need_cmd()
{
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

as_root()
{
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    need_cmd sudo
    sudo "$@"
  fi
}

dpkg_installed()
{
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

detect_codename()
{
  [ -r /etc/os-release ] || return 1
  . /etc/os-release
  printf '%s' "${VERSION_CODENAME:-}"
}

jobs()
{
  local count="${HYPR_BUILDER_JOBS:-$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf 1)}"
  [[ "$count" =~ ^[1-9][0-9]*$ ]] || die "HYPR_BUILDER_JOBS must be a positive integer"
  printf '%s' "$count"
}

setup_build_environment()
{
  local multiarch
  multiarch="$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || true)"

  case ":$PATH:" in
    *":$DEP_PREFIX/bin:"*) ;;
    *) PATH="$DEP_PREFIX/bin:$PATH" ;;
  esac

  case ":$PATH:" in
    *":$PREFIX/bin:"*) ;;
    *) PATH="$PREFIX/bin:$PATH" ;;
  esac
  export PATH

  if [ -n "$multiarch" ]; then
    export PKG_CONFIG_PATH="$DEP_PREFIX/lib/$multiarch/pkgconfig:$DEP_PREFIX/lib/pkgconfig:$DEP_PREFIX/share/pkgconfig:$PREFIX/lib/$multiarch/pkgconfig:$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:${PKG_CONFIG_PATH:-}"
  else
    export PKG_CONFIG_PATH="$DEP_PREFIX/lib/pkgconfig:$DEP_PREFIX/share/pkgconfig:$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:${PKG_CONFIG_PATH:-}"
  fi

  export CMAKE_PREFIX_PATH="$DEP_PREFIX:$PREFIX:${CMAKE_PREFIX_PATH:-}"
  export XDG_DATA_DIRS="$DEP_PREFIX/share:$PREFIX/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
}

seatd_group()
{
  local group=""

  if [ -S /run/seatd.sock ]; then
    group="$(stat -c %G /run/seatd.sock 2>/dev/null || true)"
  fi

  if [ -n "$group" ] && getent group "$group" >/dev/null 2>&1; then
    printf '%s' "$group"
  elif getent group seat >/dev/null 2>&1; then
    printf seat
  elif getent group video >/dev/null 2>&1; then
    printf video
  else
    return 1
  fi
}

configure_seatd()
{
  dpkg_installed seatd || return 0
  as_root systemctl enable --now seatd >/dev/null 2>&1 || true

  local group
  group="$(seatd_group 2>/dev/null || true)"
  [ -n "$group" ] || return 0

  if id -nG "$USER" | tr ' ' '\n' | grep -qx "$group"; then
    return 0
  fi

  as_root usermod -aG "$group" "$USER"
  warn "added $USER to $group; relogin required"
}
