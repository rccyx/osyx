from core.manifest import Entry
from core.state import ErrorTag, ProvisionError, Receipt, run

PROTECTED = frozenset({"sudo", "git", "python3", "curl", "ca-certificates"})


class Apt:
    def __init__(self, receipt: Receipt, packages: dict[str, Entry]):
        self.receipt = receipt
        self.packages = packages
        self.arch = run(["dpkg", "--print-architecture"], capture=True).strip()

    def plan(self, names: list[str]) -> None:
        installed = self._inventory()
        for name in names:
            item = self.packages[name]
            if self._missing(item, installed):
                print(f"apply APT {self._spec(item)} # {item.reason}")
        if self.receipt.values.get("apt_pending"):
            print("resume pending APT transaction")

    def apply(self, names: list[str]) -> None:
        self._recover()
        installed = self._inventory()
        requested = [name for name in names if self._missing(self.packages[name], installed)]
        if not requested:
            return
        run(["apt-get", "update"])
        installed = self._inventory()
        requested = [name for name in names if self._missing(self.packages[name], installed)]
        if not requested:
            return
        specs = [self._spec(self.packages[name]) for name in requested]
        additions, removals = self._simulate(["install", "--no-install-recommends", *specs])
        if removals:
            raise ProvisionError(
                ErrorTag.CONFLICT, f"APT would remove installed packages: {removals}"
            )
        owned = self.receipt.values.get("apt_owned", {})
        # record only packages absent before OSYX, including automatically added libraries
        fresh = [name for name in additions if name not in installed and name not in owned]
        self._begin({"apply": fresh, "destroy": []})
        run(["apt-get", "-y", "--no-remove", "install", "--no-install-recommends", *specs])
        self._recover()
        self.doctor(names)

    def doctor(self, names: list[str]) -> None:
        installed = self._inventory()
        missing = [name for name in names if self._missing(self.packages[name], installed)]
        if missing:
            raise ProvisionError(
                ErrorTag.VERIFY, f"missing or mismatched APT packages: {', '.join(missing)}"
            )

    def plan_remove(self, names: list[str]) -> list[str]:
        owned = self.receipt.values.get("apt_owned", {})
        installed = self._inventory()
        present = sorted(set(names) & owned.keys() & installed.keys() - PROTECTED)
        if not present:
            return []
        manual = self._manual()
        for name in present:
            if owned[name] != (name in manual):
                raise ProvisionError(ErrorTag.CONFLICT, f"APT manual/auto mark changed: {name}")
        additions, removals = self._simulate(["purge", *present])
        outside = set(removals) - set(present)
        eligible = {
            name
            for name, manual_mark in owned.items()
            if not manual_mark and name not in manual and name not in self.packages
        }
        if additions or outside - eligible:
            raise ProvisionError(
                ErrorTag.CONFLICT,
                f"APT purge would alter other packages: {additions + sorted(outside - eligible)}",
            )
        present = sorted(set(present) | outside)
        for name in present:
            print(f"destroy APT {name}")
        return present

    def reset(self, names: list[str]) -> None:
        self._recover()
        present = self.plan_remove(names)
        if present:
            self._begin({"apply": [], "destroy": present})
            run(["apt-get", "-y", "purge", *present])
            self._recover()
        # only remove orphaned dependencies introduced by this provisioner
        if not present:
            return
        _, orphaned = self._simulate(["autoremove", "--purge"])
        owned = self.receipt.values.get("apt_owned", {})
        automatic = (
            set(orphaned)
            & {name for name, manual in owned.items() if not manual}
            - PROTECTED
            - self.packages.keys()
        )
        if automatic:
            self._purge_orphans(sorted(automatic))

    def _purge_orphans(self, names: list[str]) -> None:
        additions, remove = self._simulate(["purge", *names])
        if additions or set(remove) - set(names):
            return
        self._begin({"apply": [], "destroy": names})
        run(["apt-get", "-y", "purge", *names])
        self._recover()

    def _begin(self, pending: dict[str, list[str]]) -> None:
        self.receipt.values["apt_pending"] = pending
        self.receipt.save()

    def _recover(self) -> None:
        pending = self.receipt.values.get("apt_pending")
        if not pending:
            return
        inventory = self._inventory()
        if run(["dpkg", "--audit"], capture=True).strip():
            raise ProvisionError(
                ErrorTag.HOST, "dpkg has unfinished work; repair dpkg before retrying"
            )
        owned = self.receipt.values.setdefault("apt_owned", {})
        manual = self._manual()
        for name in pending["apply"]:
            if name in inventory:
                owned[name] = name in manual
        for name in pending["destroy"]:
            if name not in inventory:
                owned.pop(name, None)
        del self.receipt.values["apt_pending"]
        self.receipt.save()

    def _manual(self) -> set[str]:
        return {
            name.removesuffix(f":{self.arch}")
            for name in run(["apt-mark", "showmanual"], capture=True).splitlines()
        }

    def _inventory(self) -> dict[str, str]:
        output = run(
            [
                "dpkg-query",
                "-W",
                "-f=${Package}\t${Architecture}\t${db:Status-Status}\t${Version}\n",
            ],
            capture=True,
        )
        result: dict[str, str] = {}
        for line in output.splitlines():
            name, arch, status, version = line.split("\t")
            if status == "installed":
                result[name if arch in (self.arch, "all") else f"{name}:{arch}"] = version
            elif status == "config-files":
                result[name if arch in (self.arch, "all") else f"{name}:{arch}"] = ""
        return result

    def _simulate(self, args: list[str]) -> tuple[list[str], list[str]]:
        additions: list[str] = []
        removals: list[str] = []
        for line in run(["apt-get", "-s", *args], capture=True).splitlines():
            fields = line.split()
            if len(fields) < 2:
                continue
            operation, name = fields[:2]
            name = name.removesuffix(f":{self.arch}")
            if operation == "Inst":
                additions.append(name)
            elif operation in ("Remv", "Purg"):
                removals.append(name)
        return additions, removals

    def _missing(self, entry: Entry, installed: dict[str, str]) -> bool:
        actual = installed.get(entry.name, "")
        return not actual or (bool(entry.version) and actual != entry.version)

    def _spec(self, entry: Entry) -> str:
        return f"{entry.name}={entry.version}" if entry.version else entry.name
