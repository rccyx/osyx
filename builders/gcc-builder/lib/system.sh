info() { printf '[%s] %s\n' "$1" "$2"; }
fail() { printf '[error] %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"; }

as_root()
{
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    need sudo
    sudo "$@"
  fi
}

load_platform()
{
  [ -r /etc/os-release ] || fail "missing /etc/os-release"
  source /etc/os-release
  [ "${ID:-}:${VERSION_CODENAME:-}" = "debian:trixie" ] || fail "unsupported system: ${PRETTY_NAME:-unknown}"
}

missing_packages()
{
  local package
  for package in "${PACKAGES[@]}"; do
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed' || printf '%s\n' "$package"
  done
}

install_packages()
{
  local missing=()
  mapfile -t missing < <(missing_packages)
  [ "${#missing[@]}" -eq 0 ] && return 0
  info install "packages"
  as_root apt-get update
  as_root apt-get install -y --no-install-recommends "${missing[@]}"
}

jobs()
{
  local count="${BUILDER_JOBS:-$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf 1)}"
  [[ "$count" =~ ^[1-9][0-9]*$ ]] || fail "BUILDER_JOBS must be a positive integer"
  printf '%s' "$count"
}

bootstrap_cc() { [ -x /usr/bin/gcc ] && printf /usr/bin/gcc || command -v gcc; }
bootstrap_cxx() { [ -x /usr/bin/g++ ] && printf /usr/bin/g++ || command -v g++; }
