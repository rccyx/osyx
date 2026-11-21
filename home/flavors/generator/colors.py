from __future__ import annotations


def hex_to_rgb(hex_str: str) -> str:
    value = hex_str.lstrip("#")
    return f"{int(value[0:2], 16)}, {int(value[2:4], 16)}, {int(value[4:6], 16)}"


def hex_to_ansi(hex_str: str) -> str:
    value = hex_str.lstrip("#")
    return f"{int(value[0:2], 16)};{int(value[2:4], 16)};{int(value[4:6], 16)}"


def color_variants(hex_str: str) -> dict[str, str]:
    return {
        "rgb": hex_to_rgb(hex_str),
        "ansi": hex_to_ansi(hex_str),
    }
