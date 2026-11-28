import shutil
import stat
import zipfile
import hashlib
import re
import tarfile
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

from core.state import ErrorTag, ProvisionError, run


@dataclass(frozen=True)
class Download:
    url: str
    sha256: str


def fetch(download: Download, destination: Path) -> None:
    if not re.fullmatch(r"[a-f0-9]{64}", download.sha256):
        raise ProvisionError(ErrorTag.MANIFEST, f"invalid SHA-256 for {download.url}")
    get(download.url, destination)
    with destination.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    if digest != download.sha256:
        destination.unlink(missing_ok=True)
        raise ProvisionError(ErrorTag.ARTIFACT, f"SHA-256 mismatch for {download.url}")


def extract(archive: Path, target: Path) -> None:
    target.mkdir()
    try:
        if zipfile.is_zipfile(archive):
            _extract_zip(archive, target)
        else:
            with tarfile.open(archive) as payload:
                payload.extractall(target, filter="data")
    except (OSError, tarfile.TarError, zipfile.BadZipFile) as exc:
        raise ProvisionError(
            ErrorTag.ARTIFACT, f"cannot safely extract {archive}"
        ) from exc


def _extract_zip(archive: Path, target: Path) -> None:
    with zipfile.ZipFile(archive) as payload:
        for member in payload.infolist():
            name = Path(member.filename)
            mode = member.external_attr >> 16
            kind = stat.S_IFMT(mode)
            expected = stat.S_IFDIR if member.is_dir() else stat.S_IFREG

            if (
                name.is_absolute()
                or not name.parts
                or ".." in name.parts
                or "\\" in member.filename
                or kind not in (0, expected)
            ):
                raise ProvisionError(
                    ErrorTag.ARTIFACT, f"unsafe ZIP entry: {member.filename}"
                )

            path = target / name
            if member.is_dir():
                path.mkdir(parents=True, exist_ok=True)
                continue

            path.parent.mkdir(parents=True, exist_ok=True)
            with payload.open(member) as source, path.open("xb") as output:
                shutil.copyfileobj(source, output)

            path.chmod(0o755 if mode & 0o111 else 0o644)

def get(url: str, file: Path) -> None:
    if urlparse(url).scheme != "https":
        raise ProvisionError(ErrorTag.ARTIFACT, f"expected HTTPS for {url}")
    run(
        [
            "curl",
            "--disable",
            "--fail",
            "--silent",
            "--show-error",
            "--location",
            "--proto",
            "=https",
            "--retry",
            "2",
            "--connect-timeout",
            "15",
            "--max-time",
            "600",
            "--output",
            file,
            url,
        ]
    )