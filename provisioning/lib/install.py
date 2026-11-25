import json
import os
import platform
import shlex
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import NotRequired, TypedDict, cast

import download
from files import Files, file_image, read_image
from state import ProvisionError, Receipt, run


class Release(TypedDict):
    version: str
    commands: dict[str, str]
    url: NotRequired[str]
    sha256: NotRequired[str]
    directory: NotRequired[str]
    commit: NotRequired[str]
    build: NotRequired[str]
    desktop: NotRequired[str]


class Native(TypedDict):
    version: str
    crate: NotRequired[str]
    binary: NotRequired[str]
    git: NotRequired[str]


@dataclass(frozen=True)
class Location:
    root: Path
    store: Path
    bin: Path
    menu: Path
    state: Path


def user_location(home: Path) -> Location:
    return Location(
        home,
        home / ".local/share/osyx/packages",
        home / ".local/bin",
        home / ".local/share/applications",
        home / ".local/state/osyx/provisioning",
    )


def system_location() -> Location:
    return Location(
        Path("/"),
        Path("/opt/osyx"),
        Path("/usr/local/bin"),
        Path("/usr/local/share/applications"),
        Path("/var/lib/osyx/provisioning"),
    )


class Installer:
    def __init__(self, name: str, location: Location):
        self.name = name
        self.location = location
        self.target = location.store / name
        self.receipt = Receipt(location.state / f"{name}.json")
        self.files = Files(location.root, self.receipt)

    def plan(self, version: str) -> None:
        if self.receipt.values.get("release") != version or not self.target.is_dir():
            print(f"install {self.name} {version} into {self.target}")

    def apply_release(self, release: Release) -> None:
        self.plan(release["version"])
        if self._prepare(release["version"]):
            with tempfile.TemporaryDirectory(dir=self.target.parent) as directory:
                temp = Path(directory)
                output = self._release(release, temp)
                self._check(output, release["commands"])
                output.rename(self.target)
        self._publish(release["commands"])
        if "desktop" in release:
            self._desktop(release)
        self._check(self.target, release["commands"])

    def apply_native(self, native: Native) -> None:
        commands = native_commands(self.name, native)
        self.plan(native["version"])
        if self._prepare(native["version"]):
            with tempfile.TemporaryDirectory(dir=self.target.parent) as directory:
                temp = Path(directory)
                output = self._native(native, temp)
                self._check(output, commands)
                output.rename(self.target)
        self._publish(commands)
        self._check(self.target, commands)

    def doctor(self, commands: dict[str, str]) -> None:
        self._check(self.target, commands)
        for command in commands:
            if not (self.location.bin / command).is_file():
                raise ProvisionError(f"missing command {command}")
        print(f"{self.name} installed")

    def plan_remove(self) -> None:
        self.files.plan_remove()
        if self.receipt.values.get("release") and self.target.is_dir():
            print(f"remove {self.target}")

    def reset(self, *, crate: str | None = None) -> None:
        self.plan_remove()
        self.files.reset()
        if self.receipt.values.get("release") and self.target.is_dir():
            if self.target.is_symlink():
                raise ProvisionError(f"package directory changed: {self.target}")
            if crate and (self.target / ".crates2.json").is_file():
                cargo = self.location.bin / "cargo"
                run([cargo, "uninstall", "--root", self.target, crate])
            shutil.rmtree(self.target)
        self.receipt.clear()

    def _prepare(self, version: str) -> bool:
        if platform.machine() != "x86_64":
            raise ProvisionError(
                "workstation artifact manifests currently target Debian amd64"
            )
        existing = self.receipt.values.get("release")
        if existing and existing != version:
            raise ProvisionError(
                f"reset {self.name} {existing} before installing {version}"
            )
        if self.target.is_symlink() or (self.target.exists() and not existing):
            raise ProvisionError(f"package path already exists: {self.target}")
        if self.target.is_dir():
            return False
        self.target.parent.mkdir(parents=True, exist_ok=True)
        self.receipt.values["release"] = version
        self.receipt.save()
        return True

    def _release(self, release: Release, temp: Path) -> Path:
        if self.name == "python":
            return _python(release, temp, self.location)
        if self.name == "rust":
            return _rust(release, temp)
        artifact = _artifact(self.name, release, temp)
        archive = temp / "archive"
        download.fetch(artifact, archive)
        output = temp / "payload"
        if self.name == "chrome":
            run(["dpkg-deb", "-x", archive, output])
            return output / "opt/google/chrome"
        download.extract(archive, output)
        candidate = output / release.get("directory", ".")
        first = next(iter(release["commands"].values()))
        if (candidate / first).is_file():
            return candidate
        candidates = [
            folder
            for folder in output.iterdir()
            if folder.is_dir() and (folder / first).is_file()
        ]
        if len(candidates) != 1:
            raise ProvisionError(f"archive does not contain {first}")
        return candidates[0]

    def _native(self, native: Native, temp: Path) -> Path:
        output = temp / "installed"
        if "crate" in native:
            cargo = self.location.bin / "cargo"
            command: list[str | Path] = [cargo, "install", "--locked", "--root", output]
            if "git" in native:
                command.extend(["--git", native["git"], "--rev", native["version"]])
            else:
                command.extend(["--version", f"={native['version']}"])
            run([*command, native["crate"]])
            return output
        checkout = temp / "source"
        checkout_source(native["git"], native["version"], checkout)
        bin_dir = output / "bin"
        bin_dir.mkdir(parents=True)
        run(
            [
                self.location.bin / "cargo",
                "build",
                "--locked",
                "--release",
                "--manifest-path",
                checkout / "Cargo.toml",
            ]
        )
        for binary in ("swww", "swww-daemon"):
            shutil.copy2(checkout / "target/release" / binary, bin_dir / binary)
        return output

    def _publish(self, commands: dict[str, str]) -> None:
        for command, binary in commands.items():
            path = self.location.bin / command
            key = str(path.relative_to(self.location.root))
            prior = read_image(path)
            if prior is not None and key not in self.files.changes():
                raise ProvisionError(f"command already exists: {path}")
            target = self.target / binary
            if self.name == "rust":
                env = f"RUSTUP_HOME={shlex.quote(str(self.target / 'rustup'))}"
                script = f'#!/bin/sh\nexec env {env} {shlex.quote(str(target))} "$@"\n'
                self.files.install(key, file_image(script.encode(), 0o755))
            else:
                self.files.install(key, {"kind": "link", "value": str(target)})

    def _desktop(self, release: Release) -> None:
        command = next(iter(release["commands"]))
        path = self.location.menu / f"osyx-{self.name}.desktop"
        data = f"[Desktop Entry]\nType=Application\nName={release['desktop']}\nExec={self.location.bin / command} %U\n"
        self.files.install(
            str(path.relative_to(self.location.root)), file_image(data.encode(), 0o644)
        )

    def _check(self, output: Path, commands: dict[str, str]) -> None:
        for binary in commands.values():
            path = output / binary
            if not path.is_file() or not os.access(path, os.X_OK):
                raise ProvisionError(f"{self.name} did not provide executable {binary}")


