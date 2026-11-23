wallpaper() {
  emulate -L zsh
  setopt localoptions errreturn pipefail

  _wallpaper_check_deps || return 1
  _wallpaper_start_daemon

  case "${1:-}" in
    "")
      waypaper >/dev/null 2>&1 &!
      ;;
    set)
      shift
      local img="${1:-}"
      if [ ! -f "$img" ]; then
        printf "ERROR: File not found -> %s\n" "$img" >&2
        return 1
      fi
      waypaper --wallpaper "$img" >/dev/null 2>&1
      ;;
    random)
      waypaper --folder "${WALLPAPER_DIR:-$HOME/.wallpapers}" --random >/dev/null 2>&1
      ;;
    *)
      printf "Usage: wallpaper [set <file> | random]\n" >&2
      return 1
      ;;
  esac
}

_wallpaper_check_deps() {
  local missing=0 cmd
  for cmd in waypaper swww swww-daemon; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf "ERROR: '%s' is not installed or not in your PATH.\n" "$cmd" >&2
      missing=1
    fi
  done
  return "$missing"
}

_wallpaper_start_daemon() {
  if ! pgrep -x swww-daemon >/dev/null; then
    swww-daemon >/dev/null 2>&1 &!
    sleep 0.5
  fi
}
