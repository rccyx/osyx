source "${${(%):-%N}:A:h}/audio/devices.zsh"
source "${${(%):-%N}:A:h}/audio/controls.zsh"
source "${${(%):-%N}:A:h}/audio/completion.zsh"

audio.help(){
  cat >&2 <<'HELP'

  audio                    interactive menu
  audio in [query]         set default microphone and move active capture streams
  audio out [query]        set default output and move active playback streams
  audio pod                set input to Vocaster, Focusrite, Scarlett, or USB mic
  audio machine            set input to internal machine mic
  audio speakers           set output to internal speakers
  audio headphones         set output to headphones, Bluetooth, USB, or HDMI
  audio status             show defaults and active stream counts
  audio streams            show active capture and playback streams
  audio ls                 list inputs and outputs
  audio tree               show full wpctl node tree
  audio mute in|out        toggle input or output mute
  audio vol [value]        set output volume, e.g. 5%+ 10%- 80%
  audio micvol [value]     set input volume, e.g. 5%+ 10%- 100%
  audio test [seconds]     record default mic test and play it with mpv when present
  audio restart            restart pipewire, pipewire-pulse, and wireplumber

  aliases: ain, aasr, amic, aout, apod, amachine, avol, amicvol

HELP
}

audio(){
  emulate -L zsh; setopt pipefail

  local cmd="${1:-}"; shift 2>/dev/null || true
  case "$cmd" in
    "")
      _audio__need fzf || return 1
      local action
      action="$(printf "%s\n" \
        "in          set microphone" \
        "pod         use pod mic" \
        "machine     use internal mic" \
        "out         set output" \
        "speakers    use internal speakers" \
        "headphones  use headphones" \
        "status      show defaults" \
        "streams     show active streams" \
        "ls          list devices" \
        "tree        show wpctl graph" \
        "mute-in     toggle input mute" \
        "mute-out    toggle output mute" \
        "vol         output volume" \
        "micvol      input volume" \
        "test        record mic test" \
        "restart     restart audio graph" \
        "help        show help" \
        | fzf --prompt="  audio ▸ " --height=50% --reverse --border=rounded \
              --info=hidden --no-scrollbar)" || return 1
      cmd="${action%%[[:space:]]*}"
      ;;
  esac

  case "$cmd" in
    in|input|mic)          audio.in "$@" ;;
    asr)                  audio.asr "$@" ;;
    pod|vocaster|focusrite|scarlett|usb) audio.pod "$@" ;;
    machine|internal|laptop) audio.machine "$@" ;;
    out|output|sink)      audio.out "$@" ;;
    speakers|speaker)     audio.speakers "$@" ;;
    headphones|headphone|bluetooth|bt|hdmi) audio.headphones "$@" ;;
    st|status)            audio.status ;;
    streams|apps)         audio.streams ;;
    ls|list|devices)      audio.ls ;;
    tree|graph)           audio.tree ;;
    mute-in|mutein)       audio.mute.in ;;
    mute-out|muteout)     audio.mute.out ;;
    mute)
      local which="${1:-}"
      case "$which" in
        in|input|mic) audio.mute.in ;;
        out|output|speaker|sink) audio.mute.out ;;
        *) _audio__err "usage: audio mute in|out"; return 1 ;;
      esac
      ;;
    vol|volume)           audio.vol "$@" ;;
    micvol|gain)          audio.micvol "$@" ;;
    test)                 audio.test "$@" ;;
    restart|reload)       audio.restart ;;
    help|-h|--help)       audio.help ;;
    *)                    audio.in "$cmd" "$@" ;;
  esac
}

ain(){ audio.in "$@"; }
aasr(){ audio.asr "$@"; }
amic(){ audio.mic "$@"; }
aout(){ audio.out "$@"; }
apod(){ audio.pod "$@"; }
amachine(){ audio.machine "$@"; }
avol(){ audio.vol "$@"; }
amicvol(){ audio.micvol "$@"; }

