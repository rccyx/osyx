import hashlib
import os
import re
import shlex
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

from core.files import Files, file_image, fingerprint, read_image
from core.manifest import Entry, mapping, string, string_map, strings, table
from core.state import ErrorTag, Image, ProvisionError, Receipt, run
from packages.download import Download, extract, fetch


@dataclass(frozen=True)
class Release:
    version: str
    commands: dict[str, str]
    url: str = ""
    sha256: str = ""
    directory: str = "."
    build: str = ""


@dataclass(frozen=True)
class Native:
    entry: Entry
    commands: tuple[str, ...]
    git: str = ""


def releases(path: Path) -> dict[str, Release]:
    result: dict[str, Release] = {}
    for name, raw in table(path).items():
        data = mapping(raw)
        result[name] = Release(
            string(data.get("version")),
            string_map(data.get("commands")),
            string(data["url"]) if "url" in data else "",
            string(data["sha256"]) if "sha256" in data else "",
            string(data["directory"]) if "directory" in data else ".",
            string(data["build"]) if "build" in data else "",
        )
    return result


def native(entry: Entry, options: dict[str, object]) -> Native:
    commands = tuple(strings(options["commands"])) if "commands" in options else (entry.name,)
    url = string(options["git"]) if "git" in options else ""
    if url and not re.fullmatch(r"[0-9a-f]{40}", entry.version):
        raise ProvisionError(
            ErrorTag.MANIFEST, f"Git source {entry.name} requires a full commit SHA"
        )
    return Native(entry=entry, commands=commands, git=url)


@dataclass(frozen=True)
class GitSource:
    url: str
    revision: str


def checkout_source(source: GitSource, target: Path) -> None:
    url = source.url
    revision = source.revision
    run(["git", "init", "--quiet", target])
    run(["git", "-C", target, "fetch", "--quiet", "--depth=1", url, revision])
    run(["git", "-C", target, "checkout", "--quiet", "--detach", "FETCH_HEAD"])
    if re.fullmatch(r"[0-9a-f]{40}", revision):
        actual = run(["git", "-C", target, "rev-parse", "HEAD"], capture=True).strip()
        if actual != revision:
            raise ProvisionError(ErrorTag.VERIFY, f"unexpected Git revision: {actual}")


