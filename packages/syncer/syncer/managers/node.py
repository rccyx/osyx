from __future__ import annotations

import json
from dataclasses import dataclass

from syncer.execution import Command, has, require_command, run
from syncer.lockfile import VersionPin
from syncer.terminal import note

__all__ = [
    "NodePackages",
    "capture_npm_global",
    "capture_pnpm_global",
    "restore_npm_pnpm",
]


def capture_npm_global() -> dict[str, VersionPin]:
    if not has("npm"):
        return {}
    r = run(Command(("npm", "ls", "-g", "--depth=0", "--json")))
    try:
        data = json.loads(r)
        deps = data.get("dependencies", {})
        return {
            n: VersionPin(version=str(i.get("version", "unknown")))
            for n, i in deps.items()
            if isinstance(i, dict)
        }
    except (ValueError, KeyError, TypeError, IndexError, AttributeError) as exc:
        raise ValueError(f"Cannot capture npm_global: {exc}") from exc


def capture_pnpm_global() -> dict[str, VersionPin]:
    if not has("pnpm"):
        return {}
    r = run(Command(("pnpm", "ls", "-g", "--depth=0", "--json")))
    try:
        data = json.loads(r)[0]
        deps = data.get("dependencies", {})
        return {
            n: VersionPin(version=str(i.get("version", "unknown")))
            for n, i in deps.items()
            if isinstance(i, dict)
        }
    except (ValueError, KeyError, TypeError, IndexError, AttributeError) as exc:
        raise ValueError(f"Cannot capture pnpm_global: {exc}") from exc


def restore_npm_pnpm(packages: NodePackages, dry: bool) -> None:
    if not packages.pins:
        return
    require_command(packages.manager)
    specs = [
        f"{name}@{pin['version']}" if pin["version"] != "unknown" else name
        for name, pin in packages.pins.items()
    ]
    action = "install" if packages.manager == "npm" else "add"
    note(f"{packages.manager} {action} -g {len(specs)} pkgs")
    if not dry:
        run(Command((packages.manager, action, "-g", *specs)))


@dataclass(frozen=True)
class NodePackages:
    manager: str
    pins: dict[str, VersionPin]
