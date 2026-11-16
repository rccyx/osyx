from __future__ import annotations

import os
import socket
from datetime import datetime, timezone
from pathlib import Path

from rich.table import Table

from syncer.execution import PROXY_VARS, Command, has, require_command, run
from syncer.lockfile import (
    LOCK_FILENAME,
    SCHEMA_VERSION,
    SyncLock,
    atomic_write_json,
    load_lock,
    os_info,
)
from syncer.managers import (
    NodePackages,
    RestoreOptions,
    capture_apt,
    capture_apt_config,
    capture_cargo,
    capture_flatpak,
    capture_gnome_keys,
    capture_go_tools,
    capture_mise,
    capture_nix,
    capture_npm_global,
    capture_pip3,
    capture_pipx,
    capture_pnpm_global,
    capture_rustup,
    capture_snap,
    capture_uv,
    restore_apt,
    restore_apt_config,
    restore_cargo,
    restore_gnome_keys,
    restore_go,
    restore_mise,
    restore_nix,
    restore_npm_pnpm,
    restore_pipx,
    restore_rustup,
    restore_uv,
)
from syncer.repository import git_sync
from syncer.terminal import OUT, fail, note, ok, warn

__all__ = ["cmd_diff", "cmd_status", "cmd_backup", "cmd_restore"]


def cmd_diff(pkg_dir: Path) -> int:
    lock = load_lock(pkg_dir / LOCK_FILENAME)
    if not lock:
        fail("No lock file")
        return 1
    OUT.rule("[bold cyan]syncer diff[/]")
    counts = (
        ("mise", len(lock["mise"]), len(capture_mise())),
        ("apt", len(lock["apt"]), len(capture_apt())),
    )
    for name, locked, current in counts:
        difference = current - locked
        if difference:
            OUT.print(f"  {name}: {locked} -> {current} ({difference:+d})")
    return 0


def cmd_status(pkg_dir: Path) -> int:
    lock = load_lock(pkg_dir / LOCK_FILENAME)
    OUT.rule("[bold cyan]syncer status[/]")
    if lock:
        ok(f"Snapshot at: {lock.get('snapshot_at')}")
        ok(f"Hostname: {lock.get('hostname')}")
    else:
        warn("No lock file found. Run 'backup' first.")
    return 0


def cmd_backup(pkg_dir: Path) -> int:
    OUT.rule("[bold cyan]syncer backup[/]")
    os_id, os_ver = os_info()
    u, s = capture_flatpak()
    lock: SyncLock = {
        "schema_version": SCHEMA_VERSION,
        "snapshot_at": datetime.now(tz=timezone.utc).isoformat(),
        "hostname": socket.gethostname(),
        "os_id": os_id,
        "os_version_id": os_ver,
        "mise": capture_mise(),
        "apt": capture_apt(),
        "cargo": capture_cargo(),
        "npm_global": capture_npm_global(),
        "pnpm_global": capture_pnpm_global(),
        "pipx": capture_pipx(),
        "uv_tools": capture_uv(),
        "pip3_system": capture_pip3(),
        "go_tools": capture_go_tools(),
        "rustup_toolchains": capture_rustup(),
        "nix_profile": capture_nix(),
        "snap": capture_snap(),
        "flatpak_user": u,
        "flatpak_system": s,
    }
    pkg_dir.mkdir(parents=True, exist_ok=True)
    capture_apt_config(pkg_dir)
    capture_gnome_keys(pkg_dir)
    if has("dpkg"):
        (pkg_dir / "dpkg-selections.txt").write_text(
            run(Command(("dpkg", "--get-selections")))
        )
    lock_path = pkg_dir / LOCK_FILENAME
    atomic_write_json(lock_path, lock)
    ok(f"Written → {lock_path}")
    git_sync(pkg_dir, push=True)
    t = Table(title="Syncer Status", box=None)
    t.add_column("Manager", style="cyan")
    t.add_column("Count", justify="right")
    for k, v in lock.items():
        if isinstance(v, (dict, list)) and k not in ("schema_version", "pip3_system"):
            t.add_row(k, str(len(v)))
    OUT.print(t)
    return 0


def cmd_restore(pkg_dir: Path, options: RestoreOptions) -> int:
    dry = options.dry
    git_sync(pkg_dir, push=False)
    lock = load_lock(pkg_dir / LOCK_FILENAME)
    if not lock:
        fail("No lock file found")
        return 1
    OUT.rule("[bold cyan]syncer restore[/]")
    if dry:
        note("DRY RUN — no changes will be made")
    if not dry and os.geteuid() != 0:
        run(Command(("sudo", "-v")))
    restore_apt_config(pkg_dir, dry)
    restore_gnome_keys(pkg_dir, dry)
    restore_mise(lock.get("mise", {}), dry)
    restore_apt(lock["apt"], options)
    restore_cargo(lock.get("cargo", {}), dry)
    restore_npm_pnpm(NodePackages("npm", lock["npm_global"]), dry)
    restore_npm_pnpm(NodePackages("pnpm", lock["pnpm_global"]), dry)
    restore_pipx(lock.get("pipx", {}), dry)
    restore_uv(lock.get("uv_tools", []), dry)
    restore_go(lock.get("go_tools", {}), dry)
    restore_rustup(lock.get("rustup_toolchains", []), dry)
    restore_nix(lock.get("nix_profile", []), dry)
    if options.strict and not dry:
        require_command("dpkg")
        sel = pkg_dir / "dpkg-selections.txt"
        run(Command(("dpkg", "--set-selections"), sudo=True, stdin=sel.read_text()))
        run(
            Command(
                ("apt-get", "-y", "dselect-upgrade"),
                sudo=True,
                env_clear=PROXY_VARS,
            )
        )
    ok("Restore complete")
    return 0
