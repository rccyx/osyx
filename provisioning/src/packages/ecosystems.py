import json
import shlex
import shutil
from dataclasses import dataclass
from pathlib import Path

from core.manifest import Entry, mapping, string
from core.state import ErrorTag, ProvisionError, run
from packages.install import Installer


@dataclass(frozen=True)
class Tool:
    manager: str
    entry: Entry
    executables: tuple[str, ...]
    constraints: Path


def commands(tool: Tool) -> dict[str, str]:
    directory = "bin" if tool.manager == "pipx" else "node_modules/.bin"
    return {name: f"{directory}/{name}" for name in tool.executables}


def apply(tool: Tool, installer: Installer) -> None:
    manager, entry = tool.manager, tool.entry
    paths = commands(tool)
    if installer.prepare(entry.version):
        installer.target.mkdir()
        if manager == "pipx":
            if not tool.constraints.is_file():
                raise ProvisionError(
                    ErrorTag.MANIFEST, f"missing pipx constraints: {tool.constraints}"
                )
            run(
                [
                    *_pipx(installer),
                    "install",
                    "--python",
                    "/usr/bin/python3",
                    "--pip-args",
                    f"--constraint {shlex.quote(str(tool.constraints))}",
                    f"{entry.name}=={entry.version}",
                ]
            )
        else:
            source = tool.constraints
            for filename in ("package.json", "pnpm-lock.yaml"):
                if not (source / filename).is_file():
                    raise ProvisionError(
                        ErrorTag.MANIFEST, f"missing pnpm lock input: {source / filename}"
                    )
                shutil.copy2(source / filename, installer.target / filename)
            run([installer.bin / "pnpm", "--dir", installer.target, "install", "--frozen-lockfile"])
    _verify(tool, installer)
    installer.publish(paths)
    installer.finish(paths)


def doctor(tool: Tool, installer: Installer) -> None:
    _verify(tool, installer)
    installer.doctor(commands(tool), version=tool.entry.version)


def _pipx(installer: Installer) -> list[str | Path]:
    target = installer.target
    return [
        "env",
        f"PIPX_HOME={target / 'pipx'}",
        f"PIPX_BIN_DIR={target / 'bin'}",
        f"PIPX_MAN_DIR={target / 'man'}",
        f"PIPX_SHARED_LIBS={target / 'shared'}",
        "/usr/bin/pipx",
    ]


def _verify(tool: Tool, installer: Installer) -> None:
    manager, entry = tool.manager, tool.entry
    if manager == "pipx":
        output = run([*_pipx(installer), "list", "--json"], capture=True)
        inventory = mapping(json.loads(output))
        venvs = mapping(inventory.get("venvs"))
        package = mapping(venvs.get(entry.name))
        metadata = mapping(package.get("metadata"))
        version = string(mapping(metadata.get("main_package")).get("package_version"))
    else:
        package_json = installer.target / "node_modules" / entry.name / "package.json"
        version = string(mapping(json.loads(package_json.read_text())).get("version"))
    if version != entry.version:
        raise ProvisionError(
            ErrorTag.VERIFY, f"{entry.name}: expected {entry.version}, found {version}"
        )
