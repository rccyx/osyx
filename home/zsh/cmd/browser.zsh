browser() {
  local browsers
  browsers=$(printf "%s\n" \
    opera \
    firefox \
    librewolf \
    floorp \
    mullvad-browser \
    tor-browser \
    brave-browser \
    google-chrome-stable \
    google-chrome \
    chromium \
    vivaldi \
    qutebrowser \
    zen-browser \
    | while read -r b; do
        command -v "$b" >/dev/null 2>&1 && echo "$b"
      done)

  [ -z "$browsers" ] && { echo "no browsers found"; return 1; }

  local choice
  choice=$(echo "$browsers" | fzf --prompt="browser ▸ " --height=40% --reverse)

  [ -z "$choice" ] && return

  # Launch in a new session, redirect all output, and remove from shell job control
  setsid -f "$choice" </dev/null >/dev/null 2>&1 || {
    nohup "$choice" </dev/null >/dev/null 2>&1 &
    disown
  }
}