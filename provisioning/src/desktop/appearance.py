import tempfile
from pathlib import Path

from core.files import Files, file_image, fingerprint, read_image
from core.manifest import mapping, string, table
from core.state import ErrorTag, Image, ProvisionError, run
from packages.download import Download, extract, fetch
from packages.install import GitSource, checkout_source


class Appearance:
    def __init__(self, files: Files, manifest: Path):
        self.files = files
        self.manifest = table(manifest)

    def plan(self, name: str) -> None:
        version = self._version(name)
        if not self.files.receipt.values.get("completed"):
            print(f"apply {name} {version}")
        elif self.files.receipt.values.get("release") != version:
            raise ProvisionError(
                ErrorTag.CONFLICT, f"destroy installed {name} before applying new version"
            )

    def apply(self, name: str) -> None:
        self.plan(name)
        if self.files.receipt.values.get("completed"):
            self.doctor(name)
            return
        self.files.receipt.values["release"] = self._version(name)
        self.files.receipt.save()
        with tempfile.TemporaryDirectory() as directory:
            staging = Path(directory)
            if name == "shell":
                self._shell(staging)
            else:
                self._assets(name, staging)
        if name == "fonts":
            run(["fc-cache", "-f", self.files.root / ".local/share/fonts/osyx"])
        self.files.receipt.values["completed"] = True
        self.files.receipt.save()
        self.doctor(name)

    def doctor(self, name: str) -> None:
        if not self.files.receipt.values.get("completed"):
            raise ProvisionError(ErrorTag.VERIFY, f"missing {name} receipt")
        for path, change in self.files.changes().items():
            if fingerprint(read_image(self.files.path(path))) != change["after"]:
                raise ProvisionError(ErrorTag.VERIFY, f"missing or changed {name} asset: {path}")
        if name == "fonts" and not any(
            path.is_file() for path in self.files.path(".local/share/fonts/osyx").rglob("*")
        ):
            raise ProvisionError(ErrorTag.VERIFY, "OSYX fonts missing")
        if name == "gtk":
            spec = mapping(self.manifest["gtk"])
            base = self.files.path(f".local/share/themes/{string(spec['directory'])}")
            if not (base / "gtk-3.0/gtk.css").is_file():
                raise ProvisionError(ErrorTag.VERIFY, "GTK3 theme missing")
            alias = self.files.path(f".local/share/themes/{string(spec['alias'])}")
            if not alias.is_dir():
                raise ProvisionError(ErrorTag.VERIFY, "configured GTK theme alias missing")
        if name == "shell" and not self.files.path(".oh-my-zsh/oh-my-zsh.sh").is_file():
            raise ProvisionError(ErrorTag.VERIFY, "Oh My Zsh missing")

    def destroy(self, name: str) -> None:
        self.files.reset()
        if name == "fonts":
            run(["fc-cache", "-f"])
        self.files.receipt.clear()

    def _version(self, name: str) -> str:
        spec = mapping(self.manifest[name])
        if name == "shell":
            return "+".join(string(mapping(item)["revision"]) for item in spec.values())
        return string(spec["version"])

    def _assets(self, name: str, staging: Path) -> None:
        spec = mapping(self.manifest[name])
        archive = staging / "archive"
        fetch(Download(string(spec["url"]), string(spec["sha256"])), archive)
        output = staging / "payload"
        extract(archive, output)
        if name == "fonts":
            fonts = [
                p
                for p in output.rglob("*")
                if p.is_file() and p.suffix.lower() in (".otf", ".ttf", ".ttc")
            ]
            if not fonts:
                raise ProvisionError(ErrorTag.ARTIFACT, "font archive contains no font files")
            for path in sorted(fonts):
                self._install(
                    f".local/share/fonts/osyx/{path.relative_to(output)}",
                    file_image(path.read_bytes(), 0o644),
                )
        elif name == "gtk":
            theme = string(spec["directory"])
            source = next((p for p in output.rglob(theme) if p.is_dir()), None)
            if source is None:
                raise ProvisionError(ErrorTag.ARTIFACT, f"archive does not contain {theme}")
            self._copy(source, f".local/share/themes/{theme}")
            self._install(
                f".local/share/themes/{string(spec['alias'])}", {"kind": "link", "value": theme}
            )

    def _shell(self, staging: Path) -> None:
        for name, raw in mapping(self.manifest["shell"]).items():
            spec = mapping(raw)
            checkout = staging / name
            checkout_source(
                GitSource(url=string(spec["url"]), revision=string(spec["revision"])), checkout
            )
            destination = (
                ".oh-my-zsh" if name == "oh-my-zsh" else f".oh-my-zsh/custom/plugins/{name}"
            )
            tracked = run(["git", "-C", checkout, "ls-files", "-z"], capture=True)
            for entry in tracked.rstrip("\0").split("\0"):
                image = read_image(checkout / entry)
                if image is not None:
                    self._install(f"{destination}/{entry}", image)

    def _copy(self, source: Path, destination: str) -> None:
        for path in sorted(source.rglob("*")):
            if path.is_dir() and not path.is_symlink():
                continue
            image = read_image(path)
            if image is not None:
                self._install(f"{destination}/{path.relative_to(source)}", image)

    def _install(self, name: str, image: Image) -> None:
        current = read_image(self.files.path(name))
        if current is not None and current != image and name not in self.files.changes():
            raise ProvisionError(ErrorTag.CONFLICT, f"unmanaged appearance path: {name}")
        self.files.install(name, image)
