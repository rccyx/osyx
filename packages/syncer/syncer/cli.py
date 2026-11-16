from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

from syncer.commands import cmd_backup, cmd_diff, cmd_restore, cmd_status
from syncer.execution import describe_failure
from syncer.managers import RestoreOptions
from syncer.terminal import fail

__all__ = ["DEFAULT_PKG_DIR", "main"]
DEFAULT_PKG_DIR = Path(os.environ.get("PACKAGES_DIR", str(Path.home() / "packages")))


def main() -> None:
    p = argparse.ArgumentParser(prog="syncer")
    p.add_argument("--pkg-dir", type=Path, default=DEFAULT_PKG_DIR)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("backup")
    r = sub.add_parser("restore")
    r.add_argument("--dry-run", action="store_true")
    r.add_argument("--strict", action="store_true")
    r.add_argument("--no-apt-update", action="store_true")
    sub.add_parser("diff")
    sub.add_parser("status")
    args = p.parse_args()
    try:
        if args.cmd == "backup":
            sys.exit(cmd_backup(args.pkg_dir))
        elif args.cmd == "restore":
            sys.exit(
                cmd_restore(
                    args.pkg_dir,
                    RestoreOptions(
                        dry=args.dry_run,
                        strict=args.strict,
                        no_apt_update=args.no_apt_update,
                    ),
                )
            )
        elif args.cmd == "diff":
            sys.exit(cmd_diff(args.pkg_dir))
        elif args.cmd == "status":
            sys.exit(cmd_status(args.pkg_dir))
    except subprocess.CalledProcessError as exc:
        fail(describe_failure(exc))
        sys.exit(1)
    except (OSError, ValueError) as exc:
        fail(str(exc))
        sys.exit(1)
