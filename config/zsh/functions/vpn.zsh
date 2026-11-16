# vpn.zsh — clean UI
# Colors: standard ANSI only (theme-safe)
# Plumbing: fully hidden behind gum spinner

typeset -g JARVIS_VPN_DIR="${JARVIS_VPN_DIR:-}"
typeset -g JARVIS_VPN_ETC_DIR="${JARVIS_VPN_ETC_DIR:-/etc/wireguard}"
typeset -g JARVIS_VPN_PREFIX="${JARVIS_VPN_PREFIX:-wg-}"
typeset -g JARVIS_VPN_STRIP_TOKENS="${JARVIS_VPN_STRIP_TOKENS:-proton protonvpn vpn}"
typeset -g JARVIS_VPN_DNS_TEST_HOST="${JARVIS_VPN_DNS_TEST_HOST:-example.com}"
typeset -g JARVIS_VPN_DNS_TIMEOUT_S="${JARVIS_VPN_DNS_TIMEOUT_S:-3}"

_vpn__have(){ command -v "$1" >/dev/null 2>&1; }
_vpn__need_sudo(){ [ "${EUID:-$(id -u)}" -ne 0 ] && echo sudo; }

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
_vpn__ui_init(){
  if [ -t 2 ]; then
    local rs=$'\e[0m' bd=$'\e[1m' dm=$'\e[2m'
    local grn=$'\e[32m' red=$'\e[31m' cyn=$'\e[36m'
    _vpn__ok(){   print -ru2 -- "  ${grn}${bd}✓${rs}  $*"; }
    _vpn__err(){  print -ru2 -- "  ${red}${bd}✗${rs}  $*"; }
    _vpn__note(){ print -ru2 -- "  ${cyn}${bd}·${rs}  ${dm}$*${rs}"; }
  else
    _vpn__ok(){   print -ru2 -- "vpn ok   $*"; }
    _vpn__err(){  print -ru2 -- "vpn err  $*"; }
    _vpn__note(){ print -ru2 -- "vpn      $*"; }
  fi
}

# Run cmd with gum spinner — all output suppressed.
# On failure, re-runs visibly so the actual error shows.
_vpn__run(){
  local msg="$1"; shift
  if _vpn__have gum; then
    gum spin --spinner dot --title "  ${msg}" -- "$@" >/dev/null 2>&1
    local rc=$?
    if [[ $rc -ne 0 ]]; then
      # surface the real error
      print -ru2 -- ""
      "$@" >/dev/null
      return $rc
    fi
    return 0
  else
    # no gum: suppress stdout only, keep stderr for sudo prompts
    print -rn -- "  ${msg}" >&2
    "$@" 1>/dev/null
    local rc=$?
    print -ru2 -- ""
    return $rc
  fi
}

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------
_vpn__dir(){
  [[ -n "${JARVIS_VPN_DIR}" && -d "${JARVIS_VPN_DIR}" ]] && { echo "${JARVIS_VPN_DIR}"; return; }
  [[ -d "${HOME}/vpn" ]] && { echo "${HOME}/vpn"; return; }
  local base="${XDG_STATE_HOME:-${HOME}/.local/state}/jarvis/vpn"
  mkdir -p "${base}" 2>/dev/null
  echo "${base}"
}

_vpn__with_timeout(){
  local s="$1"; shift
  _vpn__have timeout && { timeout --preserve-status "${s}" "$@"; return; }
  "$@"
}

_vpn__dns_ok(){
  local host="${1:-${JARVIS_VPN_DNS_TEST_HOST}}" t="${2:-${JARVIS_VPN_DNS_TIMEOUT_S}}"
  _vpn__have resolvectl && _vpn__with_timeout "$t" resolvectl query "$host" >/dev/null 2>&1 && return 0
  _vpn__have getent     && _vpn__with_timeout "$t" getent hosts "$host"     >/dev/null 2>&1 && return 0
  _vpn__have dig        && _vpn__with_timeout "$t" dig +time=1 +tries=1 +short "$host" >/dev/null 2>&1 && return 0
  _vpn__have nslookup   && _vpn__with_timeout "$t" nslookup "$host"         >/dev/null 2>&1 && return 0
  _vpn__have curl       && _vpn__with_timeout "$t" curl -fsS --max-time "$t" "https://${host}/" >/dev/null 2>&1 && return 0
  return 1
}

_vpn__sanitize_name(){
  local s="${1:t}"; s="${s%.conf}"; s="${s:l}"
  s="${s// /-}"; s="${s//_/-}"; s="${s//[^a-z0-9.-]/}"
  echo "$s"
}

_vpn__strip_provider_tokens(){
  local s="$1"
  [[ "$s" == ${JARVIS_VPN_PREFIX}* ]] && s="${s#${JARVIS_VPN_PREFIX}}"
  [[ "$s" == wg-* ]]                  && s="${s#wg-}"
  local -a toks=(${=JARVIS_VPN_STRIP_TOKENS})
  local t
  for t in "${toks[@]}"; do s="${s//${t}/}"; done
  s="${s//---/-}"; s="${s//--/-}"; s="${s##-}"; s="${s%%-}"
  s="${s//[^a-z0-9.-]/}"
  [[ -z "$s" ]] && s="wg"
  echo "$s"
}

