# shows pretty `man` page.
man () {
  env \
    LESS_TERMCAP_mb=$(printf "\e[1;31m") \
    LESS_TERMCAP_md=$(printf "\e[1;31m") \
    LESS_TERMCAP_me=$(printf "\e[0m") \
    LESS_TERMCAP_se=$(printf "\e[0m") \
    LESS_TERMCAP_so=$(printf "\e[1;44;33m") \
    LESS_TERMCAP_ue=$(printf "\e[0m") \
    LESS_TERMCAP_us=$(printf "\e[1;32m") \
      man "$@"
}

remindme() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: remindme <seconds> <message>"
    return 1
  fi
  (sleep "$1" && echo "Reminder: $2") &
}

# rerun last command with sudo
please() {
  sudo $(fc -ln -1)
}

# counts the lines of code in your current codebase
# needs pnpm
loc() {
  local dir="${1:-.}"
  pnpm dlx cloc "$dir" \
    --exclude-dir='node_modules,dist,out,.next,build,.turbo,.vercel,.git,.venv,__pycache__,target,vendor' \
    --not-match-f='.*lock|.*min.js|.*.svg|.*.map|.*.log'
}

precmd() {
    # Print the previously configured title
    print -Pnr -- "$TERM_TITLE"

    # Print a new line before the prompt, but only if it is not the first line
    if [ "$NEWLINE_BEFORE_PROMPT" = yes ]; then
        if [ -z "$_NEW_LINE_BEFORE_PROMPT" ]; then
            _NEW_LINE_BEFORE_PROMPT=1
        else
            print ""
        fi
    fi
}

