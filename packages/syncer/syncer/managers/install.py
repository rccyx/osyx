from __future__ import annotations

import subprocess
from dataclasses import dataclass
from shlex import join

from syncer.execution import Command, describe_failure, require_command, run
from syncer.terminal import note, warn

__all__ = ["InstallPlan", "RestoreOptions", "install", "install_with_fallback"]


def install(plan: InstallPlan, dry: bool) -> None:
    if not plan.packages:
        return
    require_command(plan.command[0])
    for spec in plan.packages.values():
        note(f"{join(plan.command)} {spec}")
        if not dry:
            run(Command((*plan.command, spec)))


def install_with_fallback(command: Command, fallback: Command) -> None:
    try:
        run(command)
    except subprocess.CalledProcessError as exc:
        if command == fallback:
            raise
        warn(f"{describe_failure(exc)}; retrying with {join(fallback.args)}")
        run(fallback)


@dataclass(frozen=True)
class InstallPlan:
    command: tuple[str, ...]
    packages: dict[str, str]


@dataclass(frozen=True)
class RestoreOptions:
    dry: bool = False
    strict: bool = False
    no_apt_update: bool = False
