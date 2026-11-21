from __future__ import annotations

def main(args: list[str]) -> int:
    if not args:
        print("Usage: python3 generate.py <theme_name> [theme_name ...]")
        print("Example: python3 generate.py malachite")
        return 1

    try:
        from .render import ThemeError, generate_theme
    except RuntimeError as error:
        print(f"Error: {error}")
        return 1

    for theme in args:
        try:
            generate_theme(theme)
        except ThemeError as error:
            print(f"Error: {error}")
            return 1

    return 0
