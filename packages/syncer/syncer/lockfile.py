from __future__ import annotations

import json
import os
import tempfile
from collections.abc import Iterable
from pathlib import Path
from typing import Any, TypedDict, cast

__all__ = [
    "SCHEMA_VERSION",
    "LOCK_FILENAME",
    "os_info",
    "atomic_write_json",
    "load_lock",
    "AptPin",
    "VersionPin",
    "PipxInjected",
    "PipxPin",
    "GoToolPin",
    "SyncLock",
]
SCHEMA_VERSION = 3
LOCK_FILENAME = "sync.lock.json"


def os_info() -> tuple[str, str]:
    """Return (os_id, os_version_id) from /etc/os-release."""
    data: dict[str, str] = {}
    p = Path("/etc/os-release")
    if p.exists():
        for line in p.read_text().splitlines():
            if "=" in line:
                k, _, v = line.partition("=")
                data[k.strip()] = v.strip().strip('"')
    return (data.get("ID", "unknown"), data.get("VERSION_ID", "unknown"))


def atomic_write_json(path: Path, lock: SyncLock) -> None:
    """Write JSON atomically: temp-write then os.replace."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(
        dir=path.parent, prefix=".sync-tmp-", suffix=".json"
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(lock, fh, indent=2, sort_keys=True)
            fh.write("\n")
        os.replace(tmp_path, path)
    finally:
        Path(tmp_path).unlink(missing_ok=True)


def load_lock(path: Path) -> SyncLock | None:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except (ValueError, UnicodeError) as exc:
        raise ValueError(f"Cannot parse lock file {path}: {exc}") from exc
    if not isinstance(raw, dict):
        raise ValueError(f"Lock file {path} must contain an object")
    if raw.get("schema_version") != SCHEMA_VERSION:
        raise ValueError(
            f"Unsupported lock schema {raw.get('schema_version')}; expected {SCHEMA_VERSION}"
        )
    missing = SyncLock.__required_keys__ - raw.keys()
    if missing:
        raise ValueError(f"Lock file {path} is missing: {', '.join(sorted(missing))}")
    _validate_lock(raw)
    return cast(SyncLock, raw)


def _validate_lock(raw: dict[str, Any]) -> None:
    metadata = ("snapshot_at", "hostname", "os_id", "os_version_id")
    lists = (
        "uv_tools",
        "pip3_system",
        "rustup_toolchains",
        "nix_profile",
        "snap",
        "flatpak_user",
        "flatpak_system",
    )
    pins = {
        "mise": ("version",),
        "apt": ("version", "arch"),
        "cargo": ("version",),
        "npm_global": ("version",),
        "pnpm_global": ("version",),
        "go_tools": ("module", "version"),
        "pipx": ("version", "python_version"),
    }
    for key in metadata:
        if not isinstance(raw[key], str):
            raise ValueError(f"Invalid lock field {key}: expected a string")
    for key in lists:
        values = raw[key]
        if not isinstance(values, list) or not all(
            isinstance(value, str) for value in values
        ):
            raise ValueError(f"Invalid lock field {key}: expected a list of strings")
    for key, fields in pins.items():
        if not isinstance(raw[key], dict) or not _valid_records(
            raw[key].values(), fields
        ):
            raise ValueError(
                f"Invalid lock field {key}: expected package records with {fields}"
            )
    for pin in raw["pipx"].values():
        injected = pin.get("injected")
        if not isinstance(injected, list) or not _valid_records(
            injected, ("package", "version")
        ):
            raise ValueError("Invalid pipx injections in lock file")


def _valid_records(records: Iterable[object], fields: tuple[str, ...]) -> bool:
    return all(
        isinstance(record, dict)
        and all(isinstance(record.get(field), str) for field in fields)
        for record in records
    )


class AptPin(TypedDict):
    version: str
    arch: str


class VersionPin(TypedDict):
    version: str


class PipxInjected(TypedDict):
    package: str
    version: str


class PipxPin(TypedDict):
    version: str
    python_version: str
    injected: list[PipxInjected]


class GoToolPin(TypedDict):
    module: str
    version: str


class SyncLock(TypedDict):
    schema_version: int
    snapshot_at: str
    hostname: str
    os_id: str
    os_version_id: str
    mise: dict[str, VersionPin]
    apt: dict[str, AptPin]
    cargo: dict[str, VersionPin]
    npm_global: dict[str, VersionPin]
    pnpm_global: dict[str, VersionPin]
    pipx: dict[str, PipxPin]
    uv_tools: list[str]
    pip3_system: list[str]
    go_tools: dict[str, GoToolPin]
    rustup_toolchains: list[str]
    nix_profile: list[str]
    snap: list[str]
    flatpak_user: list[str]
    flatpak_system: list[str]
