from collections.abc import Iterator
from pathlib import Path

from core.files import Files, read_image
from core.state import ErrorTag, Image, ProvisionError, Receipt, run


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
            if replace or self._selected(name, current):
                print(f"{'replace' if current else 'copy'} {path}")
            else:
                print(f"preserve existing {path}")

    def apply(self, *, replace: bool) -> None:
        self.plan(replace=replace)
        for name, image in self._source():
            current = read_image(self.files.path(name))
            if replace or self._selected(name, current):
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
            raise ProvisionError(
                ErrorTag.VERIFY, f"home files missing or changed: {', '.join(missing)}"
            )
        print("home files checked")

    def _selected(self, name: str, current: Image | None) -> bool:
        return current is None or name in self.files.changes()

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
            raise ProvisionError(ErrorTag.VERIFY, "checkout has no tracked home files")
        source = Files(self.repository / "home", self.receipt)
        for entry in tracked.rstrip("\0").split("\0"):
            relative = Path(entry).relative_to("home")
            image = read_image(source.path(str(relative)))
            if image is None:
                raise ProvisionError(
                    ErrorTag.VERIFY, f"tracked home file missing from checkout: {entry}"
                )
            yield str(relative), image
