import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = ROOT.parent
HOST_STATE = Path("/var/lib/osyx/provisioning")
Action = Literal["apply", "destroy", "plan", "doctor"]


@dataclass(frozen=True)
class Request:
    action: Action
    target: str
    user: str
    locale: str
    timezone: str
    yes: bool
    replace_home: bool
    firmware_intel: bool
    destroying: bool
    worker: bool


def parse() -> Request:
    parser = argparse.ArgumentParser(description="OSYX workstation provisioner")
    parser.add_argument("action", choices=("plan", "apply", "destroy", "doctor"))
    parser.add_argument("target", nargs="?", default="workstation")
    parser.add_argument("--user", default="")
    parser.add_argument("--locale", default="")
    parser.add_argument("--timezone", default="")
    parser.add_argument("--yes", action="store_true", help="accept without prompts")
    parser.add_argument(
        "--replace-home", action="store_true", help="back up and replace conflicting home files"
    )
    parser.add_argument(
        "--firmware-intel", action="store_true", help="opt in to detected Intel firmware"
    )
    parser.add_argument("--destroy", action="store_true", help="show a destruction plan")
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.destroy and args.action != "plan":
        parser.error("--destroy is only valid with plan")
    if args.firmware_intel and args.target != "workstation":
        parser.error("--firmware-intel is only valid with workstation")
    return Request(
        args.action,
        args.target,
        args.user,
        args.locale,
        args.timezone,
        args.yes,
        args.replace_home,
        args.firmware_intel,
        args.destroy,
        args.worker,
    )
