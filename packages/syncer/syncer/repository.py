from __future__ import annotations

from datetime import datetime
from pathlib import Path

from syncer.execution import Command, run
from syncer.terminal import note, ok

__all__ = ["git_sync"]


def git_sync(pkg_dir: Path, push: bool = False) -> None:
    if not (pkg_dir / ".git").is_dir():
        return
    note(f"Git: {('pushing' if push else 'pulling')} in {pkg_dir}")
    if push:
        run(Command(("git", "add", "-A"), cwd=pkg_dir))
        r = run(Command(("git", "status", "--porcelain"), cwd=pkg_dir))
        if r:
            run(
                Command(
                    ("git", "commit", "-m", f"sync: {datetime.now().isoformat()}"),
                    cwd=pkg_dir,
                )
            )
            run(Command(("git", "push"), cwd=pkg_dir))
            ok("Changes pushed to packages repo")
        else:
            note("No changes to commit")
    else:
        run(Command(("git", "pull", "--ff-only"), cwd=pkg_dir))
        ok("Pulled latest packages snapshot")
