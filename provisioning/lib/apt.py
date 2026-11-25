import json
from pathlib import Path
from typing import cast

from state import Package, ProvisionError, Receipt, Transaction, run


class Apt:
    def __init__(self, receipt: Receipt, packages: dict[str, str]):
        self.receipt = receipt
        self.packages = packages
        self.arch = run(["dpkg", "--print-architecture"], capture=True).strip()

    def plan(self) -> None:
        installed = self._inventory()
        missing = self._missing(installed)
        for name in missing:
            print(f"install {name} ({self.packages[name]})")
        if missing and not any(Path("/var/lib/apt/lists").glob("*_Packages*")):
            print("APT dependency resolution requires fresh package indexes at apply")
        pending = self._pending()
        if pending:
            print(f"resume pending APT {pending['action']}")

    def apply(self) -> None:
        self._recover()
        inventory = self._inventory()
        missing = self._missing(inventory)
        if not missing:
            return

        run(["apt-get", "update"])
        inventory = self._inventory()
        missing = self._missing(inventory)
        if not missing:
            return
        install, remove = self._simulate(
            ["install", "--no-install-recommends", *missing]
        )
        if remove:
            raise ProvisionError(
                f"APT would remove existing packages: {', '.join(remove)}"
            )
        before = {name: inventory.get(name) for name in install}
        conflicts = [name for name, package in before.items() if package is not None]
        if conflicts:
            raise ProvisionError(
                f"APT would change existing packages: {', '.join(conflicts)}"
            )
        self._begin({"action": "install", "before": before, "remove": []})
        run(
            [
                "apt-get",
                "-y",
                "--no-remove",
                "install",
                "--no-install-recommends",
                *missing,
            ]
        )
        self._recover()
        self.doctor()

    def doctor(self) -> None:
        if self._pending():
            raise ProvisionError("APT transaction incomplete")
        missing = self._missing(self._inventory())
        if missing:
            raise ProvisionError(f"missing system packages: {', '.join(missing)}")

    def plan_remove(self) -> list[str]:
        installed = self._inventory()
        owned = self._owned()
        present = sorted(name for name in owned if name in installed)
        if not present:
            return []
        manual = set(run(["apt-mark", "showmanual"], capture=True).splitlines())
        for name in present:
            unqualified = name.split(":")[0]
            if owned[name] != (name in manual or unqualified in manual):
                raise ProvisionError(f"APT manual/auto mark changed for {name}")
        install, remove = self._simulate(["purge", *present])
        unexpected = sorted(set(remove) - set(present))
        if install or unexpected:
            raise ProvisionError(
                f"APT removal would change outside packages: {install + unexpected}"
            )
        for name in present:
            print(f"purge {name}")
        return present

    def reset(self) -> None:
        self._recover()
        present = self.plan_remove()
        if not present:
            return
        self._begin({"action": "purge", "before": {}, "remove": present})
        run(["apt-get", "-y", "purge", *present])
        self._recover()
        if self._owned():
            raise ProvisionError(f"APT left owned packages: {', '.join(self._owned())}")

    def recover(self) -> None:
        self._recover()

    def _begin(self, transaction: Transaction) -> None:
        self.receipt.values["apt_pending"] = transaction
        self.receipt.save()

    def _recover(self) -> None:
        pending = self._pending()
        if pending is None:
            return
        inventory = self._inventory()
        interrupted = [
            name
            for name, package in inventory.items()
            if package["status"] not in ("installed", "config-files", "not-installed")
        ]
        if interrupted:
            raise ProvisionError(
                f"dpkg needs recovery before retrying: {', '.join(interrupted)}"
            )
        owned = self._owned()
        if pending["action"] == "install":
            manual = set(run(["apt-mark", "showmanual"], capture=True).splitlines())
            for name in pending["before"]:
                if name in inventory:
                    owned[name] = name in manual or name.split(":")[0] in manual
        else:
            owned = {
                name: manual for name, manual in owned.items() if name in inventory
            }
        self.receipt.values["apt_owned"] = owned
        del self.receipt.values["apt_pending"]
        self.receipt.save()

    def _owned(self) -> dict[str, bool]:
        return self.receipt.values.get("apt_owned", {})

    def _pending(self) -> Transaction | None:
        return self.receipt.values.get("apt_pending")

    def _missing(self, inventory: dict[str, Package]) -> list[str]:
        return [
            name
            for name in self.packages
            if name not in inventory or inventory[name]["status"] != "installed"
        ]

    def _inventory(self) -> dict[str, Package]:
        command = [
            "dpkg-query",
            "-W",
            "-f=${Package}\t${Architecture}\t${db:Status-Status}\t${Version}\n",
        ]
        inventory: dict[str, Package] = {}
        for line in run(command, capture=True).splitlines():
            name, arch, status, version = line.split("\t")
            key = name if arch in (self.arch, "all", "") else f"{name}:{arch}"
            if status != "not-installed":
                inventory[key] = {"status": status, "version": version}
        return inventory

    def _simulate(self, args: list[str]) -> tuple[list[str], list[str]]:
        lines = run(["apt-get", "-s", *args], capture=True).splitlines()
        install = []
        remove = []
        for line in lines:
            fields = line.split()
            if len(fields) < 2:
                continue
            operation, name = fields[:2]
            name = name.removesuffix(f":{self.arch}")
            if operation == "Inst":
                install.append(name)
            elif operation in ("Remv", "Purg"):
                remove.append(name)
        return install, remove


def package_manifest(path: Path) -> dict[str, str]:
    return cast(dict[str, str], json.loads(path.read_text()))
