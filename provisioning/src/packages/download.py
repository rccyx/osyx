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
        with tarfile.open(archive) as payload:
            payload.extractall(target, filter="data")
    except (OSError, tarfile.TarError) as exc:
        raise ProvisionError(ErrorTag.ARTIFACT, f"cannot safely extract {archive}") from exc


def get(url: str, file: Path) -> None:
    if urlparse(url).scheme != "https":
        raise ProvisionError(ErrorTag.ARTIFACT, f"expected HTTPS for {url}")
    run(
        [
            "curl",
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
