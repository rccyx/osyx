from __future__ import annotations

import json
import shutil
from pathlib import Path

from syncer.execution import Command, has, require_command, run
from syncer.lockfile import PipxInjected, PipxPin
from syncer.managers.install import InstallPlan, install, install_with_fallback
from syncer.terminal import note

__all__ = ["capture_pipx", "capture_uv", "capture_pip3", "restore_pipx", "restore_uv"]


def capture_pipx() -> dict[str, PipxPin]:
    if not has("pipx"):
        return {}
    r = run(Command(("pipx", "list", "--json")))
    try:
        raw = json.loads(r)
        result: dict[str, PipxPin] = {}
        for name, meta in (raw.get("venvs") or {}).items():
            md = meta.get("metadata") or {}
            main = md.get("main_package") or {}
            injected = [
                PipxInjected(
                    package=inj.get("package") or k,
                    version=inj.get("package_version")
                    or inj.get("version")
                    or "unknown",
                )
                for k, inj in (md.get("injected_packages") or {}).items()
            ]
            result[name] = PipxPin(
                version=main.get("package_version") or main.get("version") or "unknown",
                python_version=md.get("python_version") or "unknown",
                injected=injected,
            )
        return result
    except (ValueError, KeyError, TypeError, IndexError, AttributeError) as exc:
        raise ValueError(f"Cannot capture pipx: {exc}") from exc


def capture_uv() -> list[str]:
    if not has("uv"):
        return []
    r = run(Command(("uv", "tool", "list")))
    return [line.split()[0] for line in r.splitlines() if line.strip()]


def capture_pip3() -> list[str]:
    pip3 = _find_system_pip3()
    if not pip3:
        return []
    r = run(Command((pip3, "freeze")))
    return [line for line in r.splitlines() if line and (not line.startswith("#"))]


def restore_pipx(pins: dict[str, PipxPin], dry: bool) -> None:
    if not pins:
        return
    require_command("pipx")
    for name, pin in pins.items():
        spec = f"{name}=={pin['version']}" if pin["version"] != "unknown" else name
        note(f"pipx install {spec}")
        if dry:
            continue
        install_with_fallback(
            Command(("pipx", "install", spec)), Command(("pipx", "install", name))
        )
        _inject_pipx_packages(name, pin["injected"])


def restore_uv(tools: list[str], dry: bool) -> None:
    install(InstallPlan(("uv", "tool", "install"), {tool: tool for tool in tools}), dry)


def _find_system_pip3() -> str | None:
    """Return the path to a non-conda pip3, or None."""
    for candidate in ("/usr/bin/pip3", "/usr/local/bin/pip3"):
        if Path(candidate).exists():
            return candidate
    found = shutil.which("pip3")
    if found and "miniconda" not in found and ("conda" not in found):
        return found
    return None


def _inject_pipx_packages(name: str, injected: list[PipxInjected]) -> None:
    for pin in injected:
        spec = (
            f"{pin['package']}=={pin['version']}"
            if pin["version"] != "unknown"
            else pin["package"]
        )
        run(Command(("pipx", "inject", name, spec)))
