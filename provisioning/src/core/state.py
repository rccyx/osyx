import json
import os
import subprocess
import tempfile
from collections.abc import Iterator, Sequence
from contextlib import contextmanager
from dataclasses import dataclass
from enum import StrEnum
from fcntl import LOCK_EX, flock
from pathlib import Path
from typing import NotRequired, TypedDict, TypeGuard


class ErrorTag(StrEnum):
    MANIFEST = "manifest"
    CONFLICT = "conflict"
    COMMAND = "command"
    ARTIFACT = "artifact"
    STATE = "state"
    HOST = "host"
    VERIFY = "verify"


class ProvisionError(Exception):
    def __init__(self, tag: ErrorTag, message: str):
        super().__init__(message)
        self.tag = tag


class Image(TypedDict):
    kind: str
    value: str
    mode: NotRequired[int]


class Change(TypedDict):
    before: Image | None
    after: str
    previous: NotRequired[str]


class ReceiptData(TypedDict, total=False):
    files: dict[str, Change]
    directories: list[str]
    settings: dict[str, str]
    apt_owned: dict[str, bool]
    apt_pending: dict[str, list[str]]
    release: str
    tree: dict[str, str]
    completed: bool


def run(command: Sequence[str | Path], *, capture: bool = False) -> str:
    try:
        result = subprocess.run(
            command,
            check=True,
            stdout=subprocess.PIPE if capture else None,
            encoding="utf-8",
            errors="surrogateescape",
            env={**os.environ, "LC_ALL": "C", "DEBIAN_FRONTEND": "noninteractive"},
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        raise ProvisionError(ErrorTag.COMMAND, f"could not run {command[0]}: {exc}") from exc
    return result.stdout if capture else ""


@dataclass(frozen=True)
class FileContent:
    payload: bytes
    mode: int


def atomic_write(path: Path, content: FileContent) -> None:
    fd, name = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    staged = Path(name)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(content.payload)
            stream.flush()
            os.fchmod(stream.fileno(), content.mode)
            os.fsync(stream.fileno())
        staged.replace(path)
        sync_directory(path.parent)
    finally:
        staged.unlink(missing_ok=True)


def sync_directory(path: Path) -> None:
    fd = os.open(path, os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


class Receipt:
    def __init__(self, path: Path):
        self.path = path
        self.values: ReceiptData = {}

    def load(self) -> None:
        try:
            value: object = json.loads(self.path.read_text())
        except FileNotFoundError:
            self.values = {}
            return
        except (ValueError, OSError) as exc:
            raise ProvisionError(ErrorTag.STATE, f"invalid receipt {self.path}") from exc
        if not _receipt(value):
            raise ProvisionError(ErrorTag.STATE, f"invalid receipt {self.path}")
        self.values = value

    def save(self) -> None:
        payload = json.dumps(self.values, indent=2, sort_keys=True) + "\n"
        atomic_write(self.path, FileContent(payload=payload.encode(), mode=0o600))

    def clear(self) -> None:
        self.path.unlink(missing_ok=True)
        self.values = {}
        if self.path.parent.is_dir():
            sync_directory(self.path.parent)

    @contextmanager
    def locked(self) -> Iterator[None]:
        self.path.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        lock = self.path.with_suffix(".lock")
        with lock.open("a") as stream:
            flock(stream, LOCK_EX)
            self.load()
            yield


def _image(value: object) -> bool:
    if not isinstance(value, dict) or not isinstance(value.get("value"), str):
        return False
    if value.get("kind") == "link":
        return value.keys() == {"kind", "value"}
    mode = value.get("mode")
    return (
        value.get("kind") == "file"
        and isinstance(mode, int)
        and 0 <= mode <= 0o777
        and value.keys() == {"kind", "value", "mode"}
    )


def _changes(value: object) -> bool:
    return isinstance(value, dict) and all(
        isinstance(name, str)
        and isinstance(change, dict)
        and {"before", "after"} <= change.keys() <= {"before", "after", "previous"}
        and ("previous" not in change or isinstance(change["previous"], str))
        and isinstance(change["after"], str)
        and (change["before"] is None or _image(change["before"]))
        for name, change in value.items()
    )


def _string_dict(value: object) -> bool:
    return isinstance(value, dict) and all(
        isinstance(k, str) and isinstance(v, str) for k, v in value.items()
    )


def _string_list(value: object) -> bool:
    return isinstance(value, list) and all(isinstance(v, str) for v in value)


def _receipt(value: object) -> TypeGuard[ReceiptData]:
    if not isinstance(value, dict):
        return False
    for key, item in value.items():
        match key:
            case "files":
                valid = _changes(item)
            case "directories":
                valid = _string_list(item)
            case "settings" | "tree":
                valid = _string_dict(item)
            case "release":
                valid = isinstance(item, str)
            case "completed":
                valid = isinstance(item, bool)
            case "apt_owned":
                valid = isinstance(item, dict) and all(
                    isinstance(k, str) and isinstance(v, bool) for k, v in item.items()
                )
            case "apt_pending":
                valid = (
                    isinstance(item, dict)
                    and item.keys() == {"apply", "destroy"}
                    and all(_string_list(v) for v in item.values())
                )
            case _:
                return False
        if not valid:
            return False
    return True
