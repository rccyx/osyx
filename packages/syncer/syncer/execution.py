from __future__ import annotations

import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from shlex import join

__all__ = ["Command", "PROXY_VARS", "describe_failure", "has", "require_command", "run"]

PROXY_VARS = (
    "http_proxy",
    "https_proxy",
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "ALL_PROXY",
    "all_proxy",
)


def run(command: Command) -> str:
    args = command.args
    if command.sudo and os.geteuid() != 0:
        args = ("sudo", "--", *args)
    env = os.environ.copy()
    for key in command.env_clear:
        env.pop(key, None)
    completed = subprocess.run(
        args,
        capture_output=True,
        text=True,
        env=env,
        input=command.stdin,
        cwd=command.cwd,
        check=True,
    )
    return completed.stdout.strip()


def has(command: str) -> bool:
    return shutil.which(command) is not None


def require_command(command: str) -> None:
    if not has(command):
        raise FileNotFoundError(f"Required command is missing from PATH: {command}")


def describe_failure(error: subprocess.CalledProcessError) -> str:
    detail = (error.stderr or error.stdout or "").strip()
    message = f"Command exited {error.returncode}: {join(error.cmd)}"
    return f"{message}\n{detail}" if detail else message


@dataclass(frozen=True)
class Command:
    args: tuple[str, ...]
    env_clear: tuple[str, ...] = ()
    sudo: bool = False
    stdin: str | None = None
    cwd: Path | None = None
