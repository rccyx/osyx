app() {
  emulate -L zsh
  setopt localoptions err_return no_unset

  local browser brave profile target sel key
  browser=$(command -v google-chrome-stable || command -v google-chrome || command -v chromium || true)
  brave=$(command -v brave-browser || command -v brave || true)
  if [[ -z ${browser-} && -z ${brave-} ]]; then
    print -P "%F{red}Neither Chrome nor Brave found%f"
    return 1
  fi

  profile=${WEBAPP_PROFILE:-Default}
  typeset -gA WEBAPPS
  WEBAPPS=(
    gcal        https://calendar.google.com
    calendar    https://calendar.google.com
    chatgpt     https://chatgpt.com
    cc          https://chatgpt.com
    claude      https://claude.ai
    cl          https://claude.ai
    x           https://x.com
    twitter     https://x.com
    mail        https://www.icloud.com/mail
    photos      https://www.icloud.com/photos
    notes       https://www.icloud.com/notes
    soundcloud https://soundcloud.com
    sc          https://soundcloud.com
    facebook    https://facebook.com
    fb          https://facebook.com
    fbads       "https://www.facebook.com/ads/library/?active_status=active&ad_type=all&country=US&media_type=all"
    ads         "https://www.facebook.com/ads/library/?active_status=active&ad_type=all&country=US&media_type=all"
    instagram   https://instagram.com
    ig          https://instagram.com
    grok        https://grok.com
    github      https://github.com/rccyx
    gh          https://github.com/rccyx
    whatsapp    https://web.whatsapp.com
    wh          https://web.whatsapp.com
    telegram    https://web.telegram.org
    tg          https://web.telegram.org
    discord     https://discord.com/app
    dc          https://discord.com/app
    maps        https://maps.google.com
    translate   https://translate.google.com
    tr          https://translate.google.com
    gemini      https://gemini.google.com
    gm          https://gemini.google.com
    youtube     https://youtube.com
    yt          https://youtube.com
  )

  if [[ -n ${1-} ]]; then
    target=$1
    [[ -n ${WEBAPPS[$target]-} ]] && target=${WEBAPPS[$target]}
  else
    if command -v fzf >/dev/null 2>&1 && [[ -t 0 || -t 1 ]]; then
      local -a keys; keys=(${(ok)WEBAPPS})
      sel=$(
        for k in "${keys[@]}"; do
          printf "%-12s %s\n" "$k" "${WEBAPPS[$k]}"
        done | fzf --prompt="app> " --height=40% --border --reverse
      )
      [[ -z ${sel-} ]] && return 1
      key=${sel%%[[:space:]]*}
      target=${WEBAPPS[$key]}
    else
      print -P "%F{yellow}No TTY for fzf. Run from a terminal, or bind your key to launch a terminal (e.g. kitty -e zsh -ic app).%f"
      return 1
    fi
  fi

  if [[ ${target} != http*://* ]]; then
    print -P "%F{red}Invalid or unknown app:%f ${target}"
    return 1
  fi

  if [[ -z ${WEBAPP_PROFILE-} ]]; then
    if [[ ${target} == https://chatgpt.com* ]]; then
      profile="Profile 4"
    elif [[ ${target} == https://gemini.google.com* ||  ${target} == https://claude.ai*  ]]; then
      profile="Profile 3"
    elif [[ ${target} == https://web.telegram.org* || ${target} == https://www.icloud.com* ]]; then
      profile="Profile 2"
    fi
  fi

  local cmd
  if [[ ${target} == https://youtube.com* ]]; then
    cmd=$brave
  else
    cmd=$browser
  fi

  if command -v setsid >/dev/null 2>&1; then
    setsid -f "$cmd" --profile-directory="$profile" --app="$target" --new-window >/dev/null 2>&1
  else
    nohup "$cmd" --profile-directory="$profile" --app="$target" --new-window >/dev/null 2>&1 &
  fi
}

