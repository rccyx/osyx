import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

from core.files import Files, file_image, read_image
from core.manifest import mapping, string, string_map, strings, table
from core.state import ErrorTag, Image, ProvisionError, run


@dataclass(frozen=True)
class EnablerSpec:
    files: dict[str, str]
    requires: tuple[str, ...]
    timer: str = ""


def enablers(path: Path) -> dict[str, EnablerSpec]:
    result: dict[str, EnablerSpec] = {}
    for name, raw in table(path).items():
        value = mapping(raw)
        result[name] = EnablerSpec(
            string_map(value["files"]),
            tuple(strings(value["requires"])),
            string(value["timer"]) if "timer" in value else "",
        )
    return result


class Enabler:
    def __init__(self, files: Files, spec: EnablerSpec):
        self.files = files
        self.spec = spec

    def plan(self, payload: Path) -> None:
        for name, image in self._images(payload).items():
            current = read_image(self.files.path(name))
            if current != image:
                if current is not None and name not in self.files.changes():
                    raise ProvisionError(ErrorTag.CONFLICT, f"unmanaged enabler file: {name}")
                print(f"apply {self.files.path(name)}")

    def apply(self, payload: Path) -> None:
        self.plan(payload)
        for name, image in self._images(payload).items():
            self.files.install(name, image)
        if self.spec.timer and _session():
            _userctl(["daemon-reload"])
            if not _active(self.spec.timer):
                self.files.receipt.values.setdefault("settings", {})["started"] = "yes"
                self.files.receipt.save()
                _userctl(["start", self.spec.timer])
        self.files.receipt.values["completed"] = True
        self.files.receipt.save()

    def doctor(self, payload: Path) -> None:
        for name, image in self._images(payload).items():
            if read_image(self.files.path(name)) != image:
                raise ProvisionError(ErrorTag.VERIFY, f"missing or changed enabler file: {name}")
        if self.spec.timer and _session() and not _active(self.spec.timer):
            raise ProvisionError(ErrorTag.VERIFY, f"inactive user timer: {self.spec.timer}")

    def destroy(self) -> None:
        self.files.plan_remove()
        settings = self.files.receipt.values.get("settings", {})
        timer_link = f".config/systemd/user/timers.target.wants/{self.spec.timer}"
        if self.spec.timer and _session():
            if timer_link in self.files.changes() or settings.get("started") == "yes":
                _userctl(["stop", self.spec.timer])
                _userctl(["stop", self.spec.timer.removesuffix(".timer") + ".service"])
        self.files.reset()
        if self.spec.timer and _session():
            _userctl(["daemon-reload"])
        self.files.receipt.clear()

    def _images(self, payload: Path) -> dict[str, Image]:
        images: dict[str, Image] = {}
        for name, filename in self.spec.files.items():
            if Path(filename).name != filename or filename in (".", ".."):
                raise ProvisionError(ErrorTag.MANIFEST, f"invalid enabler payload: {filename}")
            mode = 0o755 if name.startswith(".local/bin/") else 0o644
            images[name] = file_image((payload / filename).read_bytes(), mode)
        if self.spec.timer:
            timer = self.spec.timer
            if Path(timer).name != timer or not timer.endswith(".timer"):
                raise ProvisionError(ErrorTag.MANIFEST, f"invalid timer: {timer}")
            images[f".config/systemd/user/timers.target.wants/{timer}"] = {
                "kind": "link",
                "value": f"../{timer}",
            }
        return images


def _session() -> bool:
    return Path(f"/run/user/{os.getuid()}/bus").exists()


def _userctl(args: list[str]) -> None:
    run(["env", f"XDG_RUNTIME_DIR=/run/user/{os.getuid()}", "systemctl", "--user", *args])


def _active(timer: str) -> bool:
    result = subprocess.run(
        [
            "env",
            f"XDG_RUNTIME_DIR=/run/user/{os.getuid()}",
            "systemctl",
            "--user",
            "is-active",
            "--quiet",
            timer,
        ],
        check=False,
    )
    return result.returncode == 0
