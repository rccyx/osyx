audio.in(){ _audio__select source "${1:-}"; }
audio.asr(){ audio.in "$@"; }
audio.mic(){ audio.in "$@"; }
audio.out(){ _audio__select sink "${1:-}"; }

audio.pod(){
  _audio__select_matching source 'vocaster|focusrite|scarlett|clarett|usb|rode|shure|pod'
}

audio.machine(){
  _audio__select_matching source 'alsa_input\.pci|alsa_input\.platform|sof|hda|built.?in|internal'
}

audio.speakers(){
  _audio__select_matching sink 'alsa_output\.pci|alsa_output\.platform|sof|hda|speaker|built.?in|internal|analog-stereo'
}

audio.headphones(){
  _audio__select_matching sink 'headphone|headset|bluetooth|bluez|usb|hdmi'
}

audio.mute.in(){
  emulate -L zsh; setopt pipefail
  _audio__need pactl || return 1
  pactl set-source-mute @DEFAULT_SOURCE@ toggle && _audio__ok "input mute toggled" || _audio__err "input mute failed"
}

audio.mute.out(){
  emulate -L zsh; setopt pipefail
  _audio__need pactl || return 1
  pactl set-sink-mute @DEFAULT_SINK@ toggle && _audio__ok "output mute toggled" || _audio__err "output mute failed"
}

audio.vol(){
  emulate -L zsh; setopt pipefail
  _audio__need pactl || return 1
  local v="${1:-}"
  if [[ -z "$v" ]]; then
    _audio__need fzf || return 1
    v="$(printf "%s\n" 5%- 5%+ 10%- 10%+ 25% 50% 75% 100% 125% 150% | fzf \
      --prompt="  output volume ▸ " --height=40% --reverse --border=rounded \
      --info=hidden --no-scrollbar)" || return 1
  fi
  [[ -z "$v" ]] && return 1
  pactl set-sink-volume @DEFAULT_SINK@ "$v" && _audio__ok "output volume ${v}" || _audio__err "volume failed"
}

audio.micvol(){
  emulate -L zsh; setopt pipefail
  _audio__need pactl || return 1
  local v="${1:-}"
  if [[ -z "$v" ]]; then
    _audio__need fzf || return 1
    v="$(printf "%s\n" 5%- 5%+ 10%- 10%+ 50% 75% 100% 125% 150% | fzf \
      --prompt="  input volume ▸ " --height=40% --reverse --border=rounded \
      --info=hidden --no-scrollbar)" || return 1
  fi
  [[ -z "$v" ]] && return 1
  pactl set-source-volume @DEFAULT_SOURCE@ "$v" && _audio__ok "input volume ${v}" || _audio__err "input volume failed"
}

audio.streams(){
  emulate -L zsh; setopt pipefail
  _audio__need pactl || return 1

  print -ru2 -- ""
  _audio__note "capture streams"
  local in_rows; in_rows="$(_audio__stream_rows_in)"
  if [[ -z "$in_rows" ]]; then
    print -ru2 -- "  none"
  else
    print -r -- "$in_rows" | awk -F '\t' '{ printf "  %-6s source=%-8s client=%s\n", $1, $2, $3 }' >&2
  fi

  print -ru2 -- ""
  _audio__note "playback streams"
  local out_rows; out_rows="$(_audio__stream_rows_out)"
  if [[ -z "$out_rows" ]]; then
    print -ru2 -- "  none"
  else
    print -r -- "$out_rows" | awk -F '\t' '{ printf "  %-6s sink=%-8s client=%s\n", $1, $2, $3 }' >&2
  fi
}

audio.ls(){
  emulate -L zsh; setopt pipefail
  _audio__need pactl || return 1

  print -ru2 -- ""
  _audio__note "inputs"
  _audio__source_rows | awk -F '\t' '{ printf "  %s  %-6s %s\n", $1, $3, $2 }' >&2

  print -ru2 -- ""
  _audio__note "outputs"
  _audio__sink_rows | awk -F '\t' '{ printf "  %s  %-6s %s\n", $1, $3, $2 }' >&2
}

audio.tree(){
  emulate -L zsh; setopt pipefail
  _audio__need wpctl || return 1
  wpctl status --name
}

audio.status(){
  emulate -L zsh; setopt pipefail
  _audio__need pactl || return 1

  local src sink
  src="$(_audio__default_source)"
  sink="$(_audio__default_sink)"

  print -ru2 -- ""
  _audio__note "input      ${src:-unknown}"
  _audio__note "output     ${sink:-unknown}"

  print -ru2 -- ""
  _audio__note "active streams"
  local cap play
  cap="$(_audio__stream_rows_in | sed '/^[[:space:]]*$/d' | wc -l | tr -d '[:space:]')"
  play="$(_audio__stream_rows_out | sed '/^[[:space:]]*$/d' | wc -l | tr -d '[:space:]')"
  print -ru2 -- "  capture   ${cap}"
  print -ru2 -- "  playback  ${play}"

  print -ru2 -- ""
  _audio__note "quick graph"
  pactl info 2>/dev/null | awk -F ': ' '/Server Name|Default Sink|Default Source/ { printf "  %-16s %s\n", $1, $2 }' >&2
}

audio.test(){
  emulate -L zsh; setopt pipefail
  _audio__need pw-record || return 1

  local seconds="${1:-5}"
  local dir="${XDG_RUNTIME_DIR:-/tmp}/jarvis-audio-${UID}"
  mkdir -p "$dir" 2>/dev/null || return 1
  local out="${dir}/mic-test-$(date +'%Y-%m-%d_%H-%M-%S').wav"

  _audio__note "recording default input for ${seconds}s"
  if _audio__have timeout; then
    timeout --preserve-status "$seconds" pw-record "$out" >/dev/null 2>&1 || true
  else
    pw-record "$out" >/dev/null 2>&1 &!
    local pid=$!
    sleep "$seconds"
    kill -TERM "$pid" 2>/dev/null || true
  fi

  [[ -s "$out" ]] || { _audio__err "test recording failed"; return 1; }
  _audio__ok "saved      ${out}"
  _audio__notify "mic test saved"

  if _audio__have mpv; then
    mpv "$out" >/dev/null 2>&1 &!
  fi
}

audio.restart(){
  emulate -L zsh; setopt pipefail
  _audio__need systemctl || return 1

  if _audio__run "Restarting PipeWire graph…" systemctl --user restart pipewire pipewire-pulse wireplumber; then
    _audio__ok "restarted pipewire, pipewire-pulse, wireplumber"
    _audio__notify "PipeWire restarted"
    return 0
  fi

  _audio__err "restart failed"
  return 1
}


_audio__select(){
  emulate -L zsh
  setopt pipefail
  _audio__check || return 1
  local kind="$1" name
  name="$(_audio__resolve_row "$kind" "$2")" || return 1
  _audio__set_${kind} "$name"
}

_audio__select_matching(){
  emulate -L zsh
  setopt pipefail
  _audio__check || return 1
  local kind="$1" name
  name="$(_audio__pick_matching "$kind" "$2")" || return 1
  _audio__set_${kind} "$name"
}
