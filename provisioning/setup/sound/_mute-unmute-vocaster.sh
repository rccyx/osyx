#!/usr/bin/env bash

set -euo pipefail

readonly binary="${HOME}/.local/bin/vocaster"
readonly state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/osyx/vocaster"
readonly dependency_marker="${state_dir}/installed-alsa-utils"

fail()
{
  printf 'vocaster: %s\n' "$*" >&2
  exit 1
}

install_dependency()
{
  if command -v amixer >/dev/null 2>&1; then
    return 0
  fi

  command -v apt-get >/dev/null 2>&1 ||
    fail "apt-get is unavailable"

  command -v sudo >/dev/null 2>&1 ||
    fail "sudo is unavailable"

  sudo apt-get update
  sudo apt-get install -y alsa-utils

  install -d "$state_dir"
  : > "$dependency_marker"
}

remove_dependency()
{
  if [[ ! -e $dependency_marker ]]; then
    return 0
  fi

  command -v apt-get >/dev/null 2>&1 ||
    fail "apt-get is unavailable"

  command -v sudo >/dev/null 2>&1 ||
    fail "sudo is unavailable"

  sudo apt-get purge -y alsa-utils
}

write_binary()
{
  install -d "$(dirname "$binary")"

  local tmp
  tmp="$(mktemp "${binary}.tmp.XXXXXX")"

  cat > "$tmp" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

export LC_ALL=C

readonly device="Vocaster One"
readonly control="name='Line In 1 Mute Capture Switch'"
readonly lock="${XDG_RUNTIME_DIR:-/tmp}/vocaster-${UID}.lock"

fail()
{
  printf 'vocaster: %s\n' "$*" >&2
  exit 1
}

command -v amixer >/dev/null 2>&1 ||
  fail "amixer is not installed"

[[ -r /proc/asound/cards ]] ||
  fail "/proc/asound/cards is unavailable"

exec 9>"$lock"

# Drop duplicate key events instead of queueing another toggle.
flock -n 9 || exit 0

mapfile -t cards < <(
  awk -v device="$device" '
    $1 ~ /^[0-9]+$/ && index($0, device) {
      print $1
    }
  ' /proc/asound/cards
)

case "${#cards[@]}" in
  0)
    fail "$device is not connected"
    ;;

  1)
    readonly card="${cards[0]}"
    ;;

  *)
    fail "multiple $device devices are connected"
    ;;
esac

read_state()
{
  amixer -c "$card" cget "$control" |
    awk -F= '
      /^[[:space:]]*: values=/ {
        gsub(/[[:space:]]/, "", $2)
        print $2
        exit
      }
    '
}

set_state()
{
  local target="$1"

  amixer -q -c "$card" cset "$control" "$target"

  # Keep the lock briefly so duplicate key events cannot toggle it back.
  sleep 0.25
}

amixer -c "$card" cget "$control" >/dev/null 2>&1 ||
  fail "the Vocaster hardware mute control is unavailable"

case "${1:-toggle}" in
  toggle)
    case "$(read_state)" in
      on)
        set_state off
        ;;

      off)
        set_state on
        ;;

      *)
        fail "could not read the mute state"
        ;;
    esac
    ;;

  mute)
    set_state on
    ;;

  unmute)
    set_state off
    ;;

  state)
    case "$(read_state)" in
      on)
        printf '%s\n' "muted"
        ;;

      off)
        printf '%s\n' "unmuted"
        ;;

      *)
        fail "could not read the mute state"
        ;;
    esac
    ;;

  *)
    fail "usage: vocaster [toggle|mute|unmute|state]"
    ;;
esac
EOF

  chmod 0755 "$tmp"
  mv -f "$tmp" "$binary"
}

setup()
{
  install_dependency
  write_binary

  printf '%s\n' "vocaster setup complete"
}

destroy()
{
  rm -f "$binary"

  remove_dependency
  rm -rf "$state_dir"

  printf '%s\n' "vocaster destroy complete"
}

[[ ${EUID} -ne 0 ]] ||
  fail "run this as your user, not with sudo"

case "${1:-}" in
  setup)
    setup
    ;;

  destroy)
    destroy
    ;;

  *)
    fail "usage: $0 {setup|destroy}"
    ;;
esac
