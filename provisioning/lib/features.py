import json
import os
import shutil
import tempfile
from pathlib import Path

from download import Download, extract, fetch
from files import Files, file_image, read_image
from install import checkout_source, user_location
from state import Image, ProvisionError, Receipt, run

PAYLOADS = {
    "screenshots": {
        "shot-full": "shot",
        "shot-mac": "shot",
        "shot-prune-month": "shot-prune-month",
    },
    "vocaster": {"vocaster": "vocaster"},
    "battery": {"battery-notify": "battery-notify"},
    "heat": {"heat-notify": "heat-notify", "cpu-temp": "cpu-temp"},
    "themes": {},
    "shell": {},
    "fonts": {},
    "screenshare": {},
}
SHELL_SOURCES = {
    "oh-my-zsh": (
        "https://github.com/ohmyzsh/ohmyzsh",
        "c0140703a53eb0d22be44f7bac318d0baacc927c",
    ),
    "zsh-autosuggestions": (
        "https://github.com/zsh-users/zsh-autosuggestions",
        "v0.7.1",
    ),
    "zsh-syntax-highlighting": (
        "https://github.com/zsh-users/zsh-syntax-highlighting",
        "0.8.0",
    ),
}
THEME_OUTPUTS = (
    ".config/mako/config",
    ".config/starship.toml",
    ".config/wofi/style.css",
    ".tmux.conf",
    ".dircolors",
    ".gitconfig.d/theme",
)