_vpn__ifname_for_base(){
  local base="$1"
  [[ "$base" == ${JARVIS_VPN_PREFIX}* ]] && { echo "$base"; return; }
  echo "${JARVIS_VPN_PREFIX}${base}"
}

_vpn__strip_dns_lines(){ sed -E 's/^[[:space:]]*DNS[[:space:]]*=.*$//'; }

_vpn__conf_list(){
  find -L "$(_vpn__dir)" -maxdepth 1 -type f -name '*.conf' -printf '%f\n' 2>/dev/null | sort
}

_vpn__resolve_conf(){
  local q="$1" dir="$(_vpn__dir)"
  local base="$(_vpn__sanitize_name "$q")"
  [[ -f "$q" ]]                  && { echo "$q";                  return; }
  [[ -f "${dir}/${q}" ]]         && { echo "${dir}/${q}";         return; }
  [[ -f "${dir}/${base}.conf" ]] && { echo "${dir}/${base}.conf"; return; }
  return 1
}

_vpn__pick_conf(){
  _vpn__have fzf || { _vpn__err "fzf not found"; return 1; }
  local dir="$(_vpn__dir)" picked
  picked="$(_vpn__conf_list | sed 's/\.conf$//' | fzf \
    --prompt="  vpn ▸ " --height=50% --reverse --border=rounded \
    --info=hidden --no-scrollbar \
    --preview="cat '${dir}/{}.conf' 2>/dev/null \
      | sed -E 's/^[[:space:]]*(Private|Preshared)Key[[:space:]]*=.*/<redacted>/' \
      | sed -E '/^[[:space:]]*DNS[[:space:]]*=/d'" \
    --preview-window=right:55%:wrap
  )" || return 1
  [[ -z "$picked" ]] && return 1
  echo "${dir}/${picked}.conf"
}

_vpn__public_ip(){
  _vpn__have curl || { echo "unknown"; return; }
  curl -fsS --max-time 4 https://ipinfo.io/ip 2>/dev/null | tr -d '[:space:]' || echo "unknown"
}

_vpn__install_quiet(){
  local conf="$1"
  local raw="$(_vpn__sanitize_name "$conf")"
  local base="$(_vpn__strip_provider_tokens "$raw")"
  local ifname="$(_vpn__ifname_for_base "$base")"
  local dst="${JARVIS_VPN_ETC_DIR}/${ifname}.conf"
  local tmp; tmp="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/vpn-${ifname}-$$.conf")"
  local sudo_cmd; sudo_cmd="$(_vpn__need_sudo)"

  $sudo_cmd mkdir -p "${JARVIS_VPN_ETC_DIR}" 2>/dev/null
  _vpn__strip_dns_lines < "$conf" > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  $sudo_cmd install -o root -g root -m 600 "$tmp" "$dst" 2>/dev/null
  local rc=$?; rm -f "$tmp"
  [[ $rc -ne 0 ]] && return 1
  echo "$ifname"
}

# ---------------------------------------------------------------------------
# Public commands
# ---------------------------------------------------------------------------
vpn.on(){
  _vpn__ui_init

  local what="$1"
  [[ -z "$what" ]] && { what="$(_vpn__pick_conf)" || { _vpn__err "no config chosen"; return 1; }; }

  local conf; conf="$(_vpn__resolve_conf "$what" 2>/dev/null)" \
    || { _vpn__err "config not found: ${what}"; return 1; }

  _vpn__dns_ok || { _vpn__err "DNS broken before connect"; return 1; }

  local ifname; ifname="$(_vpn__install_quiet "$conf")" \
    || { _vpn__err "failed to install config (permissions?)"; return 1; }

  # tear down existing tunnels silently
  local ifs; ifs="$(wg show interfaces 2>/dev/null || true)"
  if [[ -n "$ifs" ]]; then
    local sudo_cmd; sudo_cmd="$(_vpn__need_sudo)"
    local i
    for i in ${(s: :)ifs}; do
      [[ "$i" == ${JARVIS_VPN_PREFIX}* ]] && \
        $sudo_cmd wg-quick down "$i" >/dev/null 2>&1 || true
    done
  fi

  local sudo_cmd; sudo_cmd="$(_vpn__need_sudo)"
  _vpn__run "Connecting to ${ifname}…" $sudo_cmd wg-quick up "$ifname" \
    || { _vpn__err "wg-quick failed"; return 1; }

  if ! _vpn__dns_ok; then
    _vpn__err "DNS broke after connect — rolling back"
    $sudo_cmd wg-quick down "$ifname" >/dev/null 2>&1 || true
    return 1
  fi

  local ip; ip="$(_vpn__public_ip)"
  _vpn__ok "connected   ${ifname}   ${ip}"
}

