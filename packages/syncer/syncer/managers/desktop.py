from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

from syncer.execution import Command, has, require_command, run
from syncer.managers.install import InstallPlan, install
from syncer.terminal import note, ok

__all__ = [
    "FlatpakPackages",
    "capture_snap",
    "capture_flatpak",
    "capture_gnome_keys",
    "restore_gnome_keys",
    "restore_snap",
    "restore_flatpak",
]


def capture_snap() -> list[str]:
    if not has("snap"):
        return []
    r = run(Command(("snap", "list")))
    return [line.split()[0] for line in r.splitlines()[1:] if line.strip()]


def capture_flatpak() -> tuple[list[str], list[str]]:
    if not has("flatpak"):
        return ([], [])
    u = run(Command(("flatpak", "list", "--user", "--app", "--columns=application")))
    s = run(Command(("flatpak", "list", "--system", "--app", "--columns=application")))
    return (u.splitlines(), s.splitlines())


def capture_gnome_keys(pkg_dir: Path) -> None:
    if not _is_gnome_active() or not has("dconf"):
        return
    out = pkg_dir / "keybindings.dconf"
    r = run(
        Command(("dconf", "dump", "/org/gnome/settings-daemon/plugins/media-keys/"))
    )
    if r:
        out.write_text(r)
        ok(f"GNOME keybindings saved → {out}")


def restore_gnome_keys(pkg_dir: Path, dry: bool) -> None:
    f = pkg_dir / "keybindings.dconf"
    if not f.exists() or not _is_gnome_active() or (not has("dconf")):
        return
    note("Restoring GNOME keybindings")
    if not dry:
        run(
            Command(
                ("dconf", "load", "/org/gnome/settings-daemon/plugins/media-keys/"),
                stdin=f.read_text(),
            )
        )
    ok("GNOME keybindings restored")


def restore_snap(snaps: list[str], dry: bool) -> None:
    install(InstallPlan(("snap", "install"), {snap: snap for snap in snaps}), dry)


def restore_flatpak(scopes: FlatpakPackages, dry: bool) -> None:
    if not (scopes.user or scopes.system):
        return
    require_command("flatpak")
    for scope, packages in (("user", scopes.user), ("system", scopes.system)):
        for package in packages:
            note(f"flatpak install --{scope} -y {package}")
            if not dry:
                run(
                    Command(
                        ("flatpak", "install", f"--{scope}", "-y", package),
                        sudo=scope == "system",
                    )
                )


def _is_gnome_active() -> bool:
    if "GNOME" in os.environ.get("XDG_CURRENT_DESKTOP", ""):
        return True
    if not has("pgrep"):
        return False
    try:
        run(Command(("pgrep", "-x", "gnome-shell")))
    except subprocess.CalledProcessError as exc:
        if exc.returncode == 1:
            return False
        raise
    return True


@dataclass(frozen=True)
class FlatpakPackages:
    user: list[str]
    system: list[str]
