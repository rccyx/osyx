PREFIX="/usr/local"
DEP_PREFIX="$PREFIX/lib/hypr-builder"
APT_RELEASE="trixie"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-builder"
SRC_DIR="$CACHE_DIR/src"
BUILD_DIR="$CACHE_DIR/build"
STAGE_DIR="$CACHE_DIR/stage"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-builder"
MANIFEST_DIR="$STATE_DIR/manifests"

REPOS=(
  "hyprutils|https://github.com/hyprwm/hyprutils.git|83da5ee98d806cef2d05a1072b8d8b832bf52891|cmake||pc:hyprutils"
  "hyprwayland-scanner|https://github.com/hyprwm/hyprwayland-scanner.git|b8632713a6beaf28b56f2a7b0ab2fb7088dbb404|cmake||path:/usr/local/bin/hyprwayland-scanner"
  "hyprland-protocols|https://github.com/hyprwm/hyprland-protocols.git|1cb6db5fd6bb8aee419f4457402fa18293ace917|cmake||pc:hyprland-protocols"
  "hyprlang|https://github.com/hyprwm/hyprlang.git|090117506ddc3d7f26e650ff344d378c2ec329cc|cmake||pc:hyprlang"
  "hyprgraphics|https://github.com/hyprwm/hyprgraphics.git|c6e7b9f673f4360bc813d3dc75028f75ee88d3f8|cmake||pc:hyprgraphics"
  "hyprwire|https://github.com/hyprwm/hyprwire.git|7d935bb54674aa0fbd327d2a6888bd0630079ed0|cmake||pc:hyprwire"
  "aquamarine|https://github.com/hyprwm/aquamarine.git|fc39af0ccec9171aec8185eaea8afb71a46eff90|cmake||pc:aquamarine"
  "hyprcursor|https://github.com/hyprwm/hyprcursor.git|39435900785d0c560c6ae8777d29f28617d031ef|cmake||pc:hyprcursor"
  "hyprtoolkit|https://github.com/hyprwm/hyprtoolkit.git|08aed5d8ebdbbaff892552a25e5f8688730da111|cmake||pc:hyprtoolkit"
  "Hyprland|https://github.com/hyprwm/Hyprland.git|ab95888cd1d6961471f9e8df05f5e4a40dbb759d|cmake|-DNO_UWSM=ON -DUSE_TRACY=OFF -DWITH_TESTS=OFF|path:/usr/local/bin/Hyprland"
  "hypridle|https://github.com/hyprwm/hypridle.git|e5c01af0842bd66617f7004568df9406111d6e80|cmake||path:/usr/local/bin/hypridle"
  "hyprlock|https://github.com/hyprwm/hyprlock.git|b222d9b1f87e980cac379371df57913a53b99d7f|cmake||path:/usr/local/bin/hyprlock"
  "xdg-desktop-portal-hyprland|https://github.com/hyprwm/xdg-desktop-portal-hyprland.git|cc8e5ef8fb2acef3db488b9a33b0c48c2a4ee204|cmake|-DCMAKE_INSTALL_LIBEXECDIR=libexec|path:/usr/local/libexec/xdg-desktop-portal-hyprland"
  "hyprpaper|https://github.com/hyprwm/hyprpaper.git|c011bd20886ea3301474e77d7fa4d22ab013ece0|cmake||path:/usr/local/bin/hyprpaper"
  "hyprsunset|https://github.com/hyprwm/hyprsunset.git|25f704346ec22e7623b0873ef8c4573b57ca1512|cmake||path:/usr/local/bin/hyprsunset"
  "hyprshutdown|https://github.com/hyprwm/hyprshutdown.git|db1f38b03b173984ae9ed3abeb9750583c9bbd91|cmake||path:/usr/local/bin/hyprshutdown"
)

SYSTEM_DEPS=(
  "libxkbcommon|https://github.com/xkbcommon/libxkbcommon.git|xkbcommon-1.11.0|xkbcommon|1.11.0|meson|-Denable-docs=false -Denable-x11=false -Denable-wayland=false -Dxkb-config-root=/usr/share/X11/xkb -Dx-locale-root=/usr/share/X11/locale|pc:xkbcommon"
  "wayland-scanner|https://gitlab.freedesktop.org/wayland/wayland.git|1.25.0|wayland-scanner|1.25.0|meson|-Dlibraries=false -Dscanner=true -Ddocumentation=false -Dtests=false -Ddtd_validation=false|pc:wayland-scanner"
  "wayland-protocols|https://gitlab.freedesktop.org/wayland/wayland-protocols.git|1.49|wayland-protocols|1.49|meson|-Dtests=false|pc:wayland-protocols"
  "libinput|https://gitlab.freedesktop.org/libinput/libinput.git|1.29.0|libinput|1.29.0|meson|-Ddocumentation=false -Dtests=false -Ddebug-gui=false -Dlibwacom=false|pc:libinput"
  "lua55|https://www.lua.org/ftp/lua-5.5.0.tar.gz|5.5.0|lua5.5|5.5.0|lua-release|57ccc32bbbd005cab75bcc52444052535af691789dba2b9016d5c50640d68b3d|lua55"
)

