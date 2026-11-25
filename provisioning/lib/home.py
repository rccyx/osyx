from collections.abc import Iterator
from pathlib import Path

from files import Files, read_image
from state import Image, ProvisionError, Receipt, run

EXCLUDED = {
    ".tfa",
    ".vpn",
    ".exported",
    "Downloads",
    "Music",
    "Pictures",
    "packages",
    "trash",
    "README.md",
    "_install_",
}


class Home:
    def __init__(self, repository: Path, directory: Path):
        self.repository = repository
        self.receipt = Receipt(directory / ".local/state/osyx/provisioning/home.json")
        self.files = Files(directory, self.receipt)

    def plan(self, *, replace: bool) -> None:
        for name, image in self._source():
            path = self.files.path(name)
            current = read_image(path)
            if current == image:
                continue
            if self._selected(name, current, replace=replace):
                print(f"{'replace' if current else 'copy'} {path}")
            else:
                print(f"preserve existing {path}")

    def apply(self, *, replace: bool) -> None:
        self.plan(replace=replace)
        for name, image in self._source():
            current = read_image(self.files.path(name))
            if self._selected(name, current, replace=replace):
                self.files.install(name, image)

    def doctor(self) -> None:
        missing = []
        for name, image in self._source():
            path = self.files.path(name)
            current = read_image(path)
            if current == image:
                continue
            if current is None or name in self.files.changes():
                missing.append(str(path))
            else:
                print(f"preserved existing {path}")
        if missing:
            raise ProvisionError(f"home files missing or changed: {', '.join(missing)}")
        print("home files checked")

    def _selected(self, name: str, current: Image | None, *, replace: bool) -> bool:
        return current is None or name in self.files.changes() or replace

    def _source(self) -> Iterator[tuple[str, Image]]:
        tracked = run(
            [
                "git",
                "-c",
                f"safe.directory={self.repository}",
                "-C",
                self.repository,
                "ls-files",
                "-z",
                "--",
                "home/",
            ],
            capture=True,
        )
        if not tracked:
            raise ProvisionError("checkout has no tracked home files")
        source = Files(self.repository / "home", self.receipt)
        for entry in tracked.rstrip("\0").split("\0"):
            relative = Path(entry).relative_to("home")
            if relative.parts[0] in EXCLUDED:
                continue
            image = read_image(source.path(str(relative)))
            if image is None:
                raise ProvisionError(
                    f"tracked home file missing from checkout: {entry}"
                )
            yield str(relative), image
