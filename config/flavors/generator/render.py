from __future__ import annotations

from pathlib import Path
from typing import Any

try:
    from jinja2 import Environment, FileSystemLoader, StrictUndefined, TemplateError
except ModuleNotFoundError as exc:  # pragma: no cover - import-time dependency guard
    raise RuntimeError("Jinja2 not found. Install it with: sudo apt install python3-jinja2") from exc

try:
    import tomllib
except ModuleNotFoundError as exc:  # pragma: no cover - import-time dependency guard
    raise RuntimeError("tomllib not found. This script requires Python 3.11+") from exc

from .config import OUTPUTS, PALETTES_DIR, ROOT_DIR, TEMPLATES_DIR, THEME_NAMES_FILE
from .palette import build_mapping, load_palette


class ThemeError(Exception):
    pass


def generate_theme(theme_name: str) -> None:
    theme_file = PALETTES_DIR / f"{theme_name}.toml"

    if not theme_file.exists():
        raise ThemeError(f"theme file not found: {theme_file}")

    palette = load_palette(theme_file)
    mapping = build_mapping(palette)
    env = _jinja_env(TEMPLATES_DIR)

    print(f"Generating theme: {theme_name}")

    for template_name, rel_out_path in OUTPUTS.items():
        render_template(env, template_name, rel_out_path, mapping)

    write_theme_names(theme_name, palette)


def render_template(
    env: Environment,
    template_name: str,
    rel_out_path: str,
    mapping: dict[str, str],
) -> None:
    template_path = TEMPLATES_DIR / template_name

    if not template_path.exists():
        print(f"Warning: template not found: {template_path}")
        return

    try:
        rendered = env.get_template(template_name).render(**mapping)
    except TemplateError as exc:
        raise ThemeError(f"failed rendering {template_name}: {exc}") from exc

    out_path = ROOT_DIR / rel_out_path
    write_output(out_path, rendered)
    print(f"  -> Created {rel_out_path}")


def write_theme_names(theme_name: str, palette: dict[str, Any]) -> None:
    current = _read_theme_names()
    apps = current.get("apps", {})

    if not isinstance(apps, dict):
        apps = {}

    names = palette.get("theme_names", {})

    if isinstance(names, dict):
        for app, value in names.items():
            name = str(value).strip()
            if name:
                apps[str(app).strip()] = name

    content = _theme_names_toml(theme_name, apps)
    write_output(THEME_NAMES_FILE, content)
    print(f"  -> Created flavors/theme-names.toml")


def write_output(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    if path.is_symlink():
        path.unlink()

    path.write_text(content, encoding="utf-8")


def _read_theme_names() -> dict[str, Any]:
    if not THEME_NAMES_FILE.exists():
        return {}

    try:
        with THEME_NAMES_FILE.open("rb") as theme_file:
            return tomllib.load(theme_file)
    except tomllib.TOMLDecodeError:
        return {}


def _theme_names_toml(theme_name: str, apps: dict[str, Any]) -> str:
    lines = [
        f"flavor = {_toml_string(theme_name)}",
        "",
        "[apps]",
    ]

    for app in sorted(apps):
        value = str(apps[app]).strip()
        if value:
            lines.append(f"{_toml_string(app)} = {_toml_string(value)}")

    lines.append("")
    return "\n".join(lines)


def _toml_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def _jinja_env(base_dir: Path) -> Environment:
    return Environment(
        loader=FileSystemLoader(base_dir),
        undefined=StrictUndefined,
        autoescape=False,
        keep_trailing_newline=True,
        trim_blocks=False,
        lstrip_blocks=False,
    )