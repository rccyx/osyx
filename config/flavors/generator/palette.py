from __future__ import annotations

from pathlib import Path
from typing import Any

from .colors import color_variants

try:
    import tomllib
except ModuleNotFoundError as exc:  # pragma: no cover - import-time dependency guard
    raise RuntimeError("tomllib not found. This script requires Python 3.11+") from exc


def load_palette(path: Path) -> dict[str, Any]:
    with path.open("rb") as palette_file:
        return tomllib.load(palette_file)


def build_mapping(data: dict[str, Any]) -> dict[str, str]:
    mapping: dict[str, str] = {}

    for section, value in data.items():
        if isinstance(value, dict):
            mapping.update(_section_mapping(section, value))
        else:
            mapping[section] = str(value)

    return mapping


def _section_mapping(section: str, values: dict[str, Any]) -> dict[str, str]:
    mapping: dict[str, str] = {}

    for key, raw_value in values.items():
        raw = str(raw_value).strip().lstrip("#")
        name = f"{section}_{key}"
        mapping[name] = raw

        if raw and raw.lower() != "none":
            mapping.update(_safe_color_variants(name, raw))

    return mapping


def _safe_color_variants(name: str, raw: str) -> dict[str, str]:
    try:
        variants = color_variants(raw)
    except ValueError:
        return {}

    return {f"{name}_{variant}": value for variant, value in variants.items()}