vpn.off(){
  _vpn__ui_init
  local ifs; ifs="$(wg show interfaces 2>/dev/null || true)"
  [[ -z "$ifs" ]] && { _vpn__ok "already off"; return 0; }

  local sudo_cmd; sudo_cmd="$(_vpn__need_sudo)"
  local i
  for i in ${(s: :)ifs}; do
    [[ "$i" == ${JARVIS_VPN_PREFIX}* ]] && \
      _vpn__run "Disconnecting ${i}…" $sudo_cmd wg-quick down "$i" || true
  done
  _vpn__ok "disconnected"
}

vpn.status(){
  _vpn__ui_init

  local ifs; ifs="$(wg show interfaces 2>/dev/null || true)"

  if [[ -z "$ifs" ]]; then
    _vpn__note "tunnel     off"
  else
    local i
    for i in ${(s: :)ifs}; do
      local peer endpoint
      peer="$(wg show "$i" peers 2>/dev/null | head -1 | cut -c1-12)…"
      endpoint="$(wg show "$i" endpoints 2>/dev/null | awk '{print $2}' | head -1)"
      _vpn__note "tunnel     ${i}  peer ${peer}  endpoint ${endpoint}"
    done
    local ip; ip="$(_vpn__public_ip)"
    _vpn__ok "connected   ${ip}"
  fi

  print -ru2 --
  if _vpn__dns_ok; then
    _vpn__ok "dns ok"
  else
    _vpn__err "dns failed"
  fi
}

vpn.ls(){
  _vpn__ui_init
  if [ -t 2 ] && _vpn__have fzf; then
    local picked
    picked="$(_vpn__conf_list | sed 's/\.conf$//' | fzf \
      --prompt="  vpn ▸ " --height=50% --reverse --border=rounded \
      --info=hidden --no-scrollbar)" || return 1
    [[ -z "$picked" ]] && return 1
    print -r -- "$picked"
  else
    _vpn__conf_list | sed 's/\.conf$//'
  fi
}

vpn.dir(){ _vpn__ui_init; print -r -- "$(_vpn__dir)"; }

vpn.install(){
  _vpn__ui_init
  local what="$1"
  [[ -z "$what" ]] && { _vpn__err "usage: vpn install <name|path>"; return 1; }
  local conf; conf="$(_vpn__resolve_conf "$what")" || { _vpn__err "not found: $what"; return 1; }
  local ifname; ifname="$(_vpn__install_quiet "$conf")" || { _vpn__err "install failed"; return 1; }
  _vpn__ok "installed   ${ifname}"
  print -r -- "$ifname"
}

vpn.setup(){
  _vpn__ui_init
  _vpn__have apt-get || {
    _vpn__err "apt-get not found — install manually: wireguard-tools iproute2 fzf gum"
    return 1
  }
  _vpn__run "Installing packages…" \
    sudo apt-get install -y wireguard-tools iproute2 nftables curl fzf \
    || { _vpn__err "apt-get failed"; return 1; }
  _vpn__ok "packages installed"
  _vpn__note "configs    $(_vpn__dir)"
  _vpn__note "gum        https://github.com/charmbracelet/gum/releases"
}

vpn.help(){
  _vpn__ui_init
  print -ru2 -- ""
  print -ru2 -- "  vpn                 interactive picker"
  print -ru2 -- "  vpn on [name]       connect"
  print -ru2 -- "  vpn off             disconnect"
  print -ru2 -- "  vpn st              status + public ip"
  print -ru2 -- "  vpn ls              list configs"
  print -ru2 -- "  vpn dir             config directory"
  print -ru2 -- "  vpn install <name>  install config only"
  print -ru2 -- "  vpn setup           install system deps"
  print -ru2 -- ""
}

vpn(){
  _vpn__ui_init
  local cmd="${1:-}"; shift 2>/dev/null || true
  case "$cmd" in
    "")
      _vpn__have fzf || { _vpn__err "fzf missing"; return 1; }
      local action
      action=$(printf "%s\n" on off status ls dir setup help \
        | fzf --prompt="  vpn ▸ " --height=50% --reverse \
              --border=rounded --info=hidden --no-scrollbar) || return 1
      case "$action" in
        on)     vpn.on ;;
        off)    vpn.off ;;
        status) vpn.status ;;
        ls)     vpn.ls ;;
        dir)    vpn.dir ;;
        setup)  vpn.setup ;;
        help)   vpn.help ;;
      esac
      ;;
    on|up|connect)  vpn.on "$@" ;;
    sw|switch)      vpn.on "$@" ;;
    off|down)       vpn.off ;;
    st|status)      vpn.status ;;
    ls|list)        vpn.ls ;;
    dir)            vpn.dir ;;
    install)        vpn.install "$@" ;;
    setup)          vpn.setup ;;
    help|-h|--help) vpn.help ;;
    *)              vpn.on "$cmd" "$@" ;;
  esac
}

_vpn__comp(){
  local -a names
  names=("${(@f)$(_vpn__conf_list 2>/dev/null | sed 's/\.conf$//')}")
  _describe 'vpn configs' names
}
compdef _vpn__comp vpn
