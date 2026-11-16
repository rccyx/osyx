from __future__ import annotations

import shutil
from pathlib import Path

from syncer.execution import (
    PROXY_VARS,
    Command,
    has,
    require_command,
    run,
)
from syncer.lockfile import AptPin
from syncer.managers.install import RestoreOptions, install_with_fallback
from syncer.terminal import note, ok

__all__ = ["capture_apt", "capture_apt_config", "restore_apt_config", "restore_apt"]


def capture_apt() -> dict[str, AptPin]:
    if not has("apt-mark"):
        return {}
    manual = run(Command(("apt-mark", "showmanual")))
    packages = sorted(set(manual.splitlines()) - _initial_apt_packages())
    if not packages:
        return {}
    query = run(
        Command(
            (
                "dpkg-query",
                "--showformat=${Package}\t${Version}\t${Architecture}\n",
                "-W",
                *packages,
            )
        )
    )
    pins: dict[str, AptPin] = {}
    for line in query.splitlines():
        columns = line.split("\t")
        if len(columns) == 3:
            name, version, arch = columns
            pins[name] = AptPin(version=version, arch=arch)
    return pins


def capture_apt_config(pkg_dir: Path) -> None:
    if not has("apt"):
        return
    destination = pkg_dir / "apt-etc"
    destination.mkdir(parents=True, exist_ok=True)
    for name in ("sources.list", "sources.list.d", "trusted.gpg.d", "keyrings"):
        source = Path("/etc/apt") / name
        if source.exists():
            _copy_apt_config(source, destination / name)
    ok(f"APT config saved → {destination}")


def restore_apt_config(pkg_dir: Path, dry: bool) -> None:
    etcdir = pkg_dir / "apt-etc"
    if not etcdir.exists():
        return
    note("Restoring APT sources/keyrings")
    if not dry:
        for src in etcdir.iterdir():
            dst = Path("/etc/apt") / src.name
            if src.is_dir():
                run(Command(("mkdir", "-p", str(dst)), sudo=True))
                run(Command(("cp", "-a", f"{src}/.", str(dst)), sudo=True))
            else:
                run(Command(("cp", "-f", str(src), str(dst)), sudo=True))
        p_key = Path("/etc/apt/keyrings/protonvpn-stable-archive-keyring.gpg")
        if p_key.exists():
            run(Command(("mkdir", "-p", "/usr/share/keyrings"), sudo=True))
            run(
                Command(
                    (
                        "ln",
                        "-sf",
                        str(p_key),
                        "/usr/share/keyrings/protonvpn-stable-archive-keyring.gpg",
                    ),
                    sudo=True,
                )
            )
    ok("APT config restored")


def restore_apt(pins: dict[str, AptPin], options: RestoreOptions) -> None:
    if not pins:
        return
    require_command("apt-get")
    if not options.no_apt_update:
        note("apt-get update")
        if not options.dry:
            run(Command(("apt-get", "update"), sudo=True, env_clear=PROXY_VARS))
    for name, pin in pins.items():
        spec = f"{name}={pin['version']}" if pin["version"] != "unknown" else name
        note(f"apt install {spec}")
        if not options.dry:
            install_with_fallback(
                Command(("apt-get", "install", "-y", spec), sudo=True),
                Command(("apt-get", "install", "-y", name), sudo=True),
            )


def _initial_apt_packages() -> set[str]:
    archive = Path("/var/log/installer/initial-status.gz")
    if not archive.exists():
        return set()
    initial = run(Command(("gzip", "-dc", str(archive))))
    return {
        line.split(maxsplit=1)[1]
        for line in initial.splitlines()
        if line.startswith("Package: ")
    }


def _copy_apt_config(source: Path, destination: Path) -> None:
    if not source.is_dir():
        shutil.copy2(source, destination)
        return
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(source, destination, symlinks=True, dirs_exist_ok=True)
