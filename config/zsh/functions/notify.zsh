#   notify                          # fzf picker -> prompt for message
#   notify --minutes 8 --message 'grab eggs'
#   notify -m 45 -M "check oven"
#   notify 3 "do some"              # positional

notify() {
  emulate -L zsh
  setopt localoptions errexit nounset pipefail

  # deps
  local NOTIFY
  if ! NOTIFY="$(command -v notify-send)"; then
    print "notify-send not found. Install libnotify-bin."
    return 1
  fi
  local have_fzf=0
  command -v fzf >/dev/null && have_fzf=1

  # args
  local cli_minutes="" cli_msg=""
  while (( $# )); do
    case "$1" in
      --minutes|-m) shift; cli_minutes="${1:-}"; shift || true ;;
      --message|-M) shift; cli_msg="${1:-}"; shift || true ;;
      --help|-h)
        cat <<'__H__'
notify:
  notify                 -> pick delay with fzf, then enter message
  notify -m 3 -M "grab food"
  notify 45 "drink water"

Rules:
  - Exact minutes supported for 0..30
  - > 30 minutes rounds up to nearest 15

Behavior:
  - Sends critical, sticky notification (click to dismiss)
  - Body is "{message} - {HH:MM}" at fire-time
__H__
        return 0
        ;;
      '')
        shift
        ;;
      *)
        if [[ -z "$cli_minutes" && "$1" == <-> ]]; then
          cli_minutes="$1"; shift
          [[ $# -gt 0 ]] && cli_msg="$*"
          break
        else
          cli_msg="${cli_msg:+$cli_msg }$1"; shift
        fi
        ;;
    esac
  done

  # picker if minutes not provided
  local mins choice
  if [[ -z "${cli_minutes:-}" ]]; then
    if (( have_fzf )); then
      local -a opts
      local i h m label
      for (( i=0; i<=30; i++ )); do
        label=$(( i==0 ? 0 : i ))" min"
        (( i==0 )) && label="now"
        opts+=("${i}|${label}")
      done
      for (( i=45; i<=720; i+=15 )); do
        h=$(( i/60 )); m=$(( i%60 ))
        if (( h == 0 )); then
          label="${i} min"
        else
          label="${h} h"; (( m )) && label="${label} ${m} min"
        fi
        opts+=("${i}|${label}")
      done
      choice=$(printf "%s\n" "${opts[@]}" | sed 's/|/ -> /' \
        | fzf --prompt="Remind in: " --height=40% --reverse --ansi) || return 1
      mins=$(printf "%s" "$choice" | awk '{print $1}')
    else
      print "fzf not found. Enter minutes (0..720)."
      read -r "mins?Minutes: " || return 1
    fi
  else
    mins="${cli_minutes}"
  fi

  # sanitize minutes: allow exact 0..30, else round up to nearest 15
  if ! [[ "$mins" == <-> ]]; then
    print "Invalid minutes: $mins"; return 1
  fi
  (( mins < 0 )) && mins=0
  (( mins > 720 )) && mins=720
  if (( mins > 30 )); then
    mins=$(( ((mins + 14) / 15) * 15 ))
  fi

  # message
  local msg title="Reminder"
  if [[ -n "${cli_msg:-}" ]]; then
    msg="$cli_msg"
  else
    vared -p "Reminder message: " -c msg
    [[ -z "$msg" ]] && msg="Time to focus"
  fi

  # cache dir and tiny fire-time script to avoid quoting issues
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/notify"
  mkdir -p "$cache_dir"
  local jid ts_now msg_file script_file
  jid="$(date +%s)-$RANDOM"
  msg_file="$cache_dir/$jid.msg"
  script_file="$cache_dir/$jid.sh"
  print -r -- "$msg" > "$msg_file"

  # script computes occurrence timestamp at send-time
  cat > "$script_file" <<'__SCRIPT__'
#!/usr/bin/env bash
set -euo pipefail
MSG_FILE="$1"
NOTIFY_BIN="${2:-notify-send}"

WHEN="$(date '+%H:%M')"   # 24-hour HH:MM
MSG="$(cat "$MSG_FILE")"

exec "$NOTIFY_BIN" \
  -u critical \
  -t 0 \
  --app-name=reminder \
  --hint=string:category:reminder \
  --hint=boolean:resident:true \
  "Reminder" \
  "${MSG} - ${WHEN}"
__SCRIPT__
  chmod +x "$script_file"

  # log to shell (plain)
  ts_now="$(date '+%H:%M:%S')"
  if (( mins == 0 )); then
    print "[notify] $ts_now -> sending now : $msg"
  else
    print "[notify] $ts_now -> scheduled in $mins min : $msg"
  fi

  # run now or schedule
  if (( mins == 0 )); then
    "$script_file" "$msg_file" "$NOTIFY" >/dev/null 2>&1
  else
    if command -v systemd-run >/dev/null; then
      systemd-run --user --quiet \
        --unit="notify-$jid" \
        --timer-property=AccuracySec=1s \
        --on-active="${mins}m" \
        "$script_file" "$msg_file" "$NOTIFY"
    else
      nohup bash -lc "sleep $((mins*60)); exec '$script_file' '$msg_file' '$NOTIFY'" \
        >/dev/null 2>&1 & disown
    fi
  fi

  print "Reminder set."
}

