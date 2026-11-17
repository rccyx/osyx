C_RESET=""
C_BOLD=""
C_DIM=""
C_RED=""
C_GREEN=""
C_YELLOW=""
C_BLUE=""
C_CYAN=""

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ]; then
  C_RESET="$(tput sgr0 2>/dev/null || true)"
  C_BOLD="$(tput bold 2>/dev/null || true)"
  C_DIM="$(tput dim 2>/dev/null || true)"
  C_RED="$(tput setaf 1 2>/dev/null || true)"
  C_GREEN="$(tput setaf 2 2>/dev/null || true)"
  C_YELLOW="$(tput setaf 3 2>/dev/null || true)"
  C_BLUE="$(tput setaf 4 2>/dev/null || true)"
  C_CYAN="$(tput setaf 6 2>/dev/null || true)"
fi

ui()
{
  local color="$1"
  local marker="$2"
  local label="$3"
  shift 3

  printf '%s%s%s %-10s %s\n' \
    "$color" \
    "$marker" \
    "$C_RESET" \
    "$label" \
    "$*"
}

log()
{
  case "$*" in
    "[compiler] "*)
      ui "$C_CYAN" "◆" "compiler" "${*#"[compiler] "}"
      ;;

    "[cache] "*)
      ui "$C_GREEN" "✓" "cached" "${*#"[cache] "}"
      ;;

    "[restore] "*)
      ui "$C_BLUE" "↺" "restore" "${*#"[restore] "}"
      ;;

    "[resume] "*)
      ui "$C_BLUE" "↻" "resume" "${*#"[resume] "}"
      ;;

    "[build] "*)
      ui "$C_BLUE" "●" "build" "${*#"[build] "}"
      ;;

    "")
      printf '\n'
      ;;

    *)
      printf '%s\n' "$*"
      ;;
  esac
}

info()
{
  local message="$*"
  local label=""

  case "$message" in
    "clone "*)
      label="clone"
      message="${message#clone }"
      ;;

    "fetch "*)
      label="fetch"
      message="${message#fetch }"
      ;;

    "download "*)
      label="download"
      message="${message#download }"
      ;;

    "compile "*)
      label="compile"
      message="${message#compile }"
      ;;

    "pin "*)
      label="configure"
      message="${message#pin }"
      ;;

    "apt install "*)
      label="packages"
      message="${message#apt install }"
      ;;

    *)
      label="working"
      ;;
  esac

  ui "$C_BLUE" "●" "$label" "$message"
}

ok()
{
  ui "$C_GREEN" "✓" "done" "$*"
}

warn()
{
  ui "$C_YELLOW" "!" "warning" "$*" >&2
}

err()
{
  ui "$C_RED" "✗" "error" "$*" >&2
}

die()
{
  err "$*"
  exit 1
}

usage()
{
  printf '%s%s%s\n\n' "$C_BOLD" "hypr-builder" "$C_RESET"

  printf '%s\n' \
    "usage:" \
    "  ./main plan" \
    "  ./main apply --yes" \
    "  ./main doctor" \
    "  ./main reset --yes" \
    "" \
    "commands:" \
    "  plan      show what will be reused or built" \
    "  apply     build and install the pinned Hyprland stack" \
    "  doctor    validate the installed stack" \
    "  reset     uninstall owned files and delete all caches"
}
