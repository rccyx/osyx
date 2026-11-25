import argparse
import os
import pwd
import re
import sys
from dataclasses import replace
from pathlib import Path
from typing import cast

from features import PAYLOADS, Feature
from home import Home
from host import desktop, system
from install import (
    Installer,
    native_commands,
    native_manifest,
    release_manifest,
    system_location,
    user_location,
)
from state import ProvisionError, Receipt, run
from request import REPOSITORY, SYSTEM_RECEIPT, Action, Request
from system import Settings

APPS = ("chrome", "obsidian", "code")
FOUNDATION = ("home", "system")
WORKSTATION = (
    *FOUNDATION,
    "desktop",
    "go",
    "node",
    "pnpm",
    "uv",
    "python",
    "rust",
    "starship",
    "swww",
    "wl-screenrec",
    *PAYLOADS,
    *APPS,
    "builders",
)
ROOT_MODULES = ("system", "desktop", "builders", *APPS)


def main() -> int:
    request = _parse()
    try:
        _check_platform()
        account = _account(request.settings.user)
        modules = {"foundation": FOUNDATION, "workstation": WORKSTATION}.get(
            request.module, (request.module,)
        )
        if any(name in ROOT_MODULES for name in modules) and os.geteuid() != 0:
            raise ProvisionError("run system modules from a root TTY")
        if request.action == "reset" or request.remove:
            modules = tuple(reversed(modules))
        for name in modules:
            selected = replace(request, module=name)
            if (
                name == "builders"
                and request.module == "workstation"
                and request.action == "apply"
            ):
                if not request.builders and not _confirm_builders():
                    continue
            _module(selected, account)
    except (ProvisionError, OSError) as exc:
        cause = (
            f"\n  {exc.__cause__}"
            if isinstance(exc, ProvisionError) and exc.__cause__
            else ""
        )
        print(f"osyx: {exc}{cause}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("osyx: interrupted", file=sys.stderr)
        return 130
    return 0


def _parse() -> Request:
    parser = argparse.ArgumentParser(prog="provisioning/main")
    parser.add_argument("action", choices=("plan", "apply", "doctor", "reset"))
    parser.add_argument(
        "module",
        choices=("workstation", "foundation", *WORKSTATION),
        nargs="?",
        default="workstation",
    )
    parser.add_argument("--user", required=True)
    parser.add_argument("--locale", default="")
    parser.add_argument("--timezone", default="")
    parser.add_argument("--replace-home", action="store_true")
    parser.add_argument("--remove", action="store_true")
    parser.add_argument("--yes", action="store_true")
    parser.add_argument("--builders", action="store_true")
    parser.add_argument("--replace-existing", action="store_true")
    args = parser.parse_intermixed_args()
    if args.remove and args.action != "plan":
        parser.error("--remove requires plan")
    if args.action in ("apply", "reset") and not args.yes:
        parser.error(f"{args.action} requires --yes")
    if args.replace_existing and (
        args.module != "screenshots" or args.remove or args.action not in ("plan", "apply")
    ):
        parser.error("--replace-existing requires a screenshots install plan or apply")
    return Request(
        cast(Action, args.action),
        args.module,
        Settings(args.user, args.locale, args.timezone),
        args.replace_home,
        args.remove,
        args.builders,
        args.replace_existing,
    )


def _check_platform() -> None:
    release = dict(
        line.split("=", 1)
        for line in Path("/etc/os-release").read_text().splitlines()
        if "=" in line and not line.startswith("#")
    )
    if (release.get("ID"), release.get("VERSION_CODENAME")) != ("debian", "trixie"):
        raise ProvisionError("Debian Trixie is required")


def _account(user: str) -> pwd.struct_passwd:
    if not re.fullmatch(r"[a-z_][a-z0-9_-]*", user):
        raise ProvisionError(f"invalid workstation user {user}")
    try:
        account = pwd.getpwnam(user)
    except KeyError as exc:
        raise ProvisionError(f"workstation user does not exist: {user}") from exc
    directory = Path(account.pw_dir)
    if account.pw_uid == 0 or not directory.is_dir() or directory.is_symlink():
        raise ProvisionError(f"workstation user requires a real home directory: {user}")
    return account


def _module(request: Request, account: pwd.struct_passwd) -> None:
    if request.module not in ROOT_MODULES and os.geteuid() == 0:
        _as_user(request, account)
        return
    directory = Path(account.pw_dir)
    if request.module in ROOT_MODULES:
        if request.module == "system":
            system(request)
        elif request.module == "desktop":
            desktop(request)
        elif request.module == "builders":
            _builders(request, account)
        else:
            _install(request, Installer(request.module, system_location()))
        return
    if account.pw_uid != os.geteuid():
        raise ProvisionError(f"run user modules as {account.pw_name}")
    if request.module == "home":
        _home(request, Home(REPOSITORY, directory))
    elif request.module in PAYLOADS:
        _feature(request, Feature(request.module, directory, REPOSITORY))
    else:
        _install(request, Installer(request.module, user_location(directory)))


def _user_command(account: pwd.struct_passwd) -> list[str | Path]:
    return [
        "runuser",
        "-u",
        account.pw_name,
        "--",
        "env",
        "-i",
        f"HOME={account.pw_dir}",
        f"USER={account.pw_name}",
        f"PATH={account.pw_dir}/.local/bin:/usr/local/bin:/usr/bin:/bin",
    ]


def _as_user(request: Request, account: pwd.struct_passwd) -> None:
    command = [
        *_user_command(account),
        REPOSITORY / "provisioning/main",
        request.action,
        request.module,
        "--user",
        account.pw_name,
    ]
    if request.action in ("apply", "reset"):
        command.append("--yes")
    if request.replace_home:
        command.append("--replace-home")
    if request.replace_existing:
        command.append("--replace-existing")
    if request.remove:
        command.append("--remove")
    run(command)


def _home(request: Request, home: Home) -> None:
    receipt = home.receipt
    if request.action in ("apply", "reset"):
        with receipt.locked():
            if request.action == "apply":
                home.apply(replace=request.replace_home)
            elif receipt.values:
                home.files.reset()
                receipt.clear()
        return

    receipt.load()
    if request.remove:
        home.files.plan_remove()
    elif request.action == "doctor":
        home.doctor()
    else:
        home.plan(replace=request.replace_home)


def _install(request: Request, installer: Installer) -> None:
    name = request.module
    release = release_manifest(REPOSITORY).get(name)
    native = native_manifest(REPOSITORY).get(name)
    if release is not None:
        version = release["version"]
        commands = release["commands"]
    elif native is not None:
        version = native["version"]
        commands = native_commands(name, native)
    else:
        raise ProvisionError(f"unknown install module {name}")
    receipt = installer.receipt
    if request.action in ("apply", "reset"):
        with receipt.locked():
            if request.action == "reset":
                if receipt.values:
                    installer.reset(crate=native.get("crate") if native else None)
            elif release is not None:
                installer.apply_release(release)
            elif native is not None:
                installer.apply_native(native)
    else:
        receipt.load()
        if request.remove:
            installer.plan_remove()
        elif request.action == "doctor":
            installer.doctor(commands)
        else:
            installer.plan(version)


def _feature(request: Request, feature: Feature) -> None:
    receipt = feature.receipt
    if request.action in ("apply", "reset"):
        with receipt.locked():
            if request.action == "apply":
                feature.apply(replace_existing=request.replace_existing)
            elif receipt.values:
                feature.reset()
    else:
        receipt.load()
        if request.remove:
            feature.files.plan_remove()
        elif request.action == "doctor":
            feature.doctor()
        else:
            feature.plan(replace_existing=request.replace_existing)


def _builders(request: Request, account: pwd.struct_passwd) -> None:
    receipt = Receipt(SYSTEM_RECEIPT.with_name("builders.json"))
    paths = [
        REPOSITORY / "builders" / name / "main"
        for name in ("gcc-builder", "hypr-builder")
    ]
    if request.action == "plan":
        print(
            "reset Hyprland and GCC builders"
            if request.remove
            else "optionally run GCC and Hyprland builders"
        )
        return
    if request.action == "doctor":
        receipt.load()
        if receipt.values:
            for path in paths:
                run([*_user_command(account), path, "doctor"])
        return
    with receipt.locked():
        if request.action == "apply":
            if not receipt.values:
                receipt.values["release"] = "builders"
                receipt.save()
            for path in paths:
                run([*_user_command(account), path, "apply", "--yes"])
                run([*_user_command(account), path, "doctor"])
        elif receipt.values:
            for path in reversed(paths):
                run([*_user_command(account), path, "reset", "--yes"])
            receipt.clear()


def _confirm_builders() -> bool:
    return sys.stdin.isatty() and input(
        "Build the osyx Hyprland stack now? [y/N] "
    ).strip().lower() in ("y", "yes")


if __name__ == "__main__":
    sys.exit(main())
