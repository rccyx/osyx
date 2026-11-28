import io
import os
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path

from core.files import Files, file_image
from core.manifest import entries
from core.state import ErrorTag, ProvisionError, Receipt
from desktop.enablers import Enabler, enablers
from desktop.home import Home
from engine.catalog import catalog
from packages.download import extract
from packages.install import Installer

ROOT = Path(__file__).resolve().parents[1]


class ProvisioningTests(unittest.TestCase):
    def setUp(self) -> None:
        self._temporary = tempfile.TemporaryDirectory()
        self.root = Path(self._temporary.name)
        self.addCleanup(self._temporary.cleanup)

    def test_declarations_require_a_reason(self) -> None:
        path = self.root / "packages.deps"
        path.write_text("btop\n")
        with self.assertRaises(ProvisionError) as error:
            entries(path)
        self.assertEqual(error.exception.tag, ErrorTag.MANIFEST)

    def test_runtime_group_precedes_cargo_tools(self) -> None:
        inventory = catalog(ROOT)
        plan = inventory.resolve(("wl-screenrec",), requires=True)
        expected = (
            "runtime-go",
            "runtime-node",
            "runtime-pnpm",
            "runtime-uv",
            "runtime-python",
            "runtime-rust",
        )
        self.assertEqual(tuple(name for name in plan if name.startswith("runtime-")), expected)
        self.assertLess(plan.index("libavformat-dev"), plan.index("wl-screenrec"))
        self.assertLess(plan.index("runtime-rust"), plan.index("wl-screenrec"))

    def test_workstation_contains_every_enabler_without_firmware(self) -> None:
        inventory = catalog(ROOT)
        plan = inventory.resolve(("workstation",), requires=True)
        self.assertTrue(inventory.enablers.keys() <= set(plan))
        self.assertNotIn("intel-microcode", plan)
        self.assertNotIn("wofi", plan)
        self.assertNotIn("qt6-base-dev", plan)
        self.assertNotIn("clipvault", plan)

    def test_single_destroy_does_not_expand_shared_dependencies(self) -> None:
        inventory = catalog(ROOT)
        self.assertEqual(inventory.resolve(("battery",), requires=False), ("battery",))

    def test_owned_file_apply_is_idempotent(self) -> None:
        receipt = Receipt(self.root / "receipt.json")
        with receipt.locked():
            files = Files(self.root, receipt)
            image = file_image(b"config", 0o644)
            files.install("nested/config", image)
            first = receipt.path.read_bytes()
            files.install("nested/config", image)
            self.assertEqual(first, receipt.path.read_bytes())
            self.assertEqual((self.root / "nested/config").read_bytes(), b"config")

    def test_destroy_restores_existing_file_and_mode(self) -> None:
        path = self.root / "config"
        path.write_bytes(b"original")
        path.chmod(0o600)
        receipt = Receipt(self.root / "receipt.json")
        with receipt.locked():
            files = Files(self.root, receipt)
            files.install("config", file_image(b"replacement", 0o644))
            files.reset()
            receipt.clear()
        self.assertEqual(path.read_bytes(), b"original")
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_destroy_refuses_external_changes(self) -> None:
        receipt = Receipt(self.root / "receipt.json")
        with receipt.locked():
            files = Files(self.root, receipt)
            files.install("config", file_image(b"owned", 0o644))
            (self.root / "config").write_bytes(b"user modification")
            with self.assertRaises(ProvisionError):
                files.reset()
        self.assertEqual((self.root / "config").read_bytes(), b"user modification")

    def test_existing_identical_file_is_not_claimed(self) -> None:
        path = self.root / "config"
        path.write_bytes(b"existing")
        path.chmod(0o644)
        receipt = Receipt(self.root / "receipt.json")
        with receipt.locked():
            files = Files(self.root, receipt)
            files.install("config", file_image(b"existing", 0o644))
            files.reset()
        self.assertEqual(path.read_bytes(), b"existing")

    def test_symlink_parent_cannot_escape_managed_root(self) -> None:
        home = self.root / "home"
        outside = self.root / "outside"
        home.mkdir()
        outside.mkdir()
        (home / "link").symlink_to(outside)
        receipt = Receipt(self.root / "receipt.json")
        with receipt.locked(), self.assertRaises(ProvisionError):
            Files(home, receipt).install("link/config", file_image(b"blocked", 0o644))
        self.assertFalse((outside / "config").exists())

    def test_corrupt_receipt_fails_closed(self) -> None:
        path = self.root / "receipt.json"
        path.write_text('{"files":{"x":{"before":null,"after":123}}}')
        with self.assertRaises(ProvisionError):
            Receipt(path).load()

    def test_archive_cannot_write_outside_staging(self) -> None:
        archive = self.root / "archive.tar"
        with tarfile.open(archive, "w") as payload:
            member = tarfile.TarInfo("../outside")
            member.size = 4
            payload.addfile(member, io.BytesIO(b"evil"))
        with self.assertRaises(ProvisionError):
            extract(archive, self.root / "staging")
        self.assertFalse((self.root / "outside").exists())

    def test_home_copies_tracked_flavor_assets_and_preserves_conflicts(self) -> None:
        checkout = self.root / "repo"
        home = self.root / "user"
        checkout.mkdir()
        home.mkdir()
        subprocess.run(["git", "init", "-q", checkout], check=True)
        source = checkout / "home/flavors/backgrounds"
        source.mkdir(parents=True)
        (source / "image.jpg").write_bytes(b"wallpaper")
        (checkout / "home/.zshrc").write_text("repo")
        (checkout / "home/private.txt").write_text("untracked")
        subprocess.run(["git", "-C", checkout, "add", "home/flavors", "home/.zshrc"], check=True)
        (home / ".zshrc").write_text("user")
        resource = Home(checkout, home)
        with resource.receipt.locked():
            resource.apply(replace=False)
            self.assertEqual((home / "flavors/backgrounds/image.jpg").read_bytes(), b"wallpaper")
            self.assertEqual((home / ".zshrc").read_text(), "user")
            self.assertFalse((home / "private.txt").exists())
            resource.files.reset()
        self.assertFalse((home / "flavors/backgrounds/image.jpg").exists())
        self.assertEqual((home / ".zshrc").read_text(), "user")

    def test_screenshot_destroy_leaves_user_images(self) -> None:
        receipt = Receipt(self.root / "receipt.json")
        with receipt.locked():
            spec = enablers(ROOT / "enablers/manifest.toml")["screenshots"]
            resource = Enabler(Files(self.root, receipt), spec)
            resource.apply(ROOT / "enablers/payload")
            resource.apply(ROOT / "enablers/payload")
            self.assertTrue(os.access(self.root / ".local/bin/shot-full", os.X_OK))
            picture = self.root / "Pictures/Screenshots/user.png"
            picture.parent.mkdir(parents=True)
            picture.write_bytes(b"image")
            resource.destroy()
        self.assertFalse((self.root / ".local/bin/shot-full").exists())
        self.assertEqual(picture.read_bytes(), b"image")

    @unittest.skipIf(
        Path(f"/run/user/{os.getuid()}/bus").exists(), "requires an offline user session"
    )
    def test_battery_timer_files_and_link_are_removed(self) -> None:
        receipt = Receipt(self.root / "receipt.json")
        with receipt.locked():
            resource = Enabler(
                Files(self.root, receipt), enablers(ROOT / "enablers/manifest.toml")["battery"]
            )
            resource.apply(ROOT / "enablers/payload")
            unit = self.root / ".config/systemd/user/battery-notify.timer"
            link = unit.parent / "timers.target.wants/battery-notify.timer"
            self.assertEqual(link.resolve(), unit)
            self.assertTrue(unit.is_file())
            resource.destroy()
        self.assertFalse(unit.exists())
        self.assertFalse(link.is_symlink())

    def test_package_executable_hash_detects_payload_modification(self) -> None:
        installer = Installer("example", self.root)
        with installer.receipt.locked():
            self.assertTrue(installer.prepare("1.0.0"))
            binary = installer.target / "bin/example"
            binary.parent.mkdir(parents=True)
            binary.write_text("#!/bin/sh\nprintf 'hello\\n'\n")
            binary.chmod(0o755)
            commands = {"example": "bin/example"}
            installer.publish(commands)
            installer.finish(commands)
            self.assertFalse(installer.prepare("1.0.0"))
            output = subprocess.check_output([installer.bin / "example"], text=True)
            self.assertEqual(output, "hello\n")
            binary.write_text("#!/bin/sh\nexit 2\n")
            with self.assertRaises(ProvisionError):
                installer.doctor(commands, version="1.0.0")
            installer.reset()
        self.assertFalse(installer.target.exists())
        self.assertFalse((installer.bin / "example").is_symlink())


if __name__ == "__main__":
    unittest.main()