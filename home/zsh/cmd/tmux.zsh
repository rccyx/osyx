# kill all tmux sessions
txkill() {
  tmux list-sessions -F '#S' 2>/dev/null | xargs -r -I {} tmux kill-session -t {}
}

# pick a clipboard sink that works on Wayland or X11
__cop_pick_sink() {
  if [ -n "$TERM" ] && [[ "$TERM" == *kitty* ]] && command -v kitty >/dev/null 2>&1; then
    COPY_CMD=(kitty +kitten clipboard)
  elif command -v wl-copy >/dev/null 2>&1 && [ -n "${WAYLAND_DISPLAY:-}" ]; then
    COPY_CMD=(wl-copy)
  elif command -v xclip >/dev/null 2>&1; then
    COPY_CMD=(xclip -selection clipboard)
  elif command -v xsel >/dev/null 2>&1; then
    COPY_CMD=(xsel --clipboard --input)
  else
    COPY_CMD=()
  fi
}

# ensure Debian deps if missing
__cop_ensure_deps() {
  local need=()
  command -v tmux >/dev/null 2>&1 || need+=(tmux)
  command -v kitty >/dev/null 2>&1 || need+=(kitty)
  command -v wl-copy >/dev/null 2>&1 || need+=(wl-clipboard)
  command -v xclip >/dev/null 2>&1 || need+=(xclip)

  if (( ${#need[@]} )); then
    if command -v apt-get >/dev/null 2>&1; then
      echo "[cop] installing: ${need[*]} (sudo)"
      sudo apt-get update -y && sudo apt-get install -y "${need[@]}"
    fi
  fi
}

# check if Kitty remote control is available in this window
__kitty_rc_ok() {
  [ -n "${KITTY_WINDOW_ID:-}" ] || return 1
  command -v kitty >/dev/null 2>&1 || return 1
  kitty @ ls >/dev/null 2>&1
}

# copy last N lines
# inside tmux: pane scrollback
# in Kitty outside tmux: visible screen via kitty @ get-text
# else: last N zsh commands as a fallback
cop() {
  local n=${1:-700}
  local max_lines=10000
  (( n > max_lines )) && n=$max_lines

  __cop_ensure_deps
  __cop_pick_sink
  if (( ${#COPY_CMD[@]} == 0 )); then
    echo -e "\e[1;31mNo clipboard tool. Install wl-clipboard or xclip.\e[0m"
    return 1
  fi

  if [ -n "$TMUX" ]; then
    tmux capture-pane -pS -"$n" \
      | sed -r 's/\x1B\[[0-9;]*[mK]//g' \
      | "${COPY_CMD[@]}"
    echo -e "\e[1;32mCopied $n lines from tmux pane.\e[0m"
    return
  fi

  # Kitty outside tmux
  if __kitty_rc_ok; then
    kitty @ get-text --match state:focused --extent screen 2>/dev/null \
      | tail -n "$n" \
      | "${COPY_CMD[@]}"
    echo -e "\e[1;32mCopied $n lines from Kitty screen.\e[0m"
    return
  fi

  # fallback: last N commands
  local histfile=${HISTFILE:-$HOME/.zsh_history}
  if [[ -f $histfile ]]; then
    tail -n "$n" "$histfile" | sed 's/^: [0-9]*:[0-9]*;//' | "${COPY_CMD[@]}"
    echo -e "\e[1;33mKitty remote control is off. Copied last $n zsh commands.\e[0m"
    echo -e "\e[1;34mTip:\e[0m add the two lines below to enable screen copy in Kitty:"
    echo -e "  \e[1mmkdir -p ~/.config/kitty && { grep -q '^allow_remote_control' ~/.config/kitty/kitty.conf 2>/dev/null || echo 'allow_remote_control yes' >> ~/.config/kitty/kitty.conf; }\e[0m"
    echo -e "  \e[1m{ grep -q '^listen_on' ~/.config/kitty/kitty.conf 2>/dev/null || echo 'listen_on unix:@kitty' >> ~/.config/kitty/kitty.conf; }\e[0m"
    echo -e "Restart Kitty once. Then cop will grab the visible screen."
    return
  fi

  echo -e "\e[1;31mNo source to copy from.\e[0m"
  return 1
}

