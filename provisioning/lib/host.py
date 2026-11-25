import pwd
from pathlib import Path

from apt import Apt, package_manifest
from files import Files
from request import REPOSITORY, SYSTEM_RECEIPT, Request
from state import ProvisionError, Receipt, run
from system import System


def desktop(request: Request) -> None:
    receipt = Receipt(SYSTEM_RECEIPT.with_name("desktop.json"))
    apt = Apt(receipt, package_manifest(REPOSITORY / "provisioning/desktop.json"))
    files = Files(Path("/"), receipt)
    user = request.settings.user
    shell = Path("/usr/bin/zsh")
    if request.action == "apply":
        with receipt.locked():
            _check_owner(receipt, user)
            apt.apply()
            current_shell = pwd.getpwnam(user).pw_shell
            if Path(current_shell).resolve() != shell.resolve():
                settings = receipt.values.get("settings")
                if settings is not None and settings["shell"] != current_shell:
                    raise ProvisionError(f"login shell changed for {user}")
                receipt.values["settings"] = {"user": user, "shell": current_shell}
                receipt.save()
                run(["usermod", "-s", shell, user])
            for name, binary in {"fd": "fdfind", "bat": "batcat"}.items():
                if (
                    not Path(f"/usr/bin/{name}").exists()
                    and not Path(f"/usr/local/bin/{name}").exists()
                ):
                    files.install(
                        f"usr/local/bin/{name}",
                        {"kind": "link", "value": f"/usr/bin/{binary}"},
                    )
    elif request.action == "reset":
        with receipt.locked():
            _check_owner(receipt, user)
            if receipt.values:
                apt.recover()
                apt.plan_remove()
                settings = receipt.values.get("settings")
                if settings:
                    current = pwd.getpwnam(user).pw_shell
                    if current not in (str(shell), settings["shell"]):
                        raise ProvisionError(f"login shell changed for {user}")
                    if current != settings["shell"]:
                        run(["usermod", "-s", settings["shell"], user])
                files.reset()
                apt.reset()
                receipt.clear()
    else:
        receipt.load()
        _check_owner(receipt, user)
        if request.remove:
            settings = receipt.values.get("settings")
            if settings:
                print(f"restore login shell {settings['shell']} for {user}")
            apt.plan_remove()
            files.plan_remove()
        elif request.action == "doctor":
            apt.doctor()
        else:
            apt.plan()
            if Path(pwd.getpwnam(user).pw_shell).resolve() != shell.resolve():
                print(f"set login shell to {shell} for {user}")


def system(request: Request) -> None:
    receipt = Receipt(SYSTEM_RECEIPT)
    system = System(REPOSITORY, receipt)
    if request.action in ("apply", "reset"):
        with receipt.locked():
            _check_owner(receipt, request.settings.user)
            if request.action == "apply":
                system.apply(system.settings(request.settings))
            elif receipt.values:
                system.reset()
                receipt.clear()
        return

    receipt.load()
    _check_owner(receipt, request.settings.user)
    if request.remove:
        system.plan_remove()
    elif request.action == "doctor":
        system.doctor(system.settings(request.settings))
    else:
        system.plan(system.settings(request.settings))


def _check_owner(receipt: Receipt, user: str) -> None:
    owner = receipt.values.get("settings", {}).get("user")
    if owner and owner != user:
        raise ProvisionError(f"system is managed for {owner}")
