# Fonts

| Font               | Role                                                             |
| ------------------ | ---------------------------------------------------------------- |
| Inter              | UI font for GTK apps, notifications, launcher, browser UI        |
| Iosevka Fixed SS18 | Primary monospace for terminal, code, Tmux, Starship, and Neovim |
| Meslo Nerd Font    | Fallback monospace for Nerd Font glyphs                          |

## Installation

If you look on the right side of this repository on GitHub, you'll see that I've uploaded the fonts as a release package you can install:

```sh
provisioning/main apply fonts --user "$USER" --yes
```

This downloads the pinned release archive, extracts it into `~/.local/share/fonts/osyx`, and refreshes the Fontconfig cache. Keeps a state file at `.state/fonts.version` and exits cleanly if the installed version already matches.

Bundle layout:

```text
~/.local/share/fonts/osyx/
├── Inter/
├── iosevka-ss18/
└── meslo/
```

Requires: `curl`, `tar`, `fc-cache`

> [!TIP]
> If you don't like the fonts, simply `rm -rf ~/.local/share/fonts/osyx`, and use your old `~/.config/fontconfig/fonts.conf` file instead.

## Fontconfig

`config/.config/fontconfig/fonts.conf` (maps to `~/.config/fontconfig/fonts.conf`) is as important as the font files. It controls rendering behavior (antialias, hinting, hintstyle, RGB subpixel order, LCD filtering) and the family routing that makes Inter look right.

Since Inter has this weird auto adjusting property.

Browsers can pick weird optical size variants and render Inter too wide or too loose. So everything is explicitly routed: text below 18pt gets `Inter 18pt`, text 18pt and above gets `Inter 28pt`. Light weights are also forced back to regular so text stays readable on 1080p panels.

```xml
<match target="pattern">
  <test name="weight" compare="less_eq"><const>light</const></test>
  <edit name="weight" mode="assign"><const>regular</const></edit>
</match>

<match target="pattern">
  <test name="family"><string>sans-serif</string></test>
  <test name="size" compare="less"><double>18</double></test>
  <edit name="family" mode="prepend"><string>Inter 18pt</string></edit>
</match>

<match target="pattern">
  <test name="family"><string>sans-serif</string></test>
  <test name="size" compare="more_eq"><double>18</double></test>
  <edit name="family" mode="prepend"><string>Inter 28pt</string></edit>
</match>

<alias>
  <family>sans-serif</family>
  <prefer>
    <family>Inter 18pt</family>
    <family>Inter 28pt</family>
  </prefer>
</alias>

<alias>
  <family>serif</family>
  <prefer>
    <family>Inter 18pt</family>
    <family>Inter 28pt</family>
  </prefer>
</alias>

<alias>
  <family>monospace</family>
  <prefer>
    <family>Iosevka Fixed SS18</family>
    <family>Meslo LG S</family>
    <family>MesloLGS NF</family>
  </prefer>
</alias>
```

## Verify

```sh
fc-match "Inter 18pt"
fc-match "Inter 28pt"
fc-match "Iosevka Fixed SS18"
fc-match "MesloLGS NF"
find ~/.local/share/fonts/osyx -maxdepth 2 -type d | sort
```
