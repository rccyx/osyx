_have(){ command -v "$1" >/dev/null 2>&1; }
_err(){ print -P "%F{1}❌ $1%f" >&2; }
_ok(){  print -P "%F{2}$1%f"; }

# Detect session backend
_session(){
  if [[ -n ${WAYLAND_DISPLAY:-} || ${XDG_SESSION_TYPE:-} == wayland ]]; then
    printf "wayland"
  elif [[ -n ${DISPLAY:-} ]]; then
    printf "x11"
  else
    printf "none"
  fi
}

# OSC52 copy to terminal, works even over SSH and inside tmux
_osc52_copy(){
  local data b64 esc="\x1b" bel="\x07"
  data="$(cat)"
  if (( ${#data} > 1048576 )); then _err "OSC52 payload too large (>1 MB)"; return 1; fi
  b64="$(printf "%s" "$data" | base64 | tr -d '\r\n')"
  if [[ -n ${TMUX:-} ]]; then
    printf "${esc}Ptmux;${esc}]52;c;%s${bel}${esc}\\" "$b64"
  else
    printf "${esc}]52;c;%s${bel}" "$b64"
  fi
}

# Write to clipboard. Reads stdin. Optional: set CLIP_BACKEND=wl|x|xsel|osc52 to force.
_clip(){
  local be="${CLIP_BACKEND:-$(_session)}"
  case "$be" in
    wl|wayland)
      if _have wl-copy; then wl-copy "$@"; return; fi
      ;;
    x|x11)
      if _have xclip; then xclip -selection clipboard "$@"; return; fi
      if _have xsel;  then xsel --clipboard "$@"; return; fi
      ;;
    xsel)
      if _have xsel;  then xsel --clipboard "$@"; return; fi
      ;;
    osc52)
      _osc52_copy; return
      ;;
  esac

  case "$(_session)" in
    wayland)
      if _have wl-copy; then wl-copy "$@"; return; fi
      if _have xclip;   then xclip -selection clipboard "$@"; return; fi
      if _have xsel;    then xsel --clipboard "$@"; return; fi
      ;;
    x11)
      if _have xclip;   then xclip -selection clipboard "$@"; return; fi
      if _have xsel;    then xsel --clipboard "$@"; return; fi
      ;;
    none)
      _osc52_copy; return
      ;;
  esac

  _osc52_copy
}

# Read from clipboard to stdout
_paste(){
  local be="${CLIP_BACKEND:-$(_session)}"
  case "$be" in
    wl|wayland)
      if _have wl-paste; then wl-paste "$@"; return; fi
      ;;
    x|x11)
      if _have xclip; then xclip -selection clipboard -o "$@"; return; fi
      if _have xsel;  then xsel --clipboard -o "$@"; return; fi
      ;;
    xsel)
      if _have xsel;  then xsel --clipboard -o "$@"; return; fi
      ;;
    osc52)
      _err "paste via OSC52 is not possible"; return 1
      ;;
  esac

  case "$(_session)" in
    wayland)
      if _have wl-paste; then wl-paste "$@"; return; fi
      if _have xclip;    then xclip -selection clipboard -o "$@"; return; fi
      if _have xsel;     then xsel --clipboard -o "$@"; return; fi
      ;;
    x11)
      if _have xclip;    then xclip -selection clipboard -o "$@"; return; fi
      if _have xsel;     then xsel --clipboard -o "$@"; return; fi
      ;;
    none)
      _err "no GUI clipboard in this session"; return 1
      ;;
  esac

  _err "no clipboard tool found. install wl-clipboard or xclip"
  return 1
}
# create a new directory & cd into it
mdd () { mkdir -p "$@" && cd "$@"; }

# Copy picked files to clipboard
cpf() {
  local -a picks; local max_mb=10
  if (( $# )); then picks=("$@")
  else
    _have fzf || { _err "fzf not found, pass a file path"; return 1 }
    local finder; _have fd && finder="fd -t f --hidden --exclude .git ." || finder="find . -type f -not -path '*/\.git/*'"
    picks=("${(@f)$(eval "$finder" | fzf --multi --height 60% --border --reverse \
      --prompt='📋 pick file ⇢ ' \
      --preview 'command -v bat >/dev/null && bat --style=numbers --color=always --line-range :300 {} || head -n 300 {}')}")
    [[ -z $picks ]] && _err "cancelled" && return 1
  fi

  for f in "${picks[@]}"; do [[ -f $f ]] || { _err "'$f' is not a regular file"; return 1; } done
  local total_bytes=$(du -cb "${picks[@]}" | tail -1 | awk '{print $1}')
  if (( total_bytes > max_mb*1024*1024 )); then
    read -q "REPLY?⚠️ ${total_bytes} bytes > ${max_mb} MB, copy anyway? [y/N] "; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { _err "aborted"; return 1; }
  fi

  cat "${picks[@]}" | _clip || return 1
  _ok "copied ${#picks[@]} file(s) to clipboard (${total_bytes} bytes)"
}

# copy stdout of any command to clipboard
ccmd(){ eval "$@" | _clip; }
