_OSYX_THEME_ROOT="${${(%):-%x}:A:h}"

_OSYX_RELOAD_FILE="${_OSYX_RELOAD_FILE:-$HOME/.cache/zsh-reload-trigger}"
_OSYX_LOG_FILE="${_OSYX_LOG_FILE:-$HOME/.cache/osyx.log}"
_OSYX_PALETTES_DIR="${_OSYX_PALETTES_DIR:-$HOME/flavors/palettes}"
_OSYX_BACKGROUNDS_DIR="${_OSYX_BACKGROUNDS_DIR:-$HOME/flavors/backgrounds}"
_OSYX_GENERATE_SCRIPT="${_OSYX_GENERATE_SCRIPT:-$HOME/flavors/generate.py}"
_OSYX_STATE_FILE="${_OSYX_STATE_FILE:-$HOME/.cache/theme.current}"

_OSYX_THYX_DIR="${_OSYX_THYX_DIR:-/usr/share/sddm/themes/thyx}"
_OSYX_THYX_THEME_CONF="${_OSYX_THYX_THEME_CONF:-$_OSYX_THYX_DIR/theme.conf}"
_OSYX_THYX_PRESETS_DIR="${_OSYX_THYX_PRESETS_DIR:-$_OSYX_THYX_DIR/presets}"
_OSYX_THYX_FALLBACK="${_OSYX_THYX_FALLBACK:-cinder}"

_osyx_log() {
  mkdir -p "${_OSYX_LOG_FILE:h}"
  print -r -- "[$(date '+%H:%M:%S')] $*" >> "$_OSYX_LOG_FILE"
}

_osyx_apply_dircolors() {
  local context="${1:-shell}"

  eval "$(dircolors "$HOME/.dircolors" 2>/dev/null)" \
    || _osyx_log "dircolors not available in $context, skipping"
}

TRAPUSR1() {
  _osyx_apply_dircolors "TRAPUSR1"

  if [[ -o zle ]]; then
    zle -I 2>/dev/null || true
    clear
    zle reset-prompt 2>/dev/null || true
  fi

  return 0
}

_osyx_autoreload() {
  [[ -f "$_OSYX_RELOAD_FILE" ]] || return 0

  local stamp
  stamp=$(<"$_OSYX_RELOAD_FILE")
  [[ "$stamp" == "${_OSYX_LAST_RELOAD:-}" ]] && return 0

  _OSYX_LAST_RELOAD="$stamp"
  _osyx_apply_dircolors "autoreload"

  if [[ -o zle ]]; then
    zle reset-prompt 2>/dev/null || true
  else
    clear
  fi
}

_osyx_register_autoreload() {
  typeset -ga precmd_functions

  [[ -n "${precmd_functions[(re)_osyx_autoreload]}" ]] && return 0
  precmd_functions+=(_osyx_autoreload)
}

_osyx_signal_theme_pid() {
  local pid="$1"

  [[ "$pid" == <-> ]] || return 0
  [[ "$pid" == "$$" ]] && return 0

  kill -0 "$pid" 2>/dev/null || return 0
  kill -USR1 "$pid" 2>/dev/null || true
}

_osyx_signal_idle_zsh() {
  command -v ps >/dev/null 2>&1 || return 0

  ps -u "$USER" -o pid= -o pgid= -o tpgid= -o tty= -o comm= 2>/dev/null \
    | while read -r pid pgid tpgid tty comm; do
        [[ "$tty" != "?" ]] || continue
        [[ "$pgid" == "$tpgid" ]] || continue
        [[ "$comm" == "zsh" || "$comm" == "-zsh" ]] || continue

        _osyx_signal_theme_pid "$pid"
      done
}

_osyx_reload_all() {
  mkdir -p "${_OSYX_RELOAD_FILE:h}"
  print -r -- "$(date +%s%N)" >| "$_OSYX_RELOAD_FILE"

  _osyx_signal_idle_zsh
}

_osyx_theme_list() {
  local f basename

  [[ -d "$_OSYX_PALETTES_DIR" ]] || return 1

  for f in "$_OSYX_PALETTES_DIR"/*.toml(N); do
    basename="${f##*/}"
    print -r -- "${basename%%.toml}"
  done
}

_osyx_current_theme() {
  [[ -f "$_OSYX_STATE_FILE" ]] || return 1

  local current
  current=$(<"$_OSYX_STATE_FILE")
  [[ -n "$current" ]] || return 1

  print -r -- "$current"
}

