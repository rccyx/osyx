# Dependencies

Debian is the automated and tested path.

Non-Debian systems are manual dependency paths.

Install the Qt/QML runtime yourself, then run:

```sh
./package/install --no-install-deps
```

Arch:

```sh
sudo pacman -S --needed qt6-declarative qt6-svg
```

Fedora:

```sh
sudo dnf install qt6-qtdeclarative qt6-qtsvg
```

openSUSE Tumbleweed:

```sh
sudo zypper install qtdeclarative-imports-provides-qt6 libQt6Svg6
```

Ubuntu:

```sh
sudo apt-get install -y --no-install-recommends \
  qml-qt6 \
  qml6-module-qtquick \
  qml6-module-qtquick-window \
  qml6-module-qtquick-layouts \
  libqt6svg6
```

# Font

The QML uses Plus Jakarta Sans.

You can also get it from:

```text
https://github.com/rccyx/thyx
```

# Config

`powyx.toml` contains action commands and the confirmation color.

```toml
[actions]
lock = "hyprlock"
suspend = "systemctl suspend"
reboot = "systemctl reboot"
shutdown = "systemctl poweroff"

[theme]
confirm = "#E7BE5B"
```

`theme.confirm` controls the second click confirmation state.

Use this for osyx flavor colors.

Examples:

```toml
[theme]
confirm = "#8BD5CA"
```

```toml
[theme]
confirm = "#F5B8C4"
```