class Feature:
    def __init__(self, name: str, home: Path, repository: Path):
        self.name = name
        self.home = home
        self.repository = repository
        self.payload = repository / "provisioning/features/payload"
        self.receipt = Receipt(user_location(home).state / f"{name}.json")
        self.files = Files(home, self.receipt)

    def plan(self, *, replace_existing: bool) -> None:
        self._plan_files(self._files(), replace_existing=replace_existing)

    def apply(self, *, replace_existing: bool) -> None:
        images = self._files()
        self._plan_files(images, replace_existing=replace_existing)
        for name, image in images.items():
            self.files.install(name, image)
        if self.name == "themes":
            self._themes()
        elif self.name == "fonts":
            self._fonts()
        elif self.name == "shell":
            self._shell()
        self._sync_session("enable")

    def _plan_files(self, images: dict[str, Image], *, replace_existing: bool) -> None:
        if not self.receipt.values:
            print(f"enable {self.name}")
        blocked = []
        for name, image in images.items():
            current = read_image(self.files.path(name))
            if current == image:
                continue
            if current is None:
                print(f"install {name}")
            elif replace_existing or name in self.files.changes():
                print(f"replace {name}")
            else:
                blocked.append(name)
        if blocked:
            raise ProvisionError(f"existing feature paths: {', '.join(blocked)}")

    def doctor(self) -> None:
        for name, image in self._files().items():
            if read_image(self.files.path(name)) != image:
                raise ProvisionError(f"missing or changed {name}")
        if (
            self.name == "shell"
            and not (self.home / ".oh-my-zsh/oh-my-zsh.sh").is_file()
        ):
            raise ProvisionError("Oh My Zsh is missing")
        if self.name == "themes" and any(
            not self.files.path(path).is_file() for path in THEME_OUTPUTS
        ):
            raise ProvisionError("initial theme files are missing")
        if self.name == "fonts" and not self.receipt.values.get("release"):
            raise ProvisionError("fonts have no receipt")
        print(f"{self.name} checked")

    def reset(self) -> None:
        self.files.plan_remove()
        self._sync_session("stop")
        self.files.reset()
        self._sync_session("reload")
        if self.name == "fonts":
            run(["fc-cache", "-f"])
        self.receipt.clear()

    def _files(self) -> dict[str, Image]:
        images = {
            f".local/bin/{name}": file_image(
                (self.payload / filename).read_bytes(), 0o755
            )
            for name, filename in PAYLOADS[self.name].items()
        }
        if self.name in ("battery", "heat"):
            timer = f"{self.name}-notify.timer"
            service = f"{self.name}-notify.service"
            directory = ".config/systemd/user"
            for unit in (timer, service):
                images[f"{directory}/{unit}"] = file_image(
                    (self.payload / unit).read_bytes(), 0o644
                )
            images[f"{directory}/timers.target.wants/{timer}"] = {
                "kind": "link",
                "value": f"../{timer}",
            }
        if self.name == "screenshare":
            name = "hyprland-portals.conf"
            images[f".config/xdg-desktop-portal/{name}"] = file_image(
                (self.payload / name).read_bytes(), 0o644
            )
        return images

    def _install(self, name: str, image: Image) -> None:
        current = read_image(self.files.path(name))
        if (
            current is not None
            and current != image
            and name not in self.files.changes()
        ):
            raise ProvisionError(f"existing feature path: {name}")
        self.files.install(name, image)

    def _themes(self) -> None:
        if all(self.files.path(name).is_file() for name in THEME_OUTPUTS):
            return
        with tempfile.TemporaryDirectory() as directory:
            staging = Path(directory)
            source = self.repository / "home/flavors"
            target = staging / "flavors"
            target.mkdir()
            shutil.copy2(source / "generate.py", target)
            for name in ("generator", "palettes", "templates"):
                shutil.copytree(source / name, target / name)
            run(["/usr/bin/python3", "-B", target / "generate.py", "malachite"])
            for name in THEME_OUTPUTS:
                if read_image(self.files.path(name)) is None:
                    self._install(
                        name, file_image((staging / name).read_bytes(), 0o644)
                    )

    def _fonts(self) -> None:
        if self.receipt.values.get("release") == "fonts-v1.0.0":
            return
        with tempfile.TemporaryDirectory() as directory:
            staging = Path(directory)
            metadata = staging / "release.json"
            run(
                [
                    "curl",
                    "-fsSL",
                    "-o",
                    metadata,
                    "https://api.github.com/repos/rccyx/osyx/releases/tags/fonts-v1.0.0",
                ]
            )
            info = json.loads(metadata.read_text())
            artifact = next(
                (
                    asset
                    for asset in info["assets"]
                    if asset["name"] == "fonts-v1.0.0.tar.gz"
                ),
                None,
            )
            if artifact is None or not artifact.get("digest", "").startswith("sha256:"):
                raise ProvisionError("fonts-v1.0.0 has no upstream SHA-256 metadata")
            archive = staging / "fonts.tar.gz"
            fetch(
                Download(
                    artifact["browser_download_url"],
                    artifact["digest"].removeprefix("sha256:"),
                ),
                archive,
            )
            output = staging / "fonts"
            extract(archive, output)
            for font in sorted(output.rglob("*")):
                if font.is_file() and font.suffix.lower() in (".otf", ".ttf", ".ttc"):
                    name = font.relative_to(output)
                    self._install(
                        f".local/share/fonts/osyx/{name}",
                        file_image(font.read_bytes(), 0o644),
                    )
            run(["fc-cache", "-f", self.home / ".local/share/fonts/osyx"])
            self.receipt.values["release"] = "fonts-v1.0.0"
            self.receipt.save()

    def _shell(self) -> None:
        if self.receipt.values.get("release") == "oh-my-zsh":
            return
        if (
            self.home / ".oh-my-zsh/oh-my-zsh.sh"
        ).is_file() and not self.files.changes():
            print("preserve existing Oh My Zsh")
            return
        with tempfile.TemporaryDirectory() as directory:
            staging = Path(directory)
            for name, (url, revision) in SHELL_SOURCES.items():
                checkout = staging / name
                checkout_source(url, revision, checkout)
                destination = (
                    ".oh-my-zsh"
                    if name == "oh-my-zsh"
                    else f".oh-my-zsh/custom/plugins/{name}"
                )
                paths = run(["git", "-C", checkout, "ls-files", "-z"], capture=True)
                for relative in paths.rstrip("\0").split("\0"):
                    image = read_image(checkout / relative)
                    if image is not None:
                        self._install(f"{destination}/{relative}", image)
        self.receipt.values["release"] = "oh-my-zsh"
        self.receipt.save()

    def _sync_session(self, action: str) -> None:
        service = {
            "battery": "battery-notify.timer",
            "heat": "heat-notify.timer",
        }.get(self.name)
        if service is None:
            return
        runtime = Path(f"/run/user/{os.getuid()}")
        if not (runtime / "bus").exists():
            return
        command = ["env", f"XDG_RUNTIME_DIR={runtime}", "systemctl", "--user"]
        if action in ("enable", "reload"):
            run([*command, "daemon-reload"])
        if action == "stop":
            run([*command, "stop", service])
        elif action == "enable":
            run([*command, "start", service])
