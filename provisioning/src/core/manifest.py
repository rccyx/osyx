import re
import tomllib
from dataclasses import dataclass
from pathlib import Path

from core.state import ErrorTag, ProvisionError


@dataclass(frozen=True)
class Entry:
    name: str
    version: str
    reason: str


def entries(path: Path) -> dict[str, Entry]:
    result: dict[str, Entry] = {}
    for number, line in enumerate(path.read_text().splitlines(), 1):
        body, _, reason = line.partition("#")
        body = body.strip()
        if not body:
            continue
        match = re.fullmatch(r"([a-z0-9][a-z0-9+.-]*)(?:(?:==|=|@git:)([A-Za-z0-9.+:~_-]+))?", body)
        if not match or not reason.strip():
            raise ProvisionError(
                ErrorTag.MANIFEST, f"{path}:{number}: expected package and comment"
            )
        name, version = match.groups()
        if name in result:
            raise ProvisionError(ErrorTag.MANIFEST, f"{path}:{number}: duplicate {name}")
        result[name] = Entry(name, version or "", reason.strip())
    return result


def table(path: Path) -> dict[str, object]:
    try:
        return tomllib.loads(path.read_text())
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise ProvisionError(ErrorTag.MANIFEST, f"invalid manifest: {path}") from exc


def mapping(value: object) -> dict[str, object]:
    if not isinstance(value, dict):
        raise ProvisionError(ErrorTag.MANIFEST, "expected a table")
    result: dict[str, object] = {}
    for key, item in value.items():
        if not isinstance(key, str):
            raise ProvisionError(ErrorTag.MANIFEST, "expected a string key")
        result[key] = item
    return result


def string(value: object) -> str:
    if not isinstance(value, str) or not value:
        raise ProvisionError(ErrorTag.MANIFEST, "expected a nonempty string")
    return value


def strings(value: object) -> list[str]:
    if not isinstance(value, list):
        raise ProvisionError(ErrorTag.MANIFEST, "expected a string array")
    return [string(item) for item in value]


def string_map(value: object) -> dict[str, str]:
    return {key: string(item) for key, item in mapping(value).items()}
