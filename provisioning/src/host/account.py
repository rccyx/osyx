import os
import pwd
import re
from pathlib import Path

from core.state import ErrorTag, ProvisionError


def account(user: str) -> pwd.struct_passwd:
    name = user or os.environ.get("SUDO_USER") or pwd.getpwuid(os.getuid()).pw_name
    if not re.fullmatch(r"[a-z_][a-z0-9_-]*", name):
        raise ProvisionError(ErrorTag.HOST, f"invalid workstation user: {name}")
    try:
        value = pwd.getpwnam(name)
    except KeyError as exc:
        raise ProvisionError(ErrorTag.HOST, f"create the workstation user first: {name}") from exc
    if value.pw_uid == 0 or not Path(value.pw_dir).is_dir():
        raise ProvisionError(
            ErrorTag.HOST, "specify an existing non-root workstation account with --user"
        )
    if os.getuid() not in (0, value.pw_uid):
        raise ProvisionError(ErrorTag.HOST, "run as root or the selected workstation user")
    return value
