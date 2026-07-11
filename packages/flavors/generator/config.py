from __future__ import annotations

from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1]
ROOT_DIR = SCRIPT_DIR.parent
FLAVORS_DIR = ROOT_DIR / "flavors"
TEMPLATES_DIR = FLAVORS_DIR / "templates"
PALETTES_DIR = FLAVORS_DIR / "palettes"
THEME_NAMES_FILE = FLAVORS_DIR / "theme-names.toml"

OUTPUTS = {
    "mako.conf.j2": ".config/mako/config",
    "starship.toml.j2": ".config/starship.toml",
    "dircolors.j2": ".dircolors",
    "hypr.conf.j2": ".config/hypr/theme.conf",
    "tmux.conf.j2": ".tmux.conf",
    "wofi.css.j2": ".config/wofi/style.css",
    "gitconfig.j2": ".gitconfig.d/theme",
}