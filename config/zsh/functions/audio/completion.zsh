_audio__comp(){
  local -a sub=(
    in input mic asr pod vocaster focusrite scarlett usb machine internal laptop
    out output sink speakers headphones bluetooth hdmi
    status streams apps ls list devices tree graph
    mute mute-in mute-out vol volume micvol gain test restart reload help
  )
  _describe -t commands 'audio subcommands' sub
}

_audio__in_comp(){
  local -a names
  names=("${(@f)$(_audio__source_rows 2>/dev/null | awk -F '\t' '{print $2}')}")
  _describe -t sources 'audio inputs' names
}

_audio__out_comp(){
  local -a names
  names=("${(@f)$(_audio__sink_rows 2>/dev/null | awk -F '\t' '{print $2}')}")
  _describe -t sinks 'audio outputs' names
}

compdef _audio__comp audio
compdef _audio__in_comp ain aasr amic
compdef _audio__out_comp aout
