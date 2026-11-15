# Powyx

For Debian, just run `./package/install` it will auto install everything.

For other distros, install the Qt/QML runtime yourself, and then run the installer without deps checks:

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

## Font

This uses Plus Jakarta Sans.

So have a look at [`fonts.sh`](/provisioning/setup/display/fonts.sh), or you can just get the font by installing `thyx` anyway:

```text
https://github.com/rccyx/thyx
```

## Config

This is so simple. `~/.config/powyx/powyx.toml` contains action commands and the confirmation color.

```toml
[actions]
lock = "hyprlock"
suspend = "systemctl suspend"
reboot = "systemctl reboot"
shutdown = "systemctl poweroff"

[theme]
confirm = "#E7BE5B"
```

`theme.confirm` controls the second click confirmation state color.

If you're using the [flavors](/packages/flavors/) package already, it auto switches `powyx` themes when you switch desktop themes.