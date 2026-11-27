from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal

from core.manifest import Entry, entries, mapping, table
from core.state import ErrorTag, ProvisionError
from desktop.enablers import EnablerSpec, enablers
from host.firmware import intel
from packages.install import Release, releases

Kind = Literal[
    "apt",
    "home",
    "system",
    "network",
    "login-shell",
    "release",
    "cargo",
    "pipx",
    "pnpm",
    "appearance",
    "enabler",
]


@dataclass(frozen=True)
class Resource:
    kind: Kind
    requires: tuple[str, ...] = ()


@dataclass
class Catalog:
    resources: dict[str, Resource] = field(default_factory=dict)
    groups: dict[str, tuple[str, ...]] = field(default_factory=dict)
    apt: dict[str, Entry] = field(default_factory=dict)
    releases: dict[str, Release] = field(default_factory=dict)
    cargo: dict[str, Entry] = field(default_factory=dict)
    pipx: dict[str, Entry] = field(default_factory=dict)
    pnpm: dict[str, Entry] = field(default_factory=dict)
    enablers: dict[str, EnablerSpec] = field(default_factory=dict)
    tools: dict[str, object] = field(default_factory=dict)

    def options(self, manager: str, name: str) -> dict[str, object]:
        return mapping(mapping(self.tools.get(manager, {})).get(name, {}))

    def resolve(self, targets: tuple[str, ...], *, requires: bool) -> tuple[str, ...]:
        ordered: dict[str, None] = {}
        active: set[str] = set()

        def visit(name: str) -> None:
            if name in active:
                raise ProvisionError(ErrorTag.MANIFEST, f"dependency cycle: {name}")
            if name in ordered:
                return
            active.add(name)
            if name == "firmware-intel":
                for selected in (
                    intel() if requires else ("intel-cpu", "intel-gpu", "intel-wifi", "intel-audio")
                ):
                    visit(selected)
            elif name in self.groups:
                for member in self.groups[name]:
                    visit(member)
            elif name in self.resources:
                if requires:
                    for requirement in self.resources[name].requires:
                        visit(requirement)
                ordered[name] = None
            else:
                raise ProvisionError(ErrorTag.MANIFEST, f"unknown resource: {name}")
            active.remove(name)

        for target in targets:
            visit(target)
        return tuple(ordered)


def catalog(root: Path) -> Catalog:
    result = Catalog()
    deps = root / "deps"
    for path in sorted((deps / "apt").glob("*.deps")):
        _apt_group(result, path)
    for path in sorted((deps / "firmware").glob("*.deps")):
        _apt_group(result, path)
    result.releases = releases(deps / "releases.toml")
    result.cargo = entries(deps / "cargo.deps")
    result.pipx = entries(deps / "pipx.deps")
    result.pnpm = entries(deps / "pnpm.deps")
    result.enablers = enablers(root / "enablers/manifest.toml")
    result.tools = table(deps / "tools.toml")
    for backend in (result.cargo, result.pipx, result.pnpm):
        for entry in backend.values():
            if not entry.version:
                raise ProvisionError(ErrorTag.MANIFEST, f"{entry.name} requires an exact version")
    for entry in result.pipx.values():
        path = deps / "locks/pipx" / f"{entry.name}.txt"
        if (
            not path.is_file()
            or f"{entry.name}=={entry.version}" not in path.read_text().splitlines()
        ):
            raise ProvisionError(
                ErrorTag.MANIFEST, f"missing or outdated pipx constraints for {entry.name}"
            )
    for entry in result.pnpm.values():
        path = deps / "locks/pnpm" / entry.name
        if not (path / "pnpm-lock.yaml").is_file() or not (path / "package.json").is_file():
            raise ProvisionError(ErrorTag.MANIFEST, f"missing pnpm lock for {entry.name}")
    result.resources.update(
        {
            "home": Resource("home"),
            "host-settings": Resource("system", ("apt-system", "apt-bootstrap")),
            "network-services": Resource("network", ("apt-networking",)),
            "login-shell": Resource("login-shell", ("zsh",)),
            "fonts": Resource("appearance", ("fontconfig",)),
            "gtk": Resource("appearance", ("apt-appearance",)),
            "shell": Resource("appearance", ("zsh", "git")),
        }
    )
    runtime_order = ("go", "node", "pnpm", "uv", "python", "rust")
    for name in runtime_order:
        key = f"runtime-{name}"
        required: tuple[str, ...] = {
            "node": ("libatomic1",),
            "pnpm": ("runtime-node",),
            "python": ("runtime-uv",),
            "rust": ("build-essential",),
        }.get(name, ())
        result.resources[key] = Resource("release", required)
    result.resources["gh"] = Resource("release")
    for name in result.cargo:
        required = ("runtimes", "build-essential", "pkgconf")
        if name == "swww":
            required += ("apt-wallpaper",)
        elif name == "wl-screenrec":
            required += ("apt-recorder", "clang", "libclang-dev")
        elif name == "bluetui":
            required += ("bluez", "libdbus-1-dev")
        elif name == "impala":
            required += ("iwd", "libdbus-1-dev")
        result.resources[name] = Resource("cargo", required)
    for name in result.pipx:
        result.resources[name] = Resource("pipx", ("pipx",))
    for name in result.pnpm:
        result.resources[name] = Resource("pnpm", ("runtimes",))
    for name, spec in result.enablers.items():
        result.resources[name] = Resource("enabler", spec.requires)
    result.groups.update(
        {
            "system": ("apt-bootstrap", "apt-system", "host-settings"),
            "networking": ("apt-networking", "network-services"),
            "audio": ("apt-audio",),
            "desktop": ("apt-desktop",),
            "terminal": ("apt-terminal", "login-shell", "shell"),
            "appearance": ("apt-appearance", "fonts", "gtk"),
            "development": ("apt-development", "gh"),
            "login": ("apt-login",),
            "runtimes": tuple(f"runtime-{name}" for name in runtime_order),
            "cargo-tools": ("apt-recorder", "apt-wallpaper", *result.cargo),
            "pipx-tools": tuple(result.pipx),
            "pnpm-tools": tuple(result.pnpm),
            "enablers": ("apt-enablers", *result.enablers),
            "workstation": (
                "home",
                "system",
                "networking",
                "audio",
                "desktop",
                "terminal",
                "appearance",
                "development",
                "login",
                "runtimes",
                "cargo-tools",
                "pipx-tools",
                "pnpm-tools",
                "enablers",
            ),
        }
    )
    for name in result.groups:
        result.resolve((name,), requires=True)
    return result


def _apt_group(result: Catalog, path: Path) -> None:
    packages = entries(path)
    for name, entry in packages.items():
        if name in result.resources:
            raise ProvisionError(ErrorTag.MANIFEST, f"duplicate package: {name}")
        result.apt[name] = entry
        result.resources[name] = Resource("apt")
    name = path.stem if path.parent.name == "firmware" else f"apt-{path.stem}"
    result.groups[name] = tuple(packages)
