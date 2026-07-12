#!/usr/bin/env bash
# command implementations + argument parsing + dispatch

VITALS=(
  ca-certificates gnupg curl wget
  git
  locales tzdata
  dbus dbus-user-session
  xdg-user-dirs
  sudo
)

BASE_TOOLS=(
  neovim
  tree
  htop btop
  unzip xz-utils
  openssh-client
  man-db less
  python3-jinja2 
)

STACK=(
  zsh
  tmux
  kitty
  wofi
  mako
  lsd
  fzf
  ripgrep
  fd-find
  bat
  starship
  pipx
)

DESKTOP_BASE=(
  network-manager
  seatd
  polkitd
  xwayland
  xdg-desktop-portal xdg-desktop-portal-wlr
  pipewire wireplumber pipewire-pulse
  wl-clipboard
  grim slurp
  brightnessctl
  playerctl
  fonts-noto-color-emoji
)

PROFILE="$PROFILE_DEFAULT"
PREFIX="$PREFIX_DEFAULT"
LOCALE="$LOCALE_DEFAULT"
TZ="$TZ_DEFAULT"
YES=0

ensure_bat_alias(){
  if have bat; then return 0; fi
  if have batcat && [[ ! -e /usr/local/bin/bat ]]; then
    as_root mkdir -p /usr/local/bin
    as_root ln -sf "$(command -v batcat)" /usr/local/bin/bat || true
  fi
}

ensure_fd_alias(){
  if have fd; then return 0; fi
  if have fdfind && [[ ! -e /usr/local/bin/fd ]]; then
    as_root mkdir -p /usr/local/bin
    as_root ln -sf "$(command -v fdfind)" /usr/local/bin/fd || true
  fi
}

run_local_script(){
  local rel="$1"
  local p="$REPO_ROOT/$rel"
  [[ -f "$p" ]] || die "missing script: $rel"
  chmod +x "$p" >/dev/null 2>&1 || true
  local first
  first="$(head -n1 "$p" 2>/dev/null || true)"
  if [[ "$first" == *zsh* ]]; then
    apt_install_best_effort zsh
    info "run zsh: $rel"
    zsh "$p"
  else
    info "run bash: $rel"
    bash "$p"
  fi
}

ensure_locale_tz(){
  local loc="$1" tz="$2"
  apt_install_best_effort locales tzdata
  if [[ -n "$loc" ]]; then
    local gen="/etc/locale.gen"
    local lang="${loc%.*}"
    if ! grep -qE "^[[:space:]]*${loc}[[:space:]]+UTF-8" "$gen" 2>/dev/null; then
      as_root bash -lc "printf '%s UTF-8\n' '$lang' >> '$gen' || true"
      as_root bash -lc "printf '%s UTF-8\n' '$loc' >> '$gen' || true"
    fi
    as_root locale-gen >/dev/null 2>&1 || true
    as_root update-locale "LANG=$loc" >/dev/null 2>&1 || true
  fi

  if [[ -n "$tz" ]]; then
    if is_systemd && have timedatectl; then
      as_root timedatectl set-timezone "$tz" >/dev/null 2>&1 || true
    else
      if [[ -e "/usr/share/zoneinfo/$tz" ]]; then
        as_root ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime || true
        printf "%s\n" "$tz" | as_root tee /etc/timezone >/dev/null 2>&1 || true
      fi
    fi
  fi
}

usage(){
  local self
  self="$(basename "${BASH_SOURCE[0]:-$0}")"

  cat <<EOF
${C_BOLD}${self}${C_RESET} v$VERSION

synopsis:
  ${self} <command> [options]

commands:
  fresh     root-only first stage for a new debian install (baseline packages + networking + locale/tz)
  plan      read-only: compute what would change (missing apt deps)
  apply     install + configure (apt deps, locale/tz, services/groups, extras)
  doctor    print diagnostics (kernel/groups/tools/paths)
  status    print saved state (if any)
  clean     remove logs (default) or remove logs+cache+state with --all
  help      show this help

command usage:
  ${self} fresh [--user=<name>] [--locale=$LOCALE_DEFAULT] [--tz=$TZ_DEFAULT] [--yes]
  ${self} plan  [--profile=min|desktop] [--prefix=$PREFIX_DEFAULT] [--locale=$LOCALE_DEFAULT] [--tz=$TZ_DEFAULT] [--with=a,b,c] [--yes]
  ${self} apply [--profile=min|desktop] [--prefix=$PREFIX_DEFAULT] [--locale=$LOCALE_DEFAULT] [--tz=$TZ_DEFAULT] [--with=a,b,c] --yes
  ${self} doctor
  ${self} status
  ${self} clean [--all]

options:
  --profile=min|desktop   package set (default: $PROFILE_DEFAULT)
  --prefix=/usr/local     install prefix (default: $PREFIX_DEFAULT)
  --locale=LOCALE         locale to generate + set LANG (default: $LOCALE_DEFAULT)
  --tz=AREA/City          timezone (default: $TZ_DEFAULT)
  --with=a,b,c            run extra installers after base packages (comma list)
  --yes                   non-interactive confirmation for destructive actions
  -h, --help              show this help

important behavior:
  apply is destructive and requires --yes. without --yes it exits with code 2 and prints the exact rerun command.
  plan accepts --yes for symmetry but it does nothing (plan is always read-only).
  if you run plan/apply as root, the script auto re-execs as the detected main user. to force it, set MAIN_USER=<name>.
  some changes require relogin or reboot (group membership, default shell). the script will tell you when.

    examples:
      sudo ./$BOOTSTRAP_REL fresh --user=$(id -un) --yes
      ./$BOOTSTRAP_REL plan --profile=desktop
      ./$BOOTSTRAP_REL apply --profile=desktop --yes
      ./$BOOTSTRAP_REL apply --profile=min --yes
      ./$BOOTSTRAP_REL doctor
      ./$BOOTSTRAP_REL status
      ./$BOOTSTRAP_REL clean
      ./$BOOTSTRAP_REL clean --all
EOF
}

