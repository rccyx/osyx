browser() {
  local browsers
  # Added opera to the list below
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

  # This kicks it off into the background so it doesn't hang your terminal
  nohup "$choice" >/dev/null 2>&1 &
}