class Installer:
    def __init__(self, name: str, home: Path):
        self.name = name
        self.home = home
        self.target = home / ".local/share/osyx/packages" / name
        self.bin = home / ".local/bin"
        self.receipt = Receipt(home / ".local/state/osyx/provisioning" / f"{name}.json")
        self.files = Files(home, self.receipt)

    def plan(self, version: str) -> None:
        if (
            not self.receipt.values.get("completed")
            or self.receipt.values.get("release") != version
        ):
            print(f"apply {self.name} {version} -> {self.target}")

    def apply_release(self, release: Release) -> None:
        if self.prepare(release.version):
            with tempfile.TemporaryDirectory(dir=self.target.parent) as directory:
                staging = Path(directory)
                if self.name == "python":
                    self._python(release)
                elif self.name == "rust":
                    self._rust(release, staging)
                else:
                    archive = staging / "archive"
                    fetch(Download(release.url, release.sha256), archive)
                    output = staging / "payload"
                    extract(archive, output)
                    candidate = output / release.directory
                    self._check(candidate, release.commands)
                    candidate.rename(self.target)
        self.publish(release.commands)
        self.finish(release.commands)

    def apply_native(self, item: Native) -> None:
        commands = {name: f"bin/{name}" for name in item.commands}
        if self.prepare(item.entry.version):
            with tempfile.TemporaryDirectory(dir=self.target.parent) as directory:
                staging = Path(directory)
                if item.entry.name == "swww":
                    checkout = staging / "source"
                    checkout_source(GitSource(url=item.git, revision=item.entry.version), checkout)
                    run(
                        [
                            self.bin / "cargo",
                            "build",
                            "--locked",
                            "--release",
                            "--manifest-path",
                            checkout / "Cargo.toml",
                        ]
                    )
                    output = self.target / "bin"
                    output.mkdir(parents=True)
                    for command in item.commands:
                        shutil.copy2(checkout / "target/release" / command, output / command)
                else:
                    args: list[str | Path] = [
                        self.bin / "cargo",
                        "install",
                        "--locked",
                        "--root",
                        self.target,
                    ]
                    if item.git:
                        args.extend(["--git", item.git, "--rev", item.entry.version])
                    else:
                        args.extend(["--version", f"={item.entry.version}"])
                    run([*args, item.entry.name])
        self.publish(commands)
        self.finish(commands)

    def prepare(self, version: str) -> bool:
        self.plan(version)
        prior = self.receipt.values.get("release")
        self.files.path(str(self.target.relative_to(self.home)))
        if prior and version != prior:
            raise ProvisionError(
                ErrorTag.CONFLICT, f"destroy {self.name} {prior} before applying {version}"
            )
        if self.target.is_symlink() or (self.target.exists() and not prior):
            raise ProvisionError(ErrorTag.CONFLICT, f"unmanaged package directory: {self.target}")
        if self.receipt.values.get("completed") and self.target.is_dir():
            return False
        self.target.parent.mkdir(parents=True, exist_ok=True)
        self.receipt.values["release"] = version
        self.receipt.values["completed"] = False
        self.receipt.save()
        if self.target.exists():
            shutil.rmtree(self.target)
        return True

    def publish(self, commands: dict[str, str]) -> None:
        self._check(self.target, commands)
        for command, binary in commands.items():
            key = str((self.bin / command).relative_to(self.home))
            path = self.files.path(key)
            target = self.target / binary
            image: Image
            if self.name == "rust":
                env = f"RUSTUP_HOME={shlex.quote(str(self.target / 'rustup'))}"
                if command == "rustup":
                    env += f" CARGO_HOME={shlex.quote(str(self.target / 'cargo'))}"
                script = f'#!/bin/sh\nexec env {env} {shlex.quote(str(target))} "$@"\n'
                image = file_image(script.encode(), 0o755)
            else:
                image = {"kind": "link", "value": str(target)}
                # venv entry points and npm shims must stay in their original package directory
                if self.name.startswith("pnpm-"):
                    script = f'#!/bin/sh\nexec {shlex.quote(str(target))} "$@"\n'
                    image = file_image(script.encode(), 0o755)
            existing = read_image(path)
            if existing is not None and key not in self.files.changes() and existing != image:
                raise ProvisionError(ErrorTag.CONFLICT, f"unmanaged command already exists: {path}")
            self.files.install(key, image)

    def finish(self, commands: dict[str, str]) -> None:
        if not self.receipt.values.get("completed"):
            self.receipt.values["tree"] = self._hashes(commands)
        self.receipt.values["completed"] = True
        self.receipt.save()
        self.doctor(commands)

    def doctor(self, commands: dict[str, str], *, version: str = "") -> None:
        if not self.receipt.values.get("completed"):
            raise ProvisionError(ErrorTag.VERIFY, f"incomplete or missing receipt for {self.name}")
        if version and self.receipt.values.get("release") != version:
            raise ProvisionError(ErrorTag.VERIFY, f"version drift: {self.name}")
        self._check(self.target, commands)
        if self.receipt.values.get("tree") != self._hashes(commands):
            raise ProvisionError(ErrorTag.VERIFY, f"executable hash changed: {self.name}")
        for name, change in self.files.changes().items():
            if fingerprint(read_image(self.files.path(name))) != change["after"]:
                raise ProvisionError(ErrorTag.VERIFY, f"missing or changed managed path: {name}")
        for command in commands:
            if not (self.bin / command).is_file():
                raise ProvisionError(ErrorTag.VERIFY, f"missing command {command}")
        pinned = version or self.receipt.values.get("release", "")
        self._check_release_version(pinned)
        print(f"{self.name} checked")

    def plan_remove(self) -> None:
        self.files.path(str(self.target.relative_to(self.home)))
        if self.target.is_symlink():
            raise ProvisionError(ErrorTag.CONFLICT, f"package directory changed: {self.target}")
        self.files.plan_remove()
        if self.receipt.values.get("release") and self.target.is_dir():
            print(f"destroy {self.target}")

    def reset(self) -> None:
        self.plan_remove()
        self.files.reset()
        if self.receipt.values.get("release") and self.target.is_dir():
            shutil.rmtree(self.target)
        self.receipt.clear()

    def _check_release_version(self, version: str) -> None:
        cli = {
            "go": ["go", "version"],
            "node": ["node", "--version"],
            "pnpm": ["pnpm", "--version"],
            "uv": ["uv", "--version"],
            "python": ["python3.15", "--version"],
            "rust": ["rustc", "--version"],
            "yazi": ["yazi", "--version"],
            "gh": ["gh", "--version"],
        }.get(self.name)
        if cli is None or not version:
            return
        output = run([self.bin / cli[0], *cli[1:]], capture=True)
        if not re.search(rf"(?<![0-9.]){re.escape(version)}(?![0-9.])", output):
            raise ProvisionError(
                ErrorTag.VERIFY, f"{self.name}: expected {version}, found {output.strip()}"
            )

    def _hashes(self, commands: dict[str, str]) -> dict[str, str]:
        hashes: dict[str, str] = {}
        for command, binary in commands.items():
            with (self.target / binary).open("rb") as stream:
                hashes[command] = hashlib.file_digest(stream, "sha256").hexdigest()
        return hashes

    def _check(self, output: Path, commands: dict[str, str]) -> None:
        for binary in commands.values():
            path = output / binary
            if not path.is_file() or not os.access(path, os.X_OK):
                raise ProvisionError(
                    ErrorTag.VERIFY, f"{self.name} did not provide executable {binary}"
                )

    def _python(self, release: Release) -> None:
        # install with the pinned uv and build, without changing Debian Python
        run(
            [
                "env",
                f"UV_PYTHON_INSTALL_DIR={self.target.parent / '.python-staging'}",
                f"UV_PYTHON_CPYTHON_BUILD={release.build}",
                self.bin / "uv",
                "python",
                "install",
                "--no-bin",
                release.version,
            ]
        )
        staging = self.target.parent / ".python-staging"
        candidate = next(staging.glob(f"cpython-{release.version}-*"), None)
        if candidate is None:
            raise ProvisionError(ErrorTag.VERIFY, f"uv did not install CPython {release.version}")
        candidate.rename(self.target)
        if not any(staging.iterdir()):
            staging.rmdir()

    def _rust(self, release: Release, staging: Path) -> None:
        binary = staging / "rustup-init"
        fetch(Download(release.url, release.sha256), binary)
        binary.chmod(0o755)
        self.target.mkdir()
        run(
            [
                "env",
                f"CARGO_HOME={self.target / 'cargo'}",
                f"RUSTUP_HOME={self.target / 'rustup'}",
                binary,
                "-y",
                "--no-modify-path",
                "--profile",
                "minimal",
                "--default-toolchain",
                release.version,
            ]
        )
