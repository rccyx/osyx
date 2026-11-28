from collections.abc import Callable
from dataclasses import dataclass, replace
from pathlib import Path
from pwd import struct_passwd

import packages.ecosystems as ecosystems
from core.files import Files
from core.manifest import strings
from core.state import Receipt
from desktop.appearance import Appearance
from desktop.enablers import Enabler
from desktop.home import Home
from engine.catalog import Catalog
from engine.request import HOST_STATE, REPOSITORY, ROOT, Request
from host.network import Network
from host.shell_login import LoginShell
from host.system import Settings, System
from packages.install import Installer, native


def root_resource(catalog: Catalog, name: str) -> bool:
    return catalog.resources[name].kind in ("apt", "system", "network", "login-shell")


@dataclass(frozen=True)
class Operations:
    plan_destroy: Callable[[], None]
    destroy: Callable[[], None]
    plan: Callable[[], None]
    apply: Callable[[], None]
    doctor: Callable[[], None]


def receipt_path(catalog: Catalog, user: struct_passwd) -> Callable[[str], Path]:
    def locate(name: str) -> Path:
        if root_resource(catalog, name):
            resource = f"login-shell-{user.pw_name}" if name == "login-shell" else name
            return HOST_STATE / f"{resource}.json"
        return (
            Path(user.pw_dir)
            / ".local/state/osyx/provisioning"
            / f"{_store_name(catalog, name)}.json"
        )

    return locate


class Worker:
    def __init__(self, catalog: Catalog, user: struct_passwd):
        self.catalog = catalog
        self.user = user

    def execute(self, request: Request, name: str) -> None:
        request = replace(request, target=name)
        receipt = Receipt(receipt_path(self.catalog, self.user)(name))
        if request.action in ("plan", "doctor"):
            receipt.load()
            self._execute(request, receipt)
        else:
            with receipt.locked():
                self._execute(request, receipt)

    def _execute(self, request: Request, receipt: Receipt) -> None:
        name = request.target
        home = Path(self.user.pw_dir)
        kind = self.catalog.resources[name].kind
        if kind == "home":
            resource = Home(REPOSITORY, home)
            resource.receipt = receipt
            resource.files = Files(home, receipt)
            _dispatch(
                request,
                Operations(
                    plan_destroy=resource.files.plan_remove,
                    destroy=resource.files.reset,
                    plan=lambda: resource.plan(replace=request.replace_home),
                    apply=lambda: resource.apply(replace=request.replace_home),
                    doctor=resource.doctor,
                ),
            )
            if request.action == "destroy":
                receipt.clear()
        elif kind == "system":
            system = System(receipt)
            if request.action == "destroy":
                system.reset()
            elif request.destroying:
                system.plan_remove()
            else:
                settings = system.settings(
                    Settings(self.user.pw_name, request.locale, request.timezone)
                )
                _dispatch(
                    request,
                    Operations(
                        plan_destroy=system.plan_remove,
                        destroy=system.reset,
                        plan=lambda: system.plan(settings),
                        apply=lambda: system.apply(settings),
                        doctor=lambda: system.doctor(settings),
                    ),
                )
        elif kind == "network":
            network = Network(Files(Path("/"), receipt))
            _dispatch(
                request,
                Operations(
                    plan_destroy=network.files.plan_remove,
                    destroy=network.destroy,
                    plan=network.plan,
                    apply=network.apply,
                    doctor=network.doctor,
                ),
            )
        elif kind == "login-shell":
            login = LoginShell(receipt, self.user.pw_name)
            _dispatch(
                request,
                Operations(
                    plan_destroy=lambda: print("restore prior login shell if owned"),
                    destroy=login.destroy,
                    plan=login.plan,
                    apply=login.apply,
                    doctor=login.doctor,
                ),
            )
        elif kind == "appearance":
            appearance = Appearance(Files(home, receipt), ROOT / "deps/appearance.toml")
            _dispatch(
                request,
                Operations(
                    plan_destroy=appearance.files.plan_remove,
                    destroy=lambda: appearance.destroy(name),
                    plan=lambda: appearance.plan(name),
                    apply=lambda: appearance.apply(name),
                    doctor=lambda: appearance.doctor(name),
                ),
            )
        elif kind == "enabler":
            payload = ROOT / "enablers/payload"
            enabler = Enabler(Files(home, receipt), self.catalog.enablers[name])
            _dispatch(
                request,
                Operations(
                    plan_destroy=enabler.files.plan_remove,
                    destroy=enabler.destroy,
                    plan=lambda: enabler.plan(payload),
                    apply=lambda: enabler.apply(payload),
                    doctor=lambda: enabler.doctor(payload),
                ),
            )
        else:
            self._package(request, receipt)

    def _package(self, request: Request, receipt: Receipt) -> None:
        name = request.target
        kind = self.catalog.resources[name].kind
        installer = Installer(_store_name(self.catalog, name), Path(self.user.pw_dir))
        installer.receipt = receipt
        installer.files = Files(Path(self.user.pw_dir), receipt)
        if request.action == "destroy":
            installer.reset()
        elif request.destroying:
            installer.plan_remove()
        elif kind == "release":
            release = self.catalog.releases[name.removeprefix("runtime-")]
            _dispatch(
                request,
                Operations(
                    plan_destroy=installer.plan_remove,
                    destroy=installer.reset,
                    plan=lambda: installer.plan(release.version),
                    apply=lambda: installer.apply_release(release),
                    doctor=lambda: installer.doctor(release.commands, version=release.version),
                ),
            )
        elif kind == "cargo":
            item = native(self.catalog.cargo[name], self.catalog.options("cargo", name))
            paths = {command: f"bin/{command}" for command in item.commands}
            _dispatch(
                request,
                Operations(
                    plan_destroy=installer.plan_remove,
                    destroy=installer.reset,
                    plan=lambda: installer.plan(item.entry.version),
                    apply=lambda: installer.apply_native(item),
                    doctor=lambda: installer.doctor(paths, version=item.entry.version),
                ),
            )
        elif kind in ("pipx", "pnpm"):
            table = self.catalog.pipx if kind == "pipx" else self.catalog.pnpm
            entry = table[name]
            options = self.catalog.options(kind, name)
            executables = tuple(strings(options["commands"])) if "commands" in options else (name,)
            tool = ecosystems.Tool(
                manager=kind,
                entry=entry,
                executables=executables,
                constraints=ROOT
                / "deps/locks"
                / kind
                / (f"{name}.txt" if kind == "pipx" else name),
            )
            _dispatch(
                request,
                Operations(
                    plan_destroy=installer.plan_remove,
                    destroy=installer.reset,
                    plan=lambda: installer.plan(entry.version),
                    apply=lambda: ecosystems.apply(tool, installer),
                    doctor=lambda: ecosystems.doctor(tool, installer),
                ),
            )


def _store_name(catalog: Catalog, name: str) -> str:
    kind = catalog.resources[name].kind
    if kind in ("pipx", "pnpm"):
        return f"{kind}-{name}"
    return name.removeprefix("runtime-")


def _dispatch(request: Request, operations: Operations) -> None:
    if request.action == "plan":
        (operations.plan_destroy if request.destroying else operations.plan)()
    elif request.action == "apply":
        operations.apply()
    elif request.action == "destroy":
        operations.destroy()
    elif request.action == "doctor":
        operations.doctor()