parse_args(){
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile=*) PROFILE="${1#*=}" ;;
      --prefix=*) PREFIX="${1#*=}" ;;
      --locale=*) LOCALE="${1#*=}" ;;
      --tz=*) TZ="${1#*=}" ;;
      --yes) YES=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown arg: $1" ;;
    esac
    shift
  done

  if [[ "$PROFILE" != "min" && "$PROFILE" != "desktop" ]]; then
    die "invalid --profile (min|desktop): $PROFILE"
  fi
}

doctor(){
  start_logging
  log "${C_BOLD}doctor${C_RESET}"
  log "kernel: $(uname -r)"
  log "groups: $(id -nG)"
  log "sudo:   $(have sudo && echo yes || echo no)"
  log "zsh:    $(have zsh && echo yes || echo no)"
  log "omz:    $([[ -d "$HOME/.oh-my-zsh" ]] && echo yes || echo no)"
  log "seatd:  $(dpkg_installed seatd && echo installed || echo no)"
  log "nm:     $(dpkg_installed network-manager && echo installed || echo no)"
  log "state:  $STATE_FILE"
}

status(){
  start_logging
  load_state
  log "${C_BOLD}status${C_RESET}"
  if [[ -f "$STATE_FILE" ]]; then
    sed -n 's/^/  /p' "$STATE_FILE"
  else
    log "  (no state yet)"
  fi
}

clean(){
  start_logging
  local all="${1:-}"
  if [[ "$all" == "--all" ]]; then
    info "removing cache and state"
    rm -rf "$CACHE_DIR" "$STATE_DIR"
    ok "cleaned"
    return 0
  fi
  info "removing logs only"
  rm -rf "$LOG_DIR"
  ok "cleaned logs"
}

plan(){
  start_logging
  if ! is_debian; then warn "not debian, plan may be wrong"; fi

  local -a want=()
  want+=("${VITALS[@]}")
  want+=("${BASE_TOOLS[@]}")
  want+=("${STACK[@]}")
  if [[ "$PROFILE" == "desktop" ]]; then want+=("${DESKTOP_BASE[@]}"); fi

  local -a missing=()
  local p
  for p in "${want[@]}"; do
    dpkg_installed "$p" || missing+=("$p")
  done

  log "${C_BOLD}Plan${C_RESET}"
  if [[ "${#missing[@]}" -gt 0 ]]; then
    log "  + apt install (${#missing[@]}):"
    for p in "${missing[@]}"; do log "    - $p"; done
  else
    log "  = apt deps: already satisfied"
  fi

  log ""
  log "to apply: ${C_BOLD}./$BOOTSTRAP_REL apply --profile=$PROFILE --prefix=$PREFIX --yes${C_RESET}"
}

