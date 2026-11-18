
# vpn.zsh
# Encrypted WireGuard profiles. Linux + Zsh.

typeset -gr VPN_KEY='79821E0224D34EC4969FF6A8E5168EE090AE80D0' # change this key to yours
typeset -g VPN_DIR="${VPN_DIR:-$HOME/vpn}"
typeset -gr VPN_IFACE='wg-vault'
typeset -gr VPN_RUN="/run/vpn-vault-$(id -u)"

_vpn_err() {
  print -ru2 -- "vpn: $*"
}

_vpn_need() {
  command -v "$1" >/dev/null 2>&1 && return 0
  _vpn_err "missing dependency: $1"
  return 127
}

_vpn_root() {
  if (( EUID == 0 )); then
    command "$@"
  else
    command sudo "$@"
  fi
}

_vpn_name() {
  emulate -L zsh
  local name="$1"

  if (( ${#name} < 1 || ${#name} > 128 )) ||
     [[ ! "$name" =~ '^[A-Za-z0-9][A-Za-z0-9_.-]*$' ]]; then
    _vpn_err "invalid name: use 1-128 letters, digits, dots, hyphens or underscores"
    return 1
  fi

  print -r -- "$name"
}

_vpn_ready() {
  _vpn_need gpg || return $?

  [[ -d "$VPN_DIR" && ! -L "$VPN_DIR" ]] || {
    _vpn_err "run vpn init first"
    return 1
  }

  [[ -f "$VPN_DIR/.gpg-id" && ! -L "$VPN_DIR/.gpg-id" ]] || {
    _vpn_err "run vpn init first"
    return 1
  }

  [[ "$(<"$VPN_DIR/.gpg-id")" == "$VPN_KEY" ]] || {
    _vpn_err "GPG key mismatch"
    return 1
  }
}

_vpn_temp() {
  emulate -L zsh

  local base="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

  _vpn_need findmnt || return $?

  [[ -d "$base" && ! -L "$base" ]] || {
    _vpn_err "runtime directory unavailable"
    return 1
  }

  [[ "$(command stat -c %u -- "$base")" == "$EUID" ]] &&
  [[ "$(command findmnt -n -o FSTYPE -T "$base")" == tmpfs ]] || {
    _vpn_err "secure tmpfs runtime directory required"
    return 1
  }

  ( umask 077; command mktemp -d "$base/vpn.XXXXXXXX" )
}

_vpn_runtime() {
  _vpn_need findmnt || return $?

  [[ "$(command findmnt -n -o FSTYPE -T /run)" == tmpfs ]] || {
    _vpn_err "/run must be tmpfs"
    return 1
  }

  _vpn_root install -d -o root -g root -m 700 "$VPN_RUN"
}

_vpn_profiles() {
  emulate -L zsh
  local file name

  for file in "$VPN_DIR"/*.conf.gpg(N); do
    [[ -L "$file" ]] && continue

    name="${file:t}"
    name="${name%.conf.gpg}"

    _vpn_name "$name" >/dev/null 2>&1 &&
      print -r -- "$name"
  done
}

_vpn_pick() {
  emulate -L zsh
  _vpn_need fzf || return $?

  local names selected
  names="$(_vpn_profiles)"

  [[ -n "$names" ]] || {
    _vpn_err "no saved profiles"
    return 1
  }

  selected="$(print -r -- "$names" |
    command fzf --height=40% --reverse \
      --border=rounded --prompt='vpn > ')" || return $?

  [[ -n "$selected" ]] || return 1
  _vpn_name "$selected"
}

_vpn_validate() {
  emulate -L zsh

  local file="$1"

  # Allow declarative WireGuard configuration only.
  # Reject hooks, SaveConfig and unknown directives.
  command awk '
    function trim(s) {
      sub(/^[ \t\r]+/, "", s)
      sub(/[ \t\r]+$/, "", s)
      return s
    }

    BEGIN {
      section = ""
      interfaces = 0
      peers = 0
      private = 0
      public = 0
      invalid = 0
    }

    {
      line = trim($0)

      if (line == "" || line ~ /^#/) next

      if (line == "[Interface]") {
        section = "interface"
        interfaces++
        next
      }

      if (line == "[Peer]") {
        section = "peer"
        peers++
        next
      }

      pos = index(line, "=")

      if (!pos || section == "") {
        invalid = 1
        next
      }

      key = trim(substr(line, 1, pos - 1))
      value = trim(substr(line, pos + 1))

      if (value == "") {
        invalid = 1
        next
      }

      if (section == "interface") {
        if (key == "PrivateKey") private++
        else if (key !~ /^(Address|DNS|MTU|Table|ListenPort|FwMark)$/)
          invalid = 1
      } else {
        if (key == "PublicKey") public++
        else if (key !~ /^(PresharedKey|AllowedIPs|Endpoint|PersistentKeepalive)$/)
          invalid = 1
      }
    }

    END {
      if (invalid || interfaces != 1 || peers < 1 ||
          private != 1 || public != peers)
        exit 1
    }
  ' "$file" || {
    _vpn_err "invalid or unsafe WireGuard configuration"
    return 1
  }

  _vpn_need wg-quick || return $?

  command wg-quick strip "$file" >/dev/null 2>&1 || {
    _vpn_err "wg-quick rejected configuration"
    return 1
  }
}

_vpn_connected() {
  _vpn_root wg show "$VPN_IFACE" >/dev/null 2>&1
}

_vpn_current() {
  _vpn_root cat "$VPN_RUN/current/name" 2>/dev/null
}

vpn.init() {
  emulate -L zsh
  _vpn_need gpg || return $?

  command gpg --list-secret-keys "$VPN_KEY" \
    >/dev/null 2>&1 || {
    _vpn_err "GPG secret key unavailable"
    return 1
  }

  [[ ! -L "$VPN_DIR" ]] || {
    _vpn_err "store must not be a symlink"
    return 1
  }

  if [[ -e "$VPN_DIR/.gpg-id" || -L "$VPN_DIR/.gpg-id" ]]; then
    _vpn_ready || return $?
    print -r -- "vpn: already initialized"
    return 0
  fi

  (
    umask 077
    command mkdir -p -m 700 -- "$VPN_DIR" || exit $?
    command chmod 700 -- "$VPN_DIR" || exit $?
    setopt noclobber
    print -r -- "$VPN_KEY" > "$VPN_DIR/.gpg-id"
  ) || return $?

  print -r -- "vpn: initialized"
}

vpn.add() {
  emulate -L zsh

  _vpn_ready || return $?

  local name="" tmp="" conf="" encrypted="" dest=""
  local arg rc=0 tty_state=""

  while (( $# )); do
    arg="$1"
    shift

    case "$arg" in
      --name)
        (( $# )) || {
          _vpn_err "--name requires a value"
          return 2
        }
        name="$1"
        shift
        ;;
      *)
        _vpn_err "unknown argument: $arg"
        return 2
        ;;
    esac
  done

  if [[ -z "$name" ]]; then
    read -r 'name?name: ' || return 1
  fi

  name="$(_vpn_name "$name")" || return $?
  dest="$VPN_DIR/$name.conf.gpg"

  [[ ! -e "$dest" && ! -L "$dest" ]] || {
    _vpn_err "profile already exists: $name"
    return 1
  }

  tmp="$(_vpn_temp)" || return $?
  conf="$tmp/$VPN_IFACE.conf"

  {
    umask 077

    print -ru2 -- "paste WireGuard config; finish with Ctrl+D"

    if [[ -t 0 ]]; then
      tty_state="$(command stty -g)" || return $?
      command stty -echo || return $?
    fi

    command cat > "$conf"
    rc=$?

    if [[ -n "$tty_state" ]]; then
      command stty "$tty_state"
      tty_state=""
      print -ru2
    fi

    (( rc == 0 )) || return $rc

    [[ -s "$conf" ]] || {
      _vpn_err "empty configuration"
      return 1
    }

    _vpn_validate "$conf" || return $?

    encrypted="$(command mktemp "$VPN_DIR/.new.XXXXXXXX")" ||
      return $?

    command gpg --batch --trust-model always \
      --encrypt --recipient "$VPN_KEY" \
      --output "$encrypted" "$conf" || return $?

    command gpg --decrypt "$encrypted" >/dev/null ||
      return $?

    command chmod 600 -- "$encrypted" || return $?

    # Publish without overwriting an existing profile.
    command ln -- "$encrypted" "$dest" || return $?

    print -r -- "vpn: added $name"
  } always {
    [[ -n "$tty_state" ]] && command stty "$tty_state"
    [[ -n "$encrypted" ]] && command rm -f -- "$encrypted"
    [[ -n "$conf" ]] && command rm -f -- "$conf"
    [[ -n "$tmp" ]] && command rmdir -- "$tmp" 2>/dev/null
  }
}

vpn.on() {
  emulate -L zsh

  _vpn_ready || return $?
  _vpn_need wg || return $?
  _vpn_need wg-quick || return $?

  local name="" tmp="" conf="" encrypted=""
  local current="" arg
  local -a interfaces

  while (( $# )); do
    arg="$1"
    shift

    case "$arg" in
      --name)
        (( $# )) || {
          _vpn_err "--name requires a value"
          return 2
        }
        name="$1"
        shift
        ;;
      *)
        _vpn_err "unknown argument: $arg"
        return 2
        ;;
    esac
  done

  [[ -n "$name" ]] || name="$(_vpn_pick)" || return $?
  name="$(_vpn_name "$name")" || return $?

  encrypted="$VPN_DIR/$name.conf.gpg"

  [[ -f "$encrypted" && ! -L "$encrypted" ]] || {
    _vpn_err "profile not found: $name"
    return 1
  }

  _vpn_need sudo || (( EUID == 0 )) || return $?
  (( EUID == 0 )) || command sudo -v || return $?

  _vpn_runtime || return $?

  if _vpn_connected; then
    current="$(_vpn_current)"

    [[ -n "$current" ]] || {
      _vpn_err "interface already exists outside VPN manager"
      return 1
    }

    if [[ "$current" == "$name" ]]; then
      print -r -- "vpn: already connected to $name"
      return 0
    fi
  fi

  # Refuse ambiguous recovery states.
  if _vpn_root test -e "$VPN_RUN/previous"; then
    _vpn_err "unfinished previous switch; inspect runtime state"
    return 1
  fi

  if _vpn_root test -e "$VPN_RUN/next"; then
    _vpn_err "unfinished pending connection; inspect runtime state"
    return 1
  fi

  tmp="$(_vpn_temp)" || return $?
  conf="$tmp/$VPN_IFACE.conf"

  {
    umask 077

    command gpg --decrypt --output "$conf" "$encrypted" ||
      return $?

    _vpn_validate "$conf" || return $?

    print -rn -- "$name" > "$tmp/name"

    _vpn_root install -d -o root -g root -m 700 \
      "$VPN_RUN/next" || return $?

    if ! _vpn_root install -o root -g root -m 600 \
      "$conf" "$VPN_RUN/next/$VPN_IFACE.conf"; then
      _vpn_root rm -rf -- "$VPN_RUN/next"
      return 1
    fi

    if ! _vpn_root install -o root -g root -m 600 \
      "$tmp/name" "$VPN_RUN/next/name"; then
      _vpn_root rm -rf -- "$VPN_RUN/next"
      return 1
    fi

    if _vpn_connected; then
      if ! _vpn_root wg-quick down \
        "$VPN_RUN/current/$VPN_IFACE.conf"; then
        _vpn_root rm -rf -- "$VPN_RUN/next"
        return 1
      fi

      if ! _vpn_root mv -- \
        "$VPN_RUN/current" "$VPN_RUN/previous"; then
        _vpn_err "failed to preserve previous connection"
        _vpn_root rm -rf -- "$VPN_RUN/next"
        return 1
      fi
    elif _vpn_root test -d "$VPN_RUN/current"; then
      # Stale state from an inactive managed tunnel.
      _vpn_root rm -rf -- "$VPN_RUN/current" || return $?
    fi

    if ! _vpn_root mv -- "$VPN_RUN/next" "$VPN_RUN/current"; then
      _vpn_err "failed to install runtime configuration"
      if _vpn_root test -d "$VPN_RUN/previous"; then
        _vpn_root mv -- "$VPN_RUN/previous" "$VPN_RUN/current"
        _vpn_root wg-quick up "$VPN_RUN/current/$VPN_IFACE.conf"
      fi
      return 1
    fi

    if _vpn_root wg-quick up "$VPN_RUN/current/$VPN_IFACE.conf"; then
      _vpn_root rm -rf -- "$VPN_RUN/previous"
      print -r -- "vpn: connected to $name"
      return 0
    fi

    _vpn_err "failed to connect to $name"
    _vpn_root rm -rf -- "$VPN_RUN/current"

    if _vpn_root test -d "$VPN_RUN/previous"; then
      _vpn_root mv -- "$VPN_RUN/previous" "$VPN_RUN/current" ||
        return 1

      _vpn_root wg-quick up "$VPN_RUN/current/$VPN_IFACE.conf" ||
        _vpn_err "failed to restore previous VPN"
    fi

    return 1
  } always {
    [[ -n "$conf" ]] && command rm -f -- "$conf"
    [[ -n "$tmp" ]] && command rm -f -- "$tmp/name"
    [[ -n "$tmp" ]] && command rmdir -- "$tmp" 2>/dev/null
  }
}

vpn.off() {
  emulate -L zsh

  _vpn_need wg || return $?
  _vpn_need wg-quick || return $?

  local name=""
  name="$(_vpn_current)"

  if ! _vpn_connected; then
    if [[ -n "$name" ]]; then
      _vpn_root rm -rf -- "$VPN_RUN/current" || return $?
    fi
    print -r -- "vpn: off"
    return 0
  fi

  [[ -n "$name" ]] || {
    _vpn_err "refusing to disconnect unmanaged interface"
    return 1
  }

  _vpn_root wg-quick down \
    "$VPN_RUN/current/$VPN_IFACE.conf" || return $?

  _vpn_root rm -rf -- "$VPN_RUN/current" || return $?

  print -r -- "vpn: disconnected $name"
}

vpn.status() {
  emulate -L zsh

  _vpn_need wg || return $?

  local name=""
  name="$(_vpn_current)"

  if ! _vpn_connected; then
    print -r -- "VPN: off"
    return 0
  fi

  [[ -n "$name" ]] || {
    _vpn_err "WireGuard interface is active but unmanaged"
    return 1
  }

  print -r -- "VPN: on"
  print -r -- "profile: $name"

  _vpn_root wg show "$VPN_IFACE" endpoints
  _vpn_root wg show "$VPN_IFACE" latest-handshakes
  _vpn_root wg show "$VPN_IFACE" transfer
}

vpn.list() {
  emulate -L zsh
  _vpn_ready || return $?
  _vpn_profiles
}

vpn.remove() {
  emulate -L zsh

  _vpn_ready || return $?

  local name="" arg answer="" current=""

  while (( $# )); do
    arg="$1"
    shift

    case "$arg" in
      --name)
        (( $# )) || {
          _vpn_err "--name requires a value"
          return 2
        }
        name="$1"
        shift
        ;;
      *)
        _vpn_err "unknown argument: $arg"
        return 2
        ;;
    esac
  done

  [[ -n "$name" ]] || name="$(_vpn_pick)" || return $?
  name="$(_vpn_name "$name")" || return $?

  local file="$VPN_DIR/$name.conf.gpg"

  [[ -f "$file" && ! -L "$file" ]] || {
    _vpn_err "profile not found: $name"
    return 1
  }

  current="$(_vpn_current)"

  if [[ "$current" == "$name" ]]; then
    _vpn_err "disconnect $name before removing it"
    return 1
  fi

  read -r "answer?remove $name? [y/N] " || return 1
  [[ "$answer" == [yY] ]] || return 1

  command rm -- "$file" || return $?
  print -r -- "vpn: removed $name"
}

vpn() {
  emulate -L zsh

  local action="${1:-}"
  (( $# )) && shift

  if [[ -z "$action" ]]; then
    _vpn_need fzf || return $?

    action="$(printf '%s\n' \
      on off status add list remove init |
      command fzf --height=40% --reverse \
        --border=rounded --prompt='vpn > ')" || return $?
  fi

  case "$action" in
    init)   vpn.init "$@" ;;
    add)    vpn.add "$@" ;;
    on)     vpn.on "$@" ;;
    off)    vpn.off "$@" ;;
    status) vpn.status "$@" ;;
    list)   vpn.list "$@" ;;
    remove) vpn.remove "$@" ;;
    *)
      _vpn_err "unknown command: $action"
      return 2
      ;;
  esac
}

_vpn_completion() {
  local -a actions profiles

  actions=(init add on off status list remove)
  profiles=("${(@f)$(_vpn_profiles)}")

  if (( CURRENT == 2 )); then
    _describe 'vpn commands' actions
  elif (( CURRENT == 3 )); then
    case "${words[2]}" in
      on|remove) _describe 'vpn profiles' profiles ;;
    esac
  fi
}

if (( $+functions[compdef] )); then
  compdef _vpn_completion vpn
fi
