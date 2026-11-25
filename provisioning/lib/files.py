import base64
import hashlib
import json
import os
import stat
import tempfile
from pathlib import Path

from state import Change, Image, ProvisionError, Receipt, atomic_write, sync_directory


def file_image(payload: bytes, mode: int) -> Image:
    return {
        "kind": "file",
        "mode": mode,
        "value": base64.b64encode(payload).decode(),
    }


def read_image(path: Path) -> Image | None:
    try:
        info = path.lstat()
    except FileNotFoundError:
        return None
    if stat.S_ISLNK(info.st_mode):
        return {"kind": "link", "value": os.readlink(path)}
    if not stat.S_ISREG(info.st_mode):
        raise ProvisionError(f"expected a file or symlink at {path}")
    return file_image(path.read_bytes(), stat.S_IMODE(info.st_mode))


class Files:
    def __init__(self, root: Path, receipt: Receipt):
        self.root = root
        self.receipt = receipt

    def path(self, name: str) -> Path:
        relative = Path(name)
        if relative.is_absolute() or not relative.parts or ".." in relative.parts:
            raise ProvisionError(f"invalid managed path {name}")
        path = self.root / relative
        for parent in relative.parents:
            directory = self.root / parent
            if directory.is_symlink():
                raise ProvisionError(f"managed path traverses symlink {directory}")
        return path

    def changes(self) -> dict[str, Change]:
        return self.receipt.values.get("files", {})

    def install(self, name: str, image: Image) -> None:
        path = self.path(name)
        current = read_image(path)
        changes = self.changes()
        previous = changes.get(name)
        if previous and not _matches_change(current, previous):
            raise ProvisionError(f"managed file has changed: {path}")
        if current == image:
            return

        self._parents(path.parent)
        before = previous["before"] if previous else current
        changes[name] = {"before": before, "after": fingerprint(image)}
        self.receipt.values["files"] = changes
        self.receipt.save()
        _write_image(path, image)

    def plan_remove(self) -> None:
        for name, change in self.changes().items():
            path = self.path(name)
            current = read_image(path)
            if not _matches_change(current, change):
                raise ProvisionError(f"managed file has changed: {path}")
            if current != change["before"]:
                action = "restore" if change["before"] is not None else "remove"
                print(f"{action} {path}")

    def reset(self) -> None:
        self.plan_remove()
        for name, change in self.changes().items():
            path = self.path(name)
            if read_image(path) != change["before"]:
                _write_image(path, change["before"])
        directories = self.receipt.values.get("directories", [])
        for name in reversed(directories):
            path = self.path(name)
            if path.is_symlink() or not path.is_dir() or any(path.iterdir()):
                continue
            path.rmdir()

    def _parents(self, parent: Path) -> None:
        if parent == self.root or parent.is_dir():
            return
        self._parents(parent.parent)
        directories = self.receipt.values.setdefault("directories", [])
        name = str(parent.relative_to(self.root))
        if name not in directories:
            directories.append(name)
            self.receipt.save()
        parent.mkdir()


def _write_image(path: Path, image: Image | None) -> None:
    if image is None:
        path.unlink(missing_ok=True)
        sync_directory(path.parent)
    elif image["kind"] == "file":
        atomic_write(path, base64.b64decode(image["value"]), mode=image["mode"])
    else:
        with tempfile.TemporaryDirectory(dir=path.parent) as staging:
            link = Path(staging) / path.name
            link.symlink_to(image["value"])
            link.replace(path)
            sync_directory(path.parent)


def fingerprint(image: Image | None) -> str:
    return hashlib.sha256(json.dumps(image, sort_keys=True).encode()).hexdigest()


def _matches_change(current: Image | None, change: Change) -> bool:
    return (
        current in (None, change["before"]) or fingerprint(current) == change["after"]
    )
