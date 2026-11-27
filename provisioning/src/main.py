import os
import subprocess
import sys
from dataclasses import replace
from pathlib import Path
from pwd import struct_passwd
from typing import assert_never

from core.state import ErrorTag, ProvisionError, Receipt
from engine.catalog import Catalog, catalog
from engine.request import HOST_STATE, ROOT, Request, parse
from engine.worker import Worker, receipt_path, root_resource
from host.account import account
from host.firmware import intel
from packages.apt import Apt


def main() -> int:
    try:
        request = parse()
        user = account(request.user)
        inventory = catalog(ROOT)
        if request.worker:
            if (
                request.target not in inventory.resources
                or os.getuid() != user.pw_uid
                or root_resource(inventory, request.target)
            ):
                raise ProvisionError(ErrorTag.HOST, "invalid user worker")
            Worker(inventory, user).execute(request, request.target)
            return 0
        _validate(request, inventory)
        if os.geteuid() != 0:
            # one root coordinator, with all user-owned work delegated back to the account
            command = ["sudo", "--", str(ROOT / "main"), *sys.argv[1:]]
            if not request.user:
                command.extend(["--user", user.pw_name])
            return subprocess.run(command, check=False).returncode
        coordinator = Coordinator(inventory, user)
        if request.action in ("apply", "destroy"):
            if not request.yes and not sys.stdin.isatty():
                raise ProvisionError(ErrorTag.HOST, "noninteractive apply/destroy requires --yes")
            lock = Receipt(HOST_STATE / "orchestrator.json")
            with lock.locked():
                previous = lock.values.get("settings", {}).get("user")
                if previous and previous != user.pw_name:
                    raise ProvisionError(ErrorTag.HOST, f"host is managed for {previous}")
                lock.values["settings"] = {"user": user.pw_name}
                lock.save()
                coordinator.execute(request)
        else:
            coordinator.execute(request)
        return 0
    except ProvisionError as exc:
        match exc.tag:
            case ErrorTag.MANIFEST | ErrorTag.CONFLICT | ErrorTag.HOST | ErrorTag.STATE:
                code = 2
            case ErrorTag.COMMAND | ErrorTag.ARTIFACT | ErrorTag.VERIFY:
                code = 1
            case _:
                assert_never(exc.tag)
        print(f"osyx [{exc.tag}]: {exc}", file=sys.stderr)
        if exc.__cause__:
            print(f"caused by: {exc.__cause__}", file=sys.stderr)
        return code
    except (OSError, ValueError) as exc:
        print(f"osyx [host]: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("osyx: interrupted, rerun to resume or destroy", file=sys.stderr)
        return 130


class Coordinator:
    def __init__(self, catalog: Catalog, user: struct_passwd):
        self.catalog = catalog
        self.user = user

    def execute(self, request: Request) -> None:
        targets = self._select(request)
        removing = request.action == "destroy" or request.destroying
        names = self.catalog.resolve(targets, requires=not removing)
        if removing:
            self._check_removal(names)
            names = tuple(reversed(names))
        if not names:
            print("no resources selected")
            return
        if request.action == "destroy" and not request.yes:
            if not _confirm(f"Destroy owned resources for {request.target}?"):
                return
        apt_names = [name for name in names if self.catalog.resources[name].kind == "apt"]
        if removing and request.action == "destroy":
            self._apt(replace(request, action="plan", destroying=True), apt_names)
        if not removing:
            # APT prerequisites are installed in one transaction before their consumers.
            # Home is copied first, immediately after stage zero.
            if "home" in names:
                self._resource(request, "home")
            self._apt(request, apt_names)
        for name in names:
            if self.catalog.resources[name].kind == "apt" or (name == "home" and not removing):
                continue
            self._resource(request, name)
        if removing:
            self._apt(request, apt_names)

    def _select(self, request: Request) -> tuple[str, ...]:
        selected: tuple[str, ...] = (request.target,)
        if request.target == "workstation" and request.action == "apply" and not request.yes:
            chosen = ["home", "system"]
            for group in self.catalog.groups["workstation"]:
                if group in chosen:
                    continue
                if group == "enablers":
                    for name in self.catalog.enablers:
                        if _confirm(f"Apply enabler {name}?"):
                            chosen.append(name)
                elif _confirm(f"Apply {group}?"):
                    chosen.append(group)
            if not request.firmware_intel:
                try:
                    supported = bool(intel())
                except ProvisionError:
                    supported = False
                if supported and input("Apply detected Intel firmware? [y/N] ").strip().lower() in (
                    "y",
                    "yes",
                ):
                    chosen.append("firmware-intel")
            selected = tuple(chosen)
        elif (
            request.action == "apply"
            and not request.yes
            and not _confirm(f"Apply {request.target}?")
        ):
            return ()
        if request.firmware_intel:
            selected += ("firmware-intel",)
        return selected

    def _apt(self, request: Request, names: list[str]) -> None:
        if not names:
            return
        receipt = Receipt(HOST_STATE / "apt.json")
        apt = Apt(receipt, self.catalog.apt)
        if request.action in ("plan", "doctor"):
            receipt.load()
            if request.destroying:
                apt.plan_remove(names)
            elif request.action == "plan":
                apt.plan(names)
            else:
                apt.doctor(names)
        else:
            with receipt.locked():
                if request.action == "apply":
                    apt.apply(names)
                else:
                    apt.reset(names)

    def _resource(self, request: Request, name: str) -> None:
        print(f"[{name}]", flush=True)
        if root_resource(self.catalog, name):
            Worker(self.catalog, self.user).execute(request, name)
            return
        home = self.user.pw_dir
        command = [
            "runuser",
            "-u",
            self.user.pw_name,
            "--",
            "env",
            "-i",
            f"HOME={home}",
            f"USER={self.user.pw_name}",
            f"LOGNAME={self.user.pw_name}",
            f"PATH={home}/.local/bin:/usr/local/bin:/usr/bin:/bin",
            f"XDG_RUNTIME_DIR=/run/user/{self.user.pw_uid}",
            str(ROOT / "main"),
            request.action,
            name,
            "--worker",
            "--user",
            self.user.pw_name,
        ]
        if request.replace_home:
            command.append("--replace-home")
        if request.destroying:
            command.append("--destroy")
        completed = subprocess.run(command, check=False)
        if completed.returncode:
            raise SystemExit(completed.returncode)

    def _check_removal(self, names: tuple[str, ...]) -> None:
        removing = set(names)
        for name, resource in self.catalog.resources.items():
            if name in removing or resource.kind == "apt":
                continue
            dependencies = set(self.catalog.resolve(resource.requires, requires=True))
            if not removing.intersection(dependencies):
                continue
            if receipt_path(self.catalog, self.user)(name).is_file():
                raise ProvisionError(ErrorTag.CONFLICT, f"destroy {name} before its dependencies")


def _validate(request: Request, inventory: Catalog) -> None:
    if request.target.startswith("runtime-") or request.target.startswith("intel-"):
        raise ProvisionError(ErrorTag.MANIFEST, "use runtimes or firmware-intel as a group")
    if (
        request.target not in inventory.resources
        and request.target not in inventory.groups
        and request.target != "firmware-intel"
    ):
        raise ProvisionError(ErrorTag.MANIFEST, f"unknown resource: {request.target}")
    if not Path("/etc/debian_version").exists() or os.uname().machine != "x86_64":
        raise ProvisionError(ErrorTag.HOST, "OSYX currently targets Debian amd64")
    if "VERSION_CODENAME=trixie" not in Path("/etc/os-release").read_text():
        raise ProvisionError(ErrorTag.HOST, "OSYX currently targets Debian 13 (Trixie)")


def _confirm(prompt: str) -> bool:
    return input(f"{prompt} [Y/n] ").strip().lower() in ("", "y", "yes")


if __name__ == "__main__":
    raise SystemExit(main())
