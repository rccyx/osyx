import json
import os
import subprocess
import tempfile
from collections.abc import Iterator, Sequence
from contextlib import contextmanager
from fcntl import LOCK_EX, flock
from pathlib import Path
from typing import NotRequired, TypedDict, cast


class Image(TypedDict):
    kind: str
    value: str
    mode: NotRequired[int]


class Change(TypedDict):
    before: Image | None
    after: str


class Package(TypedDict):
    status: str
    version: str


class Transaction(TypedDict):
    action: str
    before: dict[str, Package | None]
    remove: list[str]


class ReceiptData(TypedDict, total=False):
    files: dict[str, Change]
    directories: list[str]
    settings: dict[str, str]
    apt_owned: dict[str, bool]
    apt_pending: Transaction
    release: str


class ProvisionError(Exception):
    pass


def run(command: Sequence[str | Path], *, capture: bool = False) -> str:
    try:
        completed = subprocess.run(
            command,
            check=True,
            stdout=subprocess.PIPE if capture else None,
            encoding="utf-8",
            errors="surrogateescape",
            env={**os.environ, "LC_ALL": "C", "DEBIAN_FRONTEND": "noninteractive"},
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        raise ProvisionError(f"could not run {command[0]}: {exc}") from exc
    return completed.stdout if capture else ""


def atomic_write(path: Path, payload: bytes, *, mode: int) -> None:
    fd, name = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    staged = Path(name)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fchmod(stream.fileno(), mode)
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
            payload = self.path.read_text()
        except FileNotFoundError:
            self.values = {}
            return
        try:
            values = json.loads(payload)
        except ValueError as exc:
            raise ProvisionError(f"invalid receipt {self.path}") from exc
        if not isinstance(values, dict):
            raise ProvisionError(f"invalid receipt {self.path}")
        self.values = cast(ReceiptData, values)

    def save(self) -> None:
        payload = json.dumps(self.values, indent=2, sort_keys=True) + "\n"
        atomic_write(self.path, payload.encode(), mode=0o600)

    def clear(self) -> None:
        self.path.unlink(missing_ok=True)
        self.values = {}
        sync_directory(self.path.parent)

    @contextmanager
    def locked(self) -> Iterator[None]:
        self.path.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        lock = self.path.with_suffix(".lock")
        with lock.open("a") as stream:
            flock(stream, LOCK_EX)
            self.load()
            yield