apply(){
  start_logging
  if ! is_debian; then warn "not debian, continuing"; fi

  if [[ "${YES:-0}" -ne 1 ]]; then
    warn "confirmation required"
    log "run: ./$BOOTSTRAP_REL apply --yes --profile=$PROFILE"
    exit 2
  fi

  ensure_sudo_present

  info "installing vitals"
  apt_install_best_effort "${VITALS[@]}"

  info "installing base tools"
  apt_install_best_effort "${BASE_TOOLS[@]}"

  info "installing stack"
  apt_install_best_effort "${STACK[@]}"
  
  if ! have lsd; then warn "lsd not found in apt. install manually or via cargo."; fi
  if ! have starship; then warn "starship not found in apt. install manually via install script."; fi

  if [[ "$PROFILE" == "desktop" ]]; then
    info "installing desktop base"
    apt_install_best_effort "${DESKTOP_BASE[@]}"
  fi

  ensure_locale_tz "$LOCALE" "$TZ"

  if dpkg_installed network-manager; then
    as_root systemctl enable NetworkManager --now >/dev/null 2>&1 || true
  fi

  if dpkg_installed seatd; then
    as_root systemctl enable seatd --now >/dev/null 2>&1 || true
    ensure_group_membership seat
  fi

  ensure_group_membership sudo
  ensure_group_membership video
  ensure_group_membership input
  ensure_group_membership audio

  if dpkg_installed zsh; then
    if [[ "${SHELL:-}" != "/usr/bin/zsh" && -x /usr/bin/zsh ]]; then
      chsh -s /usr/bin/zsh "$USER" >/dev/null 2>&1 || true
      ok "zsh set as default shell (may require relogin)"
    fi
  fi

  ensure_fd_alias
  ensure_bat_alias

  if dpkg_installed xdg-user-dirs; then
    xdg-user-dirs-update >/dev/null 2>&1 || true
  fi

  save_state_kv "OSYX_BOOTSTRAP_PROFILE" "$PROFILE"
  save_state_kv "OSYX_BOOTSTRAP_PREFIX" "$PREFIX"
  save_state_kv "OSYX_BOOTSTRAP_LOCALE" "$LOCALE"
  save_state_kv "OSYX_BOOTSTRAP_TZ" "$TZ"
  save_state_kv "OSYX_BOOTSTRAP_APPLIED_AT" "$(date -Is 2>/dev/null || date)"

  info "installing core runtimes"
  run_local_script "provisioning/runtimes/rust"
  run_local_script "provisioning/runtimes/node"
  run_local_script "provisioning/runtimes/pnpm"
  run_local_script "provisioning/runtimes/go"
  run_local_script "provisioning/runtimes/uv"

  info "setting up shell plugins"
  run_local_script "provisioning/setup/shell/enable-zsh-plugs.zsh"

  ok "done"
  if [[ "${OSYX_BOOTSTRAP_NEEDS_RELOGIN:-0}" == "1" ]]; then
    warn "relogin or reboot is required (groups/shell)"
  fi
  
  bash "$REPO_ROOT/bin/_install_"
  bash "$REPO_ROOT/config/_install_"
}

fresh_root_stage(){
  local user="$1"
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "fresh must run as root (use: sudo ./$BOOTSTRAP_REL fresh --user=... )"
  export DEBIAN_FRONTEND=noninteractive

  info "fresh stage: base system packages"
  apt-get update -y

  apt-get install -y --no-install-recommends \
    sudo adduser passwd login \
    util-linux coreutils findutils procps \
    ca-certificates gnupg curl wget \
    locales tzdata \
    git \
    dbus dbus-user-session \
    network-manager openssh-client \
    rfkill pciutils usbutils lsb-release \
    man-db less vim nano \
    fontconfig fonts-dejavu fonts-liberation \
    xdg-user-dirs || true

  apt-get install -y firmware-linux firmware-linux-nonfree firmware-misc-nonfree || true

  systemctl enable NetworkManager --now >/dev/null 2>&1 || true
  if [[ -n "$user" ]]; then
    usermod -aG sudo "$user" >/dev/null 2>&1 || true
    su - "$user" -c "xdg-user-dirs-update" >/dev/null 2>&1 || true
  fi

  ok "fresh stage done"
  warn "reboot recommended if networking or groups were weird"
}

fresh(){
  local user=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user=*) user="${1#*=}" ;;
      --locale=*) LOCALE="${1#*=}" ;;
      --tz=*) TZ="${1#*=}" ;;
      --yes) YES=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown arg: $1" ;;
    esac
    shift
  done

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "fresh must run as root (use sudo)"
  fi

  if [[ -z "$user" ]]; then
    user="$(pick_main_user || true)"
  fi

  start_logging
  fresh_root_stage "$user"
  ensure_locale_tz "$LOCALE" "$TZ"

  ok "fresh complete"
  if [[ -n "$user" ]]; then
    warn "now log in as: $user"
    log "then run: ./$BOOTSTRAP_REL apply --profile=$PROFILE_DEFAULT --yes"
  else
    warn "could not determine user automatically"
    log "run apply as your normal user after you log in"
  fi
}

main(){
  case "${CMD:-}" in
    fresh)
      fresh "$@"
      ;;
    plan)
      parse_args "$@"
      if [[ "${EUID:-$(id -u)}" -eq 0 && -z "${OSYX_BOOTSTRAP_REENTERED:-}" ]]; then
        local u
        u="$(pick_main_user || true)"
        [[ -n "$u" ]] || die "run plan as normal user (or set MAIN_USER)"
        reexec_as_user "$u" "plan" "--profile=$PROFILE" "--prefix=$PREFIX" "--locale=$LOCALE" "--tz=$TZ" || true
      fi
      plan
      ;;
    apply)
      parse_args "$@"
      if [[ "${EUID:-$(id -u)}" -eq 0 && -z "${OSYX_BOOTSTRAP_REENTERED:-}" ]]; then
        local u
        u="$(pick_main_user || true)"
        [[ -n "$u" ]] || die "run apply as normal user (or set MAIN_USER)"
        local -a a=("apply" "--profile=$PROFILE" "--prefix=$PREFIX" "--locale=$LOCALE" "--tz=$TZ")
        [[ "$YES" -eq 1 ]] && a+=("--yes")
        reexec_as_user "$u" "${a[@]}"
      fi
      apply
      ;;
    doctor) doctor ;;
    status) status ;;
    clean) clean "$@" ;;
    ""|help|-h|--help) usage ;;
    *) die "unknown command: $CMD" ;;
  esac
}
