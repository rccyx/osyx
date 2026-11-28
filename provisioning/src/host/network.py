import base64
import hashlib
import subprocess
from pathlib import Path

from core.files import Files, file_image, read_image
from core.state import ErrorTag, Image, ProvisionError, run

UNITS = ("systemd-networkd.service", "systemd-resolved.service", "iwd.service")


class Network:
    def __init__(self, files: Files):
        self.files = files

    def plan(self) -> None:
        if self._competing():
            print("preserve active network manager; migrate networking separately")
            return
        for name, image in self._images().items():
            if not self._matches(name, image):
                print(f"apply {name}")
        print("configure iwd and networkd for the next boot")

    def apply(self) -> None:
        if self._competing():
            print("preserve existing network manager and DNS configuration")
            return
        images = self._images()
        for name, image in images.items():
            current = read_image(self.files.path(name))
            if (
                current is not None
                and not self._matches(name, image)
                and name not in self.files.changes()
                and not self._packaged_default(name, current)
            ):
                raise ProvisionError(
                    ErrorTag.CONFLICT, f"existing network configuration: {name}"
                )
        for name, image in images.items():
            if not self._matches(name, image):
                self.files.install(name, image)
                print(f"apply {name}")
        self.files.receipt.values["completed"] = True
        self.files.receipt.save()
        if self._live():
            run(["systemctl", "daemon-reload"])
        print("configured iwd and networkd for the next boot")

    def doctor(self) -> None:
        if self._competing():
            print("existing network manager retained")
            return
        for name, image in self._images().items():
            if not self._matches(name, image):
                raise ProvisionError(ErrorTag.VERIFY, f"missing network setup: {name}")

    def destroy(self) -> None:
        # avoid stopping live network services or cutting off a remote session
        self.files.reset()
        self.files.receipt.clear()
        if self._live():
            run(["systemctl", "daemon-reload"])
        print("network configuration restored; reboot when safe")

    def _packaged_default(self, name: str, current: Image) -> bool:
        if name != "etc/iwd/main.conf" or current["kind"] != "file":
            return False
        conffiles = run(
            ["dpkg-query", f"--root={self.files.root}", "-W", "-f=${Conffiles}", "iwd"],
            capture=True,
        )
        digest = hashlib.md5(base64.b64decode(current["value"]), usedforsecurity=False).hexdigest()
        return any(line.split() == [f"/{name}", digest] for line in conffiles.splitlines())

    def _live(self) -> bool:
        return self.files.root == Path("/") and Path("/run/systemd/system").exists()

    def _matches(self, name: str, image: Image) -> bool:
        path = self.files.path(name)
        current = read_image(path)
        if current == image:
            return True
        if current and current["kind"] == image["kind"] == "link":
            return path.resolve() == (path.parent / image["value"]).resolve()
        return False

    def _competing(self) -> bool:
        if not self._live():
            return False
        for unit in (
            "NetworkManager.service",
            "networking.service",
            "connman.service",
            "dhcpcd.service",
        ):
            if (
                subprocess.run(["systemctl", "is-active", "--quiet", unit], check=False).returncode
                == 0
            ):
                return True
        return False

    def _images(self) -> dict[str, Image]:
        images: dict[str, Image] = {
            "etc/iwd/main.conf": file_image(
                b"[General]\nEnableNetworkConfiguration=true\n[Network]\nNameResolvingService=systemd\n",
                0o644,
            ),
            "etc/systemd/network/90-osyx-ethernet.network": file_image(
                b"[Match]\nName=en* eth*\n[Network]\nDHCP=yes\n", 0o644
            ),
        }
        for unit in UNITS:
            source = Path("/usr/lib/systemd/system") / unit
            if not source.is_file():
                source = Path("/lib/systemd/system") / unit
            if not source.is_file():
                # plan can run before the APT dependencies are installed
                source = Path("/usr/lib/systemd/system") / unit
            images[f"etc/systemd/system/multi-user.target.wants/{unit}"] = {
                "kind": "link",
                "value": str(source),
            }
        return images