def release_manifest(root: Path) -> dict[str, Release]:
    return cast(
        dict[str, Release],
        json.loads((root / "provisioning/releases.json").read_text()),
    )


def native_manifest(root: Path) -> dict[str, Native]:
    return cast(
        dict[str, Native], json.loads((root / "provisioning/native.json").read_text())
    )


def native_commands(name: str, native: Native) -> dict[str, str]:
    names = ("swww", "swww-daemon") if name == "swww" else (native.get("binary", name),)
    return {command: f"bin/{command}" for command in names}


def checkout_source(url: str, version: str, target: Path) -> None:
    run(["git", "init", "--quiet", target])
    run(["git", "-C", target, "fetch", "--quiet", "--depth=1", url, version])
    run(["git", "-C", target, "checkout", "--quiet", "--detach", "FETCH_HEAD"])


def _artifact(name: str, release: Release, temp: Path) -> download.Download:
    if name == "chrome":
        return download.chrome(release["version"], temp)
    if name == "code":
        return download.vscode(release["commit"], temp)
    return download.Download(release["url"], release["sha256"])


def _python(release: Release, temp: Path, location: Location) -> Path:
    run(
        [
            "env",
            f"UV_PYTHON_INSTALL_DIR={temp / 'python'}",
            f"UV_PYTHON_CPYTHON_BUILD={release['build']}",
            location.bin / "uv",
            "python",
            "install",
            "--no-bin",
            release["version"],
        ]
    )
    interpreter = next((temp / "python").glob(f"cpython-{release['version']}-*"), None)
    if interpreter is None:
        raise ProvisionError(f"uv did not install CPython {release['version']}")
    return interpreter


def _rust(release: Release, temp: Path) -> Path:
    binary = temp / "rustup-init"
    download.fetch(download.rustup(release["url"], temp), binary)
    binary.chmod(0o755)
    output = temp / "installed"
    output.mkdir()
    run(
        [
            "env",
            f"CARGO_HOME={output / 'cargo'}",
            f"RUSTUP_HOME={output / 'rustup'}",
            binary,
            "-y",
            "--no-modify-path",
            "--profile",
            "minimal",
            "--default-toolchain",
            release["version"],
        ]
    )
    return output
