import hashlib
import tempfile
import unittest
from pathlib import Path

from core.files import Files
from core.state import ErrorTag, ProvisionError, Receipt
from host.network import Network


class NetworkTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.config = self.root / "etc/iwd/main.conf"
        self.config.parent.mkdir(parents=True)
        self.default = b"[General]\n#EnableNetworkConfiguration=true\n"
        self.config.write_bytes(self.default)
        self.config.chmod(0o644)
        digest = hashlib.md5(self.default, usedforsecurity=False).hexdigest()
        database = self.root / "var/lib/dpkg/status"
        database.parent.mkdir(parents=True)
        database.write_text(
            "Package: iwd\n"
            "Status: install ok installed\n"
            "Architecture: amd64\n"
            "Version: 3.8-2\n"
            "Maintainer: Test <test@example.invalid>\n"
            "Description: test fixture\n"
            f"Conffiles:\n /etc/iwd/main.conf {digest}\n"
        )
        self.receipt = Receipt(self.root / "receipt.json")
        self.network = Network(Files(self.root, self.receipt))

    def test_packaged_configuration_is_replaced_and_restored(self) -> None:
        with self.receipt.locked():
            self.network.apply()
            self.network.doctor()
            self.assertIn(b"EnableNetworkConfiguration=true\n", self.config.read_bytes())
            self.assertNotIn(b"#EnableNetworkConfiguration", self.config.read_bytes())
            self.assertIn("etc/iwd/main.conf", self.network.files.changes())
            before = self.receipt.path.read_bytes()
            self.network.apply()
            self.assertEqual(before, self.receipt.path.read_bytes())
            self.network.destroy()
        self.assertEqual(self.config.read_bytes(), self.default)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o644)
        self.assertFalse(self.receipt.path.exists())

    def test_locally_modified_configuration_is_preserved(self) -> None:
        custom = b"[General]\nAddressRandomization=network\n"
        self.config.write_bytes(custom)
        with self.receipt.locked(), self.assertRaises(ProvisionError) as error:
            self.network.apply()
        self.assertEqual(error.exception.tag, ErrorTag.CONFLICT)
        self.assertEqual(self.config.read_bytes(), custom)
        self.assertFalse((self.root / "etc/systemd").exists())

    def test_symlink_configuration_is_not_replaced(self) -> None:
        original = self.config.with_name("custom.conf")
        self.config.rename(original)
        self.config.symlink_to(original.name)
        with self.receipt.locked(), self.assertRaises(ProvisionError) as error:
            self.network.apply()
        self.assertEqual(error.exception.tag, ErrorTag.CONFLICT)
        self.assertTrue(self.config.is_symlink())
        self.assertEqual(original.read_bytes(), self.default)


if __name__ == "__main__":
    unittest.main()