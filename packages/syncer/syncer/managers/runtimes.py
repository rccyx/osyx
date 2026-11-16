from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from syncer.execution import Command, has, require_command, run
from syncer.lockfile import GoToolPin, VersionPin
from syncer.managers.install import InstallPlan, install, install_with_fallback
from syncer.terminal import note

__all__ = [
    "capture_mise",
    "capture_cargo",
    "capture_go_tools",
    "capture_rustup",
    "capture_nix",
    "restore_mise",
    "restore_cargo",
    "restore_go",
    "restore_rustup",
    "restore_nix",
]


def capture_mise() -> dict[str, VersionPin]:
    if not has("mise"):
        return {}
    r = run(Command(("mise", "ls", "--global", "--json")))
    try:
        entries: list[dict[str, Any]] = json.loads(r)
        return {e["tool"]: VersionPin(version=e["version"]) for e in entries}
    except (ValueError, KeyError, TypeError, IndexError, AttributeError) as exc:
        raise ValueError(f"Cannot capture mise: {exc}") from exc


def capture_cargo() -> dict[str, VersionPin]:
    if not has("cargo"):
        return {}
    r = run(Command(("cargo", "install", "--list")))
    result: dict[str, VersionPin] = {}
    for line in r.splitlines():
        if line and (not line[0].isspace()):
            parts = line.rstrip(":").split()
            if len(parts) >= 2:
                result[parts[0]] = VersionPin(version=parts[1].lstrip("v"))
    return result


def capture_go_tools() -> dict[str, GoToolPin]:
    if not has("go"):
        return {}
    gobin = run(Command(("go", "env", "GOBIN"))) or run(
        Command(("go", "env", "GOPATH"))
    )
    directory = Path(gobin or str(Path.home() / "go" / "bin"))
    if not directory.is_dir():
        return {}
    pins: dict[str, GoToolPin] = {}
    for binary in sorted(directory.iterdir()):
        pin = _capture_go_binary(binary)
        if pin is not None:
            pins[binary.name] = pin
    return pins


def capture_rustup() -> list[str]:
    if not has("rustup"):
        return []
    r = run(Command(("rustup", "toolchain", "list")))
    return [line.split()[0] for line in r.splitlines() if line.strip()]


def capture_nix() -> list[str]:
    if not has("nix"):
        return []
    output = run(Command(("nix", "profile", "list", "--json")))
    try:
        profile = json.loads(output)
        elements = profile.get("elements", [])
        entries = elements.values() if isinstance(elements, dict) else elements
        return [
            entry.get("originalUrl") or entry.get("attrPath") or ""
            for entry in entries
            if isinstance(entry, dict)
        ]
    except (ValueError, KeyError, TypeError, AttributeError) as exc:
        raise ValueError(f"Cannot parse Nix profile: {exc}") from exc


def restore_mise(pins: dict[str, VersionPin], dry: bool) -> None:
    if not pins:
        return
    specs = [f"{name}@{pin['version']}" for name, pin in pins.items()]
    install(
        InstallPlan(("mise", "use", "--global"), {spec: spec for spec in specs}), dry
    )
    if not dry:
        run(Command(("mise", "install")))


def restore_cargo(pins: dict[str, VersionPin], dry: bool) -> None:
    packages = {
        name: f"{name}@{pin['version']}" if pin["version"] != "unknown" else name
        for name, pin in pins.items()
    }
    install(InstallPlan(("cargo", "install"), packages), dry)


def restore_go(pins: dict[str, GoToolPin], dry: bool) -> None:
    specs = [f"{pin['module']}@{pin['version']}" for pin in pins.values()]
    install(InstallPlan(("go", "install"), {spec: spec for spec in specs}), dry)


def restore_rustup(toolchains: list[str], dry: bool) -> None:
    install(
        InstallPlan(
            ("rustup", "toolchain", "install"),
            {toolchain: toolchain for toolchain in toolchains},
        ),
        dry,
    )


def restore_nix(packages: list[str], dry: bool) -> None:
    if not packages:
        return
    require_command("nix")
    for package in packages:
        note(f"nix profile install {package}")
        if not dry:
            install_with_fallback(
                Command(("nix", "profile", "install", package)),
                Command(("nix", "profile", "install", f"nixpkgs#{package}")),
            )


def _capture_go_binary(binary: Path) -> GoToolPin | None:
    if not binary.is_file() or not os.access(binary, os.X_OK):
        return None
    metadata = run(Command(("go", "version", "-m", str(binary))))
    for line in metadata.splitlines():
        columns = line.split()
        if len(columns) >= 3 and columns[0] == "mod":
            return GoToolPin(module=columns[1], version=columns[2])
    return None
