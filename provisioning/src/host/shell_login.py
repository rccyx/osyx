import pwd

from core.state import ErrorTag, ProvisionError, Receipt, run


class LoginShell:
    def __init__(self, receipt: Receipt, username: str):
        self.receipt = receipt
        self.username = username

    def plan(self) -> None:
        if self._current() != "/usr/bin/zsh":
            print(f"apply login shell zsh for {self.username}")

    def apply(self) -> None:
        self.plan()
        current = self._current()
        if current == "/usr/bin/zsh":
            return
        previous = self.receipt.values.setdefault("settings", {}).get("before")
        if previous and previous != current:
            raise ProvisionError(ErrorTag.CONFLICT, "login shell changed outside OSYX")
        self.receipt.values["settings"] = {"before": current, "user": self.username}
        self.receipt.save()
        run(["usermod", "--shell", "/usr/bin/zsh", self.username])

    def doctor(self) -> None:
        if self._current() != "/usr/bin/zsh":
            raise ProvisionError(ErrorTag.VERIFY, "zsh is not the login shell")

    def destroy(self) -> None:
        settings = self.receipt.values.get("settings", {})
        previous = settings.get("before")
        if previous:
            current = self._current()
            if current not in (previous, "/usr/bin/zsh"):
                raise ProvisionError(ErrorTag.CONFLICT, "login shell changed outside OSYX")
            if current != previous:
                run(["usermod", "--shell", previous, self.username])
        self.receipt.clear()

    def _current(self) -> str:
        return pwd.getpwnam(self.username).pw_shell
