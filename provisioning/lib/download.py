import hashlib
import json
import re
import tarfile
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

from state import ProvisionError, run

GOOGLE = "https://dl.google.com"
CHROME_REPO = f"{GOOGLE}/linux/chrome/deb"
GOOGLE_KEY = "EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796"


@dataclass(frozen=True)
class Download:
    url: str
    sha256: str


def fetch(download: Download, destination: Path) -> None:
    if not re.fullmatch(r"[a-f0-9]{64}", download.sha256):
        raise ProvisionError(f"invalid SHA-256 for {download.url}")
    _fetch(download.url, destination)
    with destination.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    if digest != download.sha256:
        raise ProvisionError(f"SHA-256 mismatch for {download.url}")


def extract(archive: Path, target: Path) -> None:
    target.mkdir()
    with tarfile.open(archive) as payload:
        payload.extractall(target, filter="data")


def rustup(url: str, staging: Path) -> Download:
    checksum = staging / "rustup.sha256"
    _fetch(f"{url}.sha256", checksum)
    return Download(url, checksum.read_text().split()[0])


def vscode(commit: str, staging: Path) -> Download:
    metadata = staging / "code.json"
    _fetch(
        "https://update.code.visualstudio.com/api/update/linux-x64/stable/"
        "0000000000000000000000000000000000000000",
        metadata,
    )
    info = json.loads(metadata.read_text())
    if info["version"] != commit:
        raise ProvisionError(
            "Microsoft's checksum feed no longer describes the pinned VS Code release"
        )
    return Download(info["url"], info["sha256hash"])


def chrome(version: str, staging: Path) -> Download:
    keys = staging / "google.asc"
    ring = staging / "google.gpg"
    signature = staging / "InRelease"
    listing = staging / "Packages.gz"
    gnupg = staging / "gnupg"
    gnupg.mkdir(mode=0o700)
    command = ["gpg", "--batch", "--homedir", str(gnupg)]
    _fetch(f"{GOOGLE}/linux/linux_signing_key.pub", keys)
    run([*command, "--import", keys], capture=True)
    run([*command, "--output", ring, "--export", GOOGLE_KEY])
    if not ring.stat().st_size:
        raise ProvisionError("Google package signing key missing")
    _fetch(f"{CHROME_REPO}/dists/stable/InRelease", signature)
    release = run(["gpgv", "--keyring", ring, "--output", "-", signature], capture=True)
    index_path = "main/binary-amd64/Packages.gz"
    hashes = release.split("SHA256:\n", 1)[1]
    for line in hashes.splitlines():
        if not line.startswith(" "):
            break
        digest, _, name = line.split()
        if name == index_path:
            fetch(Download(f"{CHROME_REPO}/dists/stable/{name}", digest), listing)
            return _chrome_package(version, listing)
    raise ProvisionError("Google's signed index does not list the amd64 package index")


def _chrome_package(version: str, listing: Path) -> Download:
    packages = run(["gzip", "-dc", listing], capture=True)
    for paragraph in packages.split("\n\n"):
        fields = dict(
            line.split(": ", 1) for line in paragraph.splitlines() if ": " in line
        )
        if fields.get("Package") != "google-chrome-stable":
            continue
        if fields.get("Version", "").split("-", 1)[0] == version:
            return Download(f"{CHROME_REPO}/{fields['Filename']}", fields["SHA256"])
    raise ProvisionError(f"Google's signed index does not contain Chrome {version}")


def _fetch(url: str, file: Path) -> None:
    if urlparse(url).scheme != "https":
        raise ProvisionError(f"expected HTTPS for {url}")
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
            "--output",
            file,
            url,
        ]
    )