_osyx_next_theme() {
  local current="$1"
  shift

  local -a themes=("$@")
  local i count=${#themes[@]}

  for (( i = 1; i <= count; i++ )); do
    if [[ "${themes[i]}" == "$current" ]]; then
      print -r -- "${themes[$(( i % count + 1 ))]}"
      return 0
    fi
  done

  print -r -- "${themes[1]}"
}

_osyx_choose_theme() {
  local mode="$1"
  local -a themes=("${(@f)$(_osyx_theme_list)}")

  if (( ${#themes[@]} == 0 )); then
    print -ru2 -- "no palettes found in $_OSYX_PALETTES_DIR"
    return 1
  fi

  if [[ "$mode" == "rotate" ]]; then
    _osyx_next_theme "$(_osyx_current_theme 2>/dev/null)" "${themes[@]}"
    return $?
  fi

  if [[ -n "$mode" ]]; then
    if [[ -f "$_OSYX_PALETTES_DIR/$mode.toml" ]]; then
      print -r -- "$mode"
      return 0
    fi

    print -ru2 -- "theme not found: $mode"
    return 1
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    print -ru2 -- "fzf not found."
    return 1
  fi

  printf '%s\n' "${themes[@]}" | fzf --prompt='theme > ' --height=40%
}

_osyx_generate_theme_files() {
  local theme="$1"

  if [[ ! -f "$_OSYX_GENERATE_SCRIPT" ]]; then
    _osyx_log "generate.py not found, skipping"
    return 0
  fi

  python3 "$_OSYX_GENERATE_SCRIPT" "$theme" >/dev/null 2>&1 \
    || _osyx_log "generate.py failed for $theme"
}

_osyx_write_theme_state() {
  mkdir -p "${_OSYX_STATE_FILE:h}" 2>/dev/null
  print -r -- "$1" >| "$_OSYX_STATE_FILE" 2>/dev/null || true
}

_osyx_reload_kitty() {
  command -v pgrep >/dev/null 2>&1 || return 0

  local pid
  for pid in ${(f)"$(pgrep -u "$USER" -x kitty 2>/dev/null)"}; do
    kill -USR1 "$pid" 2>/dev/null || true
  done
}

_osyx_reload_tmux() {
  if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1 \
      || _osyx_log "tmux source failed"
  else
    _osyx_log "tmux not running, skipping"
  fi
}

_osyx_reload_hyprland() {
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || _osyx_log "hyprctl reload failed"
  else
    _osyx_log "hyprctl not found, skipping"
  fi
}

_osyx_reload_mako() {
  if command -v makoctl >/dev/null 2>&1; then
    makoctl reload >/dev/null 2>&1 || _osyx_log "makoctl reload failed"
  else
    pkill -x mako >/dev/null 2>&1 || true
    (mako >/dev/null 2>&1 & disown) >/dev/null 2>&1 \
      || _osyx_log "mako not found, skipping"
  fi
}

_osyx_reload_nvim() {
  if ! command -v nvim >/dev/null 2>&1; then
    _osyx_log "nvim not found, skipping"
    return 0
  fi

  local sock
  for sock in \
    /run/user/$(id -u)/nvim.*.0 \
    /tmp/nvim.${USER}/**/nvim.*.0(N); do
    [[ -S "$sock" ]] || continue
    nvim --server "$sock" --remote-send '<Cmd>OsyxFlip<CR>' >/dev/null 2>&1 \
      || _osyx_log "nvim socket $sock unreachable, skipping"
  done
}

_osyx_wallpaper_file() {
  local theme="$1"
  local ext

  for ext in jpg png jpeg webp; do
    if [[ -f "$_OSYX_BACKGROUNDS_DIR/$theme.$ext" ]]; then
      print -r -- "$_OSYX_BACKGROUNDS_DIR/$theme.$ext"
      return 0
    fi
  done

  return 1
}

_osyx_apply_wallpaper() {
  local theme="$1"
  local wallpaper_file

  wallpaper_file="$(_osyx_wallpaper_file "$theme")" || {
    _osyx_log "no wallpaper found for $theme, skipping"
    return 0
  }

  if command -v wallpaper >/dev/null 2>&1; then
    wallpaper set "$wallpaper_file" >/dev/null 2>&1 \
      || _osyx_log "wallpaper set failed for $wallpaper_file"
  elif command -v waypaper >/dev/null 2>&1; then
    waypaper --wallpaper "$wallpaper_file" >/dev/null 2>&1 \
      || _osyx_log "waypaper failed for $wallpaper_file"
  else
    _osyx_log "no wallpaper tool found, skipping"
  fi
}

_osyx_apply_thyx() {
  local theme="$1"

  [[ -d "$_OSYX_THYX_DIR" ]] || return 0

  if [[ -f "$_OSYX_THYX_PRESETS_DIR/$theme.conf" ]]; then
    cp -- "$_OSYX_THYX_PRESETS_DIR/$theme.conf" "$_OSYX_THYX_THEME_CONF"
  else
    cp -- "$_OSYX_THYX_PRESETS_DIR/$_OSYX_THYX_FALLBACK.conf" "$_OSYX_THYX_THEME_CONF"
  fi
}

_osyx_apply_theme() {
  local theme="$1"

  _osyx_generate_theme_files "$theme"
  _osyx_write_theme_state "$theme"
  _osyx_apply_thyx "$theme"

  _osyx_reload_kitty &!
  _osyx_reload_hyprland &!
  _osyx_reload_mako &!
  _osyx_apply_wallpaper "$theme" &!
  _osyx_reload_tmux &!
  _osyx_reload_nvim &!

  _osyx_reload_all
}

themes() {
  local choice

  choice="$(_osyx_choose_theme "${1:-}")" || return 1
  _osyx_apply_theme "$choice"
  clear
}

_osyx_apply_dircolors "init"
_osyx_register_autoreload
