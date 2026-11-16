#!/usr/bin/env python3
"""sync — whole-system package lockfile & git-backed backup/restore.

Think Cargo.lock for your entire machine.
Captures exact versions for APT, mise, cargo, npm, pnpm, pipx, uv, go, nix, etc.

Commands:
    backup                  snapshot state -> sync.lock.json + git push
    restore [--dry-run]     pull latest -> replay sync.lock.json (safe)
    restore [--strict]      also replay dpkg selections (destructive)
    diff                    drift between installed and locked versions
    status                  quick overview of managers + locked counts
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import textwrap
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, NamedTuple, TypedDict

try:
    from rich.console import Console
    from rich.markup import escape
    from rich.panel import Panel
    from rich.table import Table
except ImportError:
    print("Missing: pip install rich", file=sys.stderr)
    sys.exit(1)


# ── constants ─────────────────────────────────────────────────────────────────

SCHEMA_VERSION: int = 3
LOCK_FILENAME: str = "sync.lock.json"
_DEFAULT_PKG_DIR: Path = Path(
    os.environ.get("PACKAGES_DIR", str(Path.home() / "packages"))
)
_PROXY_VARS: list[str] = [
    "http_proxy",
    "https_proxy",
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "ALL_PROXY",
    "all_proxy",
]

_out = Console()
_err = Console(stderr=True)


# ── TypedDicts ────────────────────────────────────────────────────────────────


class AptPin(TypedDict):
    version: str
    arch: str


class MisePin(TypedDict):
    version: str


class CargoPin(TypedDict):
    version: str


class NpmPin(TypedDict):
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
    mise: dict[str, MisePin]
    apt: dict[str, AptPin]
    cargo: dict[str, CargoPin]
    npm_global: dict[str, NpmPin]
    pnpm_global: dict[str, NpmPin]
    pipx: dict[str, PipxPin]
    uv_tools: list[str]
    pip3_system: list[str]
    go_tools: dict[str, GoToolPin]
    rustup_toolchains: list[str]
    nix_profile: list[str]
    snap: list[str]
    flatpak_user: list[str]
    flatpak_system: list[str]


# ── subprocess helpers ────────────────────────────────────────────────────────


class CmdResult(NamedTuple):
    ok: bool
    stdout: str
    stderr: str
    code: int


def _run(
    *cmd: str,
    env_clear: list[str] | None = None,
    sudo: bool = False,
    stdin: str | None = None,
    cwd: Path | None = None,
) -> CmdResult:
    """Run a subprocess. Never raises; returns CmdResult."""
    args: list[str] = list(cmd)
    if sudo and os.geteuid() != 0:
        args = ["sudo", "--"] + args

    env = os.environ.copy()
    for key in env_clear or []:
        env.pop(key, None)

    try:
        proc = subprocess.run(
            args,
            capture_output=True,
            text=True,
            env=env,
            input=stdin,
            cwd=cwd,
        )
        return CmdResult(
            ok=proc.returncode == 0,
            stdout=proc.stdout.strip(),
            stderr=proc.stderr.strip(),
            code=proc.returncode,
        )
    except FileNotFoundError:
        return CmdResult(
            ok=False, stdout="", stderr=f"command not found: {args[0]}", code=127
        )
    except Exception as exc:
        return CmdResult(ok=False, stdout="", stderr=str(exc), code=1)


def _has(cmd: str) -> bool:
    return shutil.which(cmd) is not None


# ── output helpers ────────────────────────────────────────────────────────────


def _ok(msg: str) -> None:
    _out.print(f"  [bold green]✓[/] {escape(msg)}")


def _note(msg: str) -> None:
    _out.print(f"  [dim cyan]·[/] {escape(msg)}")


def _warn(msg: str) -> None:
    _err.print(f"  [bold yellow]![/] {escape(msg)}")


def _fail(msg: str) -> None:
    _err.print(f"  [bold red]✗[/] {escape(msg)}")


# ── OS / file helpers ─────────────────────────────────────────────────────────


def _os_info() -> tuple[str, str]:
    """Return (os_id, os_version_id) from /etc/os-release."""
    data: dict[str, str] = {}
    p = Path("/etc/os-release")
    if p.exists():
        for line in p.read_text().splitlines():
            if "=" in line:
                k, _, v = line.partition("=")
                data[k.strip()] = v.strip().strip('"')
    return data.get("ID", "unknown"), data.get("VERSION_ID", "unknown")


def _atomic_write_json(path: Path, data: Any) -> None:
    """Write JSON atomically: temp-write then os.replace."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(
        dir=path.parent, prefix=".sync-tmp-", suffix=".json"
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, sort_keys=True)
            fh.write("\n")
        os.replace(tmp_path, path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def _load_lock(path: Path) -> SyncLock | None:
    if not path.exists():
        return None
    try:
        raw: Any = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as exc:
        _fail(f"Cannot read lock file: {exc}")
        return None
    stored_schema = raw.get("schema_version", 0)
    if stored_schema != SCHEMA_VERSION:
        _warn(
            f"Lock schema v{stored_schema} ≠ current v{SCHEMA_VERSION}. "
            "Proceeding anyway."
        )
    return raw  # type: ignore[return-value]


def _find_system_pip3() -> str | None:
    """Return the path to a non-conda pip3, or None."""
    for candidate in ("/usr/bin/pip3", "/usr/local/bin/pip3"):
        if Path(candidate).exists():
            return candidate
    found = shutil.which("pip3")
    if found and "miniconda" not in found and "conda" not in found:
        return found
    return None


def _is_gnome_active() -> bool:
    if "GNOME" in os.environ.get("XDG_CURRENT_DESKTOP", ""):
        return True
    return _run("pgrep", "-x", "gnome-shell").ok


# ── capture functions ─────────────────────────────────────────────────────────


def _capture_mise() -> dict[str, MisePin]:
    if not _has("mise"):
        return {}
    r = _run("mise", "ls", "--global", "--json")
    if not r.ok or not r.stdout:
        return {}
    try:
        entries: list[dict[str, Any]] = json.loads(r.stdout)
        return {
            e["tool"]: MisePin(version=e["version"])
            for e in entries
            if "tool" in e and "version" in e
        }
    except Exception:
        return {}


def _capture_apt() -> dict[str, AptPin]:
    if not _has("apt-mark"):
        return {}
    manual_r = _run("apt-mark", "showmanual")
    if not manual_r.ok:
        return {}
    initial: set[str] = set()
    init_gz = Path("/var/log/installer/initial-status.gz")
    if init_gz.exists():
        gz_r = _run("gzip", "-dc", str(init_gz))
        if gz_r.ok:
            for line in gz_r.stdout.splitlines():
                if line.startswith("Package: "):
                    initial.add(line.split(maxsplit=1)[1])
    manual = sorted(set(manual_r.stdout.splitlines()) - initial)
    if not manual:
        return {}
    dpkg_r = _run(
        "dpkg-query",
        "--showformat=${Package}\t${Version}\t${Architecture}\n",
        "-W",
        *manual,
    )
    result: dict[str, AptPin] = {}
    if dpkg_r.ok:
        for line in dpkg_r.stdout.splitlines():
            parts = line.split("\t")
            if len(parts) == 3:
                pkg, version, arch = parts
                result[pkg] = AptPin(version=version, arch=arch)
    return result


def _capture_apt_config(pkg_dir: Path) -> None:
    if not _has("apt"):
        return
    etcdir = pkg_dir / "apt-etc"
    etcdir.mkdir(parents=True, exist_ok=True)
    for src in [
        Path("/etc/apt/sources.list"),
        Path("/etc/apt/sources.list.d"),
        Path("/etc/apt/trusted.gpg.d"),
        Path("/etc/apt/keyrings"),
    ]:
        if src.exists():
            dst = etcdir / src.name
            if src.is_dir():
                if dst.exists():
                    shutil.rmtree(dst)
                shutil.copytree(src, dst, symlinks=True, dirs_exist_ok=True)
            else:
                shutil.copy2(src, dst)
    _ok(f"APT config saved → {etcdir}")


def _capture_cargo() -> dict[str, CargoPin]:
    if not _has("cargo"):
        return {}
    r = _run("cargo", "install", "--list")
    if not r.ok:
        return {}
    result: dict[str, CargoPin] = {}
    for line in r.stdout.splitlines():
        if line and not line[0].isspace():
            parts = line.rstrip(":").split()
            if len(parts) >= 2:
                result[parts[0]] = CargoPin(version=parts[1].lstrip("v"))
    return result


def _capture_npm_global() -> dict[str, NpmPin]:
    if not _has("npm"):
        return {}
    r = _run("npm", "ls", "-g", "--depth=0", "--json")
    if not r.stdout:
        return {}
    try:
        data = json.loads(r.stdout)
        deps = data.get("dependencies", {})
        return {
            n: NpmPin(version=str(i.get("version", "unknown")))
            for n, i in deps.items()
            if isinstance(i, dict)
        }
    except Exception:
        return {}


def _capture_pnpm_global() -> dict[str, NpmPin]:
    if not _has("pnpm"):
        return {}
    r = _run("pnpm", "ls", "-g", "--depth=0", "--json")
    if not r.stdout:
        return {}
    try:
        data = json.loads(r.stdout)[0]
        deps = data.get("dependencies", {})
        return {
            n: NpmPin(version=str(i.get("version", "unknown")))
            for n, i in deps.items()
            if isinstance(i, dict)
        }
    except Exception:
        return {}


def _capture_pipx() -> dict[str, PipxPin]:
    if not _has("pipx"):
        return {}
    r = _run("pipx", "list", "--json")
    if not r.ok or not r.stdout:
        return {}
    try:
        raw = json.loads(r.stdout)
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
    except Exception:
        return {}


def _capture_uv() -> list[str]:
    if not _has("uv"):
        return []
    r = _run("uv", "tool", "list")
    if not r.ok:
        return []
    # uv tool list format: "package v0.1.0 (binary1, binary2)"
    return [line.split()[0] for line in r.stdout.splitlines() if line.strip()]


def _capture_pip3() -> list[str]:
    pip3 = _find_system_pip3()
    if not pip3:
        return []
    r = _run(pip3, "freeze")
    return [l for l in r.stdout.splitlines() if l and not l.startswith("#")]


def _capture_go_tools() -> dict[str, GoToolPin]:
    if not _has("go"):
        return {}
    gobin = _run("go", "env", "GOBIN").stdout or _run("go", "env", "GOPATH").stdout
    if not gobin:
        gobin = str(Path.home() / "go" / "bin")
    bin_dir = Path(gobin)
    if not bin_dir.is_dir():
        return {}
    result: dict[str, GoToolPin] = {}
    for binary in sorted(bin_dir.iterdir()):
        if binary.is_file() and os.access(binary, os.X_OK):
            r = _run("go", "version", "-m", str(binary))
            for line in r.stdout.splitlines():
                parts = line.split()
                if len(parts) >= 3 and parts[0] == "mod":
                    result[binary.name] = GoToolPin(module=parts[1], version=parts[2])
                    break
    return result


def _capture_rustup() -> list[str]:
    if not _has("rustup"):
        return []
    r = _run("rustup", "toolchain", "list")
    return [line.split()[0] for line in r.stdout.splitlines() if line.strip()]


def _capture_nix() -> list[str]:
    if not _has("nix"):
        return []
    r = _run("nix", "profile", "list", "--json")
    if r.ok:
        try:
            data = json.loads(r.stdout)
            els = data.get("elements", [])
            items = els.values() if isinstance(els, dict) else els
            return [
                e.get("originalUrl") or e.get("attrPath") or ""
                for e in items
                if isinstance(e, dict)
            ]
        except Exception:
            pass
    r2 = _run("nix", "profile", "list")
    return [line.split()[-1] for line in r2.stdout.splitlines() if line.strip()]


def _capture_snap() -> list[str]:
    if not _has("snap"):
        return []
    r = _run("snap", "list")
    return [l.split()[0] for l in r.stdout.splitlines()[1:] if l.strip()]


def _capture_flatpak() -> tuple[list[str], list[str]]:
    if not _has("flatpak"):
        return [], []
    u = _run("flatpak", "list", "--user", "--app", "--columns=application")
    s = _run("flatpak", "list", "--system", "--app", "--columns=application")
    return u.stdout.splitlines(), s.stdout.splitlines()


def _capture_gnome_keys(pkg_dir: Path) -> None:
    if not _is_gnome_active() or not _has("dconf"):
        return
    out = pkg_dir / "keybindings.dconf"
    r = _run("dconf", "dump", "/org/gnome/settings-daemon/plugins/media-keys/")
    if r.ok and r.stdout:
        out.write_text(r.stdout)
        _ok(f"GNOME keybindings saved → {out}")


# ── restore functions ─────────────────────────────────────────────────────────


def _restore_apt_config(pkg_dir: Path, dry: bool) -> None:
    etcdir = pkg_dir / "apt-etc"
    if not etcdir.exists():
        return
    _note("Restoring APT sources/keyrings")
    if not dry:
        for src in etcdir.iterdir():
            dst = Path("/etc/apt") / src.name
            if src.is_dir():
                _run("mkdir", "-p", str(dst), sudo=True)
                _run("cp", "-a", f"{src}/*", str(dst), sudo=True)
            else:
                _run("cp", "-f", str(src), str(dst), sudo=True)

        # Repair common keyring path mismatches (e.g. ProtonVPN)
        p_key = Path("/etc/apt/keyrings/protonvpn-stable-archive-keyring.gpg")
        if p_key.exists():
            _run("mkdir", "-p", "/usr/share/keyrings", sudo=True)
            _run(
                "ln",
                "-sf",
                str(p_key),
                "/usr/share/keyrings/protonvpn-stable-archive-keyring.gpg",
                sudo=True,
            )
    _ok("APT config restored")


def _restore_mise(pins: dict[str, MisePin], dry: bool) -> list[str]:
    if not pins or not _has("mise"):
        return []
    errs = []
    for tool, pin in pins.items():
        spec = f"{tool}@{pin['version']}"
        _note(f"mise use --global {spec}")
        if not dry and not _run("mise", "use", "--global", spec).ok:
            errs.append(f"mise:{spec}")
    if not dry:
        _run("mise", "install")
    return errs


def _restore_apt(pins: dict[str, AptPin], dry: bool, no_up: bool) -> list[str]:
    if not pins or not _has("apt-get"):
        return []
    if not no_up:
        _note("apt-get update")
        if not dry:
            _run("apt-get", "update", sudo=True, env_clear=_PROXY_VARS)
    errs = []
    for pkg, pin in pins.items():
        spec = f"{pkg}={pin['version']}" if pin["version"] != "unknown" else pkg
        _note(f"apt install {spec}")
        if not dry:
            if not _run("apt-get", "install", "-y", spec, sudo=True).ok:
                if not _run("apt-get", "install", "-y", pkg, sudo=True).ok:
                    errs.append(f"apt:{pkg}")
    return errs


def _restore_cargo(pins: dict[str, CargoPin], dry: bool) -> list[str]:
    if not pins or not _has("cargo"):
        return []
    errs = []
    for name, pin in pins.items():
        spec = f"{name}@{pin['version']}" if pin["version"] != "unknown" else name
        _note(f"cargo install {spec}")
        if not dry and not _run("cargo", "install", spec).ok:
            errs.append(f"cargo:{name}")
    return errs


def _restore_npm_pnpm(
    mgr: str, pins: dict[str, NpmPin], dry: bool
) -> list[str]:
    if not pins or not _has(mgr):
        return []
    specs = [f"{n}@{p['version']}" if p["version"] != "unknown" else n for n, p in pins.items()]
    _note(f"{mgr} install -g {len(specs)} pkgs")
    if not dry:
        cmd = [mgr, "install", "-g"] if mgr == "npm" else [mgr, "add", "-g"]
        if not _run(*cmd, *specs).ok:
            return [f"{mgr}:{s}" for s in specs]
    return []


def _restore_pipx(pins: dict[str, PipxPin], dry: bool) -> list[str]:
    if not pins or not _has("pipx"):
        return []
    errs = []
    for name, pin in pins.items():
        spec = f"{name}=={pin['version']}" if pin["version"] != "unknown" else name
        _note(f"pipx install {spec}")
        if not dry:
            if not _run("pipx", "install", spec).ok:
                if not _run("pipx", "install", name).ok:
                    errs.append(f"pipx:{name}")
                    continue
            for inj in pin.get("injected", []):
                s = f"{inj['package']}=={inj['version']}" if inj["version"] != "unknown" else inj["package"]
                _run("pipx", "inject", name, s)
    return errs


def _restore_uv(tools: list[str], dry: bool) -> list[str]:
    if not tools or not _has("uv"):
        return []
    errs = []
    for t in tools:
        _note(f"uv tool install {t}")
        if not dry and not _run("uv", "tool", "install", t).ok:
            errs.append(f"uv:{t}")
    return errs


def _restore_go(pins: dict[str, GoToolPin], dry: bool) -> list[str]:
    if not pins or not _has("go"):
        return []
    errs = []
    for _, pin in pins.items():
        s = f"{pin['module']}@{pin['version']}"
        _note(f"go install {s}")
        if not dry and not _run("go", "install", s).ok:
            errs.append(f"go:{s}")
    return errs


def _restore_rustup(tcs: list[str], dry: bool) -> list[str]:
    if not tcs or not _has("rustup"):
        return []
    errs = []
    for tc in tcs:
        _note(f"rustup toolchain install {tc}")
        if not dry and not _run("rustup", "toolchain", "install", tc).ok:
            errs.append(f"rustup:{tc}")
    return errs


def _restore_nix(pkgs: list[str], dry: bool) -> list[str]:
    if not pkgs or not _has("nix"):
        return []
    errs = []
    for p in pkgs:
        _note(f"nix profile install {p}")
        if not dry:
            if not _run("nix", "profile", "install", p).ok:
                if not _run("nix", "profile", "install", f"nixpkgs#{p}").ok:
                    errs.append(f"nix:{p}")
    return errs


def _restore_gnome_keys(pkg_dir: Path, dry: bool) -> None:
    f = pkg_dir / "keybindings.dconf"
    if not f.exists() or not _is_gnome_active() or not _has("dconf"):
        return
    _note("Restoring GNOME keybindings")
    if not dry:
        _run(
            "dconf",
            "load",
            "/org/gnome/settings-daemon/plugins/media-keys/",
            stdin=f.read_text(),
        )
    _ok("GNOME keybindings restored")


# ── Git automation ────────────────────────────────────────────────────────────


def _git_sync(pkg_dir: Path, push: bool = False) -> None:
    if not (pkg_dir / ".git").is_dir():
        return
    _note(f"Git: {'pushing' if push else 'pulling'} in {pkg_dir}")
    if push:
        _run("git", "add", "-A", cwd=pkg_dir)
        r = _run("git", "status", "--porcelain", cwd=pkg_dir)
        if r.stdout:
            _run("git", "commit", "-m", f"sync: {datetime.now().isoformat()}", cwd=pkg_dir)
            _run("git", "push", cwd=pkg_dir)
            _ok("Changes pushed to packages repo")
        else:
            _note("No changes to commit")
    else:
        _run("git", "pull", "--ff-only", cwd=pkg_dir)
        _ok("Pulled latest packages snapshot")


def _restore_snap(snaps: list[str], dry: bool) -> list[str]:
    if not snaps or not _has("snap"):
        return []
    errs = []
    for s in snaps:
        _note(f"snap install {s}")
        if not dry and not _run("snap", "install", s).ok:
            errs.append(f"snap:{s}")
    return errs


def _restore_flatpak(user: list[str], system: list[str], dry: bool) -> list[str]:
    if not (user or system) or not _has("flatpak"):
        return []
    errs = []
    for p in user:
        _note(f"flatpak install --user -y {p}")
        if not dry and not _run("flatpak", "install", "--user", "-y", p).ok:
            errs.append(f"flatpak-user:{p}")
    for p in system:
        _note(f"flatpak install --system -y {p}")
        if not dry and not _run("flatpak", "install", "--system", "-y", p, sudo=True).ok:
            errs.append(f"flatpak-sys:{p}")
    return errs


# ── commands ──────────────────────────────────────────────────────────────────

def cmd_diff(pkg_dir: Path) -> int:
    lock = _load_lock(pkg_dir / LOCK_FILENAME)
    if not lock:
        _fail("No lock file")
        return 1
    _out.rule("[bold cyan]jarvis sync diff[/]")
    # Simplified diff: just list managers with count changes
    curr_mise = _capture_mise()
    curr_apt = _capture_apt()
    def d(name: str, lk: dict, cur: dict):
        diff = len(cur) - len(lk)
        if diff != 0:
            _out.print(f"  {name}: {len(lk)} -> {len(cur)} ({'+' if diff > 0 else ''}{diff})")
    d("mise", lock.get("mise", {}), curr_mise)
    d("apt", lock.get("apt", {}), curr_apt)
    # ... could add more but keeping it lean
    return 0


def cmd_status(pkg_dir: Path) -> int:
    lock = _load_lock(pkg_dir / LOCK_FILENAME)
    _out.rule("[bold cyan]jarvis sync status[/]")
    if lock:
        _ok(f"Snapshot at: {lock.get('snapshot_at')}")
        _ok(f"Hostname: {lock.get('hostname')}")
    else:
        _warn("No lock file found. Run 'backup' first.")
    return 0


def cmd_backup(pkg_dir: Path) -> int:
    _out.rule("[bold cyan]jarvis sync backup[/]")

    os_id, os_ver = _os_info()
    u, s = _capture_flatpak()

    lock: SyncLock = {
        "schema_version": SCHEMA_VERSION,
        "snapshot_at": datetime.now(tz=timezone.utc).isoformat(),
        "hostname": socket.gethostname(),
        "os_id": os_id,
        "os_version_id": os_ver,
        "mise": _capture_mise(),
        "apt": _capture_apt(),
        "cargo": _capture_cargo(),
        "npm_global": _capture_npm_global(),
        "pnpm_global": _capture_pnpm_global(),
        "pipx": _capture_pipx(),
        "uv_tools": _capture_uv(),
        "pip3_system": _capture_pip3(),
        "go_tools": _capture_go_tools(),
        "rustup_toolchains": _capture_rustup(),
        "nix_profile": _capture_nix(),
        "snap": _capture_snap(),
        "flatpak_user": u,
        "flatpak_system": s,
    }

    _capture_apt_config(pkg_dir)
    _capture_gnome_keys(pkg_dir)

    # Save dpkg selections for --strict restore
    if _has("dpkg"):
        (pkg_dir / "dpkg-selections.txt").write_text(_run("dpkg", "--get-selections").stdout)

    lock_path = pkg_dir / LOCK_FILENAME
    _atomic_write_json(lock_path, lock)
    _ok(f"Written → {lock_path}")

    _git_sync(pkg_dir, push=True)

    t = Table(title="Jarvis Sync Status", box=None)
    t.add_column("Manager", style="cyan")
    t.add_column("Count", justify="right")
    for k, v in lock.items():
        if isinstance(v, (dict, list)) and k not in ("schema_version", "pip3_system"):
            t.add_row(k, str(len(v)))
    _out.print(t)

    return 0


def cmd_restore(
    pkg_dir: Path, dry: bool, strict: bool, no_up: bool
) -> int:
    _git_sync(pkg_dir, push=False)
    lock = _load_lock(pkg_dir / LOCK_FILENAME)
    if not lock:
        _fail("No lock file found")
        return 1

    _out.rule("[bold cyan]jarvis sync restore[/]")
    if dry:
        _note("DRY RUN — no changes will be made")

    if not dry and os.geteuid() != 0:
        _run("sudo", "-v")

    _restore_apt_config(pkg_dir, dry)
    _restore_gnome_keys(pkg_dir, dry)

    errs = []
    errs += _restore_mise(lock.get("mise", {}), dry)
    errs += _restore_apt(lock.get("apt", {}), dry, no_up)
    errs += _restore_cargo(lock.get("cargo", {}), dry)
    errs += _restore_npm_pnpm("npm", lock.get("npm_global", {}), dry)
    errs += _restore_npm_pnpm("pnpm", lock.get("pnpm_global", {}), dry)
    errs += _restore_pipx(lock.get("pipx", {}), dry)
    errs += _restore_uv(lock.get("uv_tools", []), dry)
    errs += _restore_go(lock.get("go_tools", {}), dry)
    errs += _restore_rustup(lock.get("rustup_toolchains", []), dry)
    errs += _restore_nix(lock.get("nix_profile", []), dry)

    if strict and not dry and _has("dpkg"):
        sel = pkg_dir / "dpkg-selections.txt"
        if sel.exists():
            _run("dpkg", "--set-selections", sudo=True, stdin=sel.read_text())
            _run("apt-get", "-y", "dselect-upgrade", sudo=True, env_clear=_PROXY_VARS)

    if errs:
        _fail(f"Failed items: {', '.join(errs)}")
        return 1
    _ok("Restore complete")
    return 0


def main() -> None:
    p = argparse.ArgumentParser(prog="jarvis sync")
    p.add_argument("--pkg-dir", type=Path, default=_DEFAULT_PKG_DIR)
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("backup")
    r = sub.add_parser("restore")
    r.add_argument("--dry-run", action="store_true")
    r.add_argument("--strict", action="store_true")
    r.add_argument("--no-apt-update", action="store_true")

    sub.add_parser("diff")
    sub.add_parser("status")

    args = p.parse_args()
    if args.cmd == "backup":
        sys.exit(cmd_backup(args.pkg_dir))
    elif args.cmd == "restore":
        sys.exit(cmd_restore(args.pkg_dir, args.dry_run, args.strict, args.no_apt_update))
    elif args.cmd == "diff":
        sys.exit(cmd_diff(args.pkg_dir))
    elif args.cmd == "status":
        sys.exit(cmd_status(args.pkg_dir))

if __name__ == "__main__":
    main()
