from __future__ import annotations

from rich.console import Console
from rich.markup import escape

__all__ = ["OUT", "ERR", "ok", "note", "warn", "fail"]
OUT = Console()
ERR = Console(stderr=True)


def ok(msg: str) -> None:
    OUT.print(f"  [bold green]✓[/] {escape(msg)}")


def note(msg: str) -> None:
    OUT.print(f"  [dim cyan]·[/] {escape(msg)}")


def warn(msg: str) -> None:
    ERR.print(f"  [bold yellow]![/] {escape(msg)}")


def fail(msg: str) -> None:
    ERR.print(f"  [bold red]✗[/] {escape(msg)}")
