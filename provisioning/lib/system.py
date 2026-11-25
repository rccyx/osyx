import re
from dataclasses import dataclass
from pathlib import Path

from apt import Apt, package_manifest
from files import Files, file_image, read_image
from state import Image, ProvisionError, Receipt, run


@dataclass(frozen=True)
class Settings:
    user: str
    locale: str
    timezone: str


class System:
    def __init__(self, repository: Path, receipt: Receipt):
        self.receipt = receipt
        self.files = Files(Path("/"), receipt)
        self.apt = Apt(
            receipt, package_manifest(repository / "provisioning/system.json")
        )

    def settings(self, request: Settings) -> Settings:
        prior = self.receipt.values.get("settings", {})
        if prior and prior["user"] != request.user:
            raise ProvisionError(f"system is managed for {prior['user']}")
        locale = request.locale or prior.get("locale", "")
        timezone = request.timezone or prior.get("timezone", "")
        if not re.fullmatch(r"[a-z]{2,3}(?:_[A-Z]{2})?\.UTF-8", locale):
            raise ProvisionError("specify a UTF-8 locale with --locale")
        if not re.fullmatch(r"[A-Za-z0-9_+-]+(?:/[A-Za-z0-9_+-]+)*", timezone):
            raise ProvisionError("specify a timezone with --timezone")
        return Settings(request.user, locale, timezone)

    def plan(self, settings: Settings) -> None:
        self.apt.plan()
        grant = self.files.path(_sudoers(settings))
        if read_image(grant) != _sudo_grant(settings):
            print(f"configure sudo for {settings.user}")
        localtime = self.files.path("etc/localtime")
        if localtime.resolve() != _zoneinfo(settings).resolve():
            print(f"set timezone {settings.timezone}")
        if not self._locale_set(settings):
            print(f"set locale {settings.locale}")

    def apply(self, settings: Settings) -> None:
        self.plan(settings)
        if not self.receipt.values.get("settings"):
            self.receipt.values["settings"] = {
                "user": settings.user,
                "locale": settings.locale,
                "timezone": settings.timezone,
            }
            self.receipt.save()
        self.apt.apply()
        self._configure(settings)
        current = {
            "user": settings.user,
            "locale": settings.locale,
            "timezone": settings.timezone,
        }
        if self.receipt.values["settings"] != current:
            self.receipt.values["settings"] = current
            self.receipt.save()
        self.doctor(settings)

    def doctor(self, settings: Settings) -> None:
        self.apt.doctor()
        if read_image(self.files.path(_sudoers(settings))) != _sudo_grant(settings):
            raise ProvisionError(f"sudo grant missing or changed for {settings.user}")
        run(["visudo", "-cf", "/etc/sudoers"], capture=True)
        if self.files.path("etc/localtime").resolve() != _zoneinfo(settings).resolve():
            raise ProvisionError(f"timezone differs from {settings.timezone}")
        if not self._locale_set(settings) or not _locale_available(settings):
            raise ProvisionError(f"locale is not configured: {settings.locale}")
        run(["nix", "--version"], capture=True)
        print("Debian base checked")

    def plan_remove(self) -> None:
        if "apt_pending" in self.receipt.values:
            print("reconcile pending APT transaction before removal")
        self.apt.plan_remove()
        self.files.plan_remove()

    def reset(self) -> None:
        self.apt.recover()
        self.apt.plan_remove()
        path = self.files.path("etc/locale.gen")
        previous = self.files.changes().get("etc/locale.gen")
        regenerate = previous and read_image(path) != previous["before"]
        self.files.reset()
        if regenerate:
            run(["locale-gen"])
        self.apt.reset()

    def _configure(self, settings: Settings) -> None:
        if not _zoneinfo(settings).is_file():
            raise ProvisionError(f"unknown timezone {settings.timezone}")
        sudoers = _sudoers(settings)
        if sudoers not in self.files.changes() and self.files.path(sudoers).exists():
            if read_image(self.files.path(sudoers)) != _sudo_grant(settings):
                raise ProvisionError(f"sudoers grant already exists at /{sudoers}")
        self.files.install(sudoers, _sudo_grant(settings))
        if self.files.path("etc/localtime").resolve() != _zoneinfo(settings).resolve():
            self.files.install(
                "etc/localtime", {"kind": "link", "value": str(_zoneinfo(settings))}
            )
        self._configure_locale(settings)

    def _configure_locale(self, settings: Settings) -> None:
        supported = Path("/usr/share/i18n/SUPPORTED").read_text().splitlines()
        entry = f"{settings.locale} UTF-8"
        if entry not in supported:
            raise ProvisionError(f"unsupported locale {settings.locale}")
        path = self.files.path("etc/locale.gen")
        old = _text(path)
        if entry not in old.splitlines():
            lines = [
                entry if line == f"# {entry}" else line for line in old.splitlines()
            ]
            if entry not in lines:
                lines.append(entry)
            self.files.install(
                "etc/locale.gen", file_image(("\n".join(lines) + "\n").encode(), 0o644)
            )
        if not _locale_available(settings):
            run(["locale-gen"])
        if not self._locale_set(settings):
            path = self.files.path("etc/locale.conf")
            lines = [
                line
                for line in _text(path).splitlines()
                if not line.startswith("LANG=")
            ]
            lines.append(f"LANG={settings.locale}")
            self.files.install(
                "etc/locale.conf", file_image(("\n".join(lines) + "\n").encode(), 0o644)
            )

    def _locale_set(self, settings: Settings) -> bool:
        path = self.files.path("etc/locale.conf")
        return any(
            line.removeprefix("LANG=").strip("\"'") == settings.locale
            for line in _text(path).splitlines()
            if line.startswith("LANG=")
        )


def _sudoers(settings: Settings) -> str:
    return f"etc/sudoers.d/osyx-{settings.user}"


def _sudo_grant(settings: Settings) -> Image:
    return file_image(f"{settings.user} ALL=(ALL:ALL) ALL\n".encode(), 0o440)


def _zoneinfo(settings: Settings) -> Path:
    return Path("/usr/share/zoneinfo") / settings.timezone


def _locale_available(settings: Settings) -> bool:
    available = run(["locale", "-a"], capture=True).splitlines()
    return settings.locale.replace("UTF-8", "utf8") in available


def _text(path: Path) -> str:
    try:
        return path.read_text()
    except FileNotFoundError:
        return ""