SYSTEM_DEP_APT_DEPS=(
  "libxkbcommon|build-essential meson ninja-build pkg-config bison flex gawk python3 xkb-data"
  "wayland-scanner|build-essential meson ninja-build pkg-config libexpat1-dev"
  "wayland-protocols|build-essential meson ninja-build pkg-config"
  "libinput|build-essential meson ninja-build pkg-config libevdev-dev libmtdev-dev libudev-dev"
  "lua55|build-essential ca-certificates curl xz-utils libreadline-dev"
)

COMPONENT_APT_DEPS=(
  "hyprutils|build-essential cmake ninja-build pkg-config libpixman-1-dev"
  "hyprwayland-scanner|build-essential cmake ninja-build pkg-config libpugixml-dev"
  "hyprland-protocols|build-essential cmake ninja-build pkg-config"
  "hyprlang|build-essential cmake ninja-build pkg-config"
  "hyprgraphics|build-essential cmake ninja-build pkg-config zlib1g-dev libzstd-dev libegl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev libdrm-dev libpixman-1-dev libcairo2-dev libpango1.0-dev libharfbuzz-dev libfontconfig1-dev libjpeg-dev libwebp-dev libmagic-dev libpng-dev librsvg2-dev libjxl-dev libheif-dev"
  "hyprwire|build-essential cmake ninja-build pkg-config libffi-dev"
  "aquamarine|build-essential cmake ninja-build pkg-config libegl1-mesa-dev libgles2-mesa-dev libseat-dev seatd libinput-dev libwayland-dev wayland-protocols libpixman-1-dev libdrm-dev libgbm-dev libudev-dev libdisplay-info-dev hwdata"
  "hyprcursor|build-essential cmake ninja-build pkg-config libzip-dev libcairo2-dev librsvg2-dev libtomlplusplus-dev xcur2png"
  "hyprtoolkit|build-essential cmake ninja-build pkg-config libegl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev libwayland-dev wayland-protocols libpixman-1-dev libdrm-dev libgbm-dev libxkbcommon-dev libpango1.0-dev libcairo2-dev libiniparser-dev"
  "Hyprland|build-essential cmake ninja-build pkg-config git file scdoc python3 python3-jinja2 libegl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev libvulkan-dev spirv-tools glslang-tools glslang-dev libxkbcommon-dev libxkbcommon-x11-dev libxkbregistry-dev uuid-dev libwayland-dev wayland-protocols libcairo2-dev libpango1.0-dev libpixman-1-dev libxcursor-dev libdrm-dev libinput-dev libei-dev libeis-dev libgbm-dev libglib2.0-dev libre2-dev libmuparser-dev liblcms2-dev libliftoff-dev libsdbus-c++-dev libxcb1-dev libxcb-composite0-dev libxcb-cursor-dev libxcb-errors-dev libxcb-ewmh-dev libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-randr0-dev libxcb-render0-dev libxcb-render-util0-dev libxcb-res0-dev libxcb-shape0-dev libxcb-util-dev libxcb-xfixes0-dev libxcb-xinerama0-dev libxcb-xinput-dev libxcb-xkb-dev xwayland wl-clipboard"
  "hypridle|build-essential cmake ninja-build pkg-config libwayland-dev wayland-protocols libsdbus-c++-dev"
  "hyprlock|build-essential cmake ninja-build pkg-config libegl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev libwayland-dev wayland-protocols libxkbcommon-dev libcairo2-dev libpango1.0-dev libdrm-dev libgbm-dev libsdbus-c++-dev libpam0g-dev"
  "xdg-desktop-portal-hyprland|build-essential cmake ninja-build pkg-config libwayland-dev wayland-protocols libpipewire-0.3-dev libspa-0.2-dev libdrm-dev uuid-dev libgbm-dev libsdbus-c++-dev qt6-base-dev qt6-wayland dbus-user-session xdg-desktop-portal xdg-desktop-portal-gtk slurp"
  "hyprpaper|build-essential cmake ninja-build pkg-config libwayland-dev wayland-protocols libpixman-1-dev libdrm-dev"
  "hyprsunset|build-essential cmake ninja-build pkg-config libwayland-dev wayland-protocols libsystemd-dev"
  "hyprshutdown|build-essential cmake ninja-build pkg-config libpixman-1-dev libdrm-dev"
)
