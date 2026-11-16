_audio__have(){ command -v "$1" >/dev/null 2>&1; }

_audio__ok(){ _audio__message ok "$*"; }
_audio__err(){ _audio__message err "$*"; }
_audio__note(){ _audio__message note "$*"; }

_audio__message(){
  local kind="$1" message="$2"
  if [[ ! -t 2 ]]; then
    print -ru2 -- "audio ${kind}  ${message}"
    return
  fi

  local color marker
  case "$kind" in
    ok) color=$'\e[32m'; marker='✓' ;;
    err) color=$'\e[31m'; marker='✗' ;;
    note) color=$'\e[36m'; marker='·' ;;
  esac
  print -ru2 -- "  ${color}${marker}"$'\e[0m'"  ${message}"
}

_audio__need(){
  local missing=0 dep
  for dep in "$@"; do
    _audio__have "$dep" || { _audio__err "missing dep: ${dep}"; missing=1; }
  done
  [[ $missing -eq 0 ]]
}

_audio__check(){
  _audio__need pactl wpctl fzf || return 1
}

_audio__notify(){
  _audio__have notify-send && notify-send -a jarvis "jarvis - audio" "$*" -t 2200 2>/dev/null || true
}

_audio__run(){
  local msg="$1"; shift
  if _audio__have gum; then
    gum spin --spinner dot --title "  ${msg}" -- "$@" >/dev/null 2>&1
    local rc=$?
    if [[ $rc -ne 0 ]]; then
      print -ru2 -- ""
      "$@" >/dev/null
      return $rc
    fi
    return 0
  fi

  print -rn -- "  ${msg}" >&2
  "$@" 1>/dev/null
  local rc=$?
  print -ru2 -- ""
  return $rc
}

_audio__default_source(){ pactl get-default-source 2>/dev/null || true; }
_audio__default_sink(){ pactl get-default-sink 2>/dev/null || true; }

_audio__source_rows(){
  local def; def="$(_audio__default_source)"
  pactl list short sources 2>/dev/null | awk -v def="$def" '
    $2 !~ /\.monitor$/ {
      mark = ($2 == def) ? "*" : " "
      printf "%s\t%s\t%s\n", mark, $2, $1
    }
  '
}

_audio__sink_rows(){
  local def; def="$(_audio__default_sink)"
  pactl list short sinks 2>/dev/null | awk -v def="$def" '
    {
      mark = ($2 == def) ? "*" : " "
      printf "%s\t%s\t%s\n", mark, $2, $1
    }
  '
}

_audio__stream_rows_in(){
  pactl list short source-outputs 2>/dev/null | awk '{ printf "%s\t%s\t%s\n", $1, $3, $4 }'
}

_audio__stream_rows_out(){
  pactl list short sink-inputs 2>/dev/null | awk '{ printf "%s\t%s\t%s\n", $1, $3, $4 }'
}

_audio__node_id_for_name(){
  local name="$1"
  wpctl status --name 2>/dev/null | awk -v n="$name" '
    index($0, n) {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^[0-9]+\.$/) {
          sub(/\.$/, "", $i)
          print $i
          exit
        }
      }
    }
  '
}

_audio__pick_row(){
  local kind="$1" rows selected
  case "$kind" in
    source) rows="$(_audio__source_rows)" ;;
    sink)   rows="$(_audio__sink_rows)" ;;
    *) return 1 ;;
  esac

  [[ -z "$rows" ]] && { _audio__err "no ${kind}s found"; return 1; }

  if [[ "$kind" == source ]]; then
    selected="$(print -r -- "$rows" | fzf \
      --prompt="  audio in ▸ " --height=50% --reverse --border=rounded \
      --delimiter=$'\t' --with-nth=1,2 --info=hidden --no-scrollbar \
      --preview='pactl list sources 2>/dev/null | sed -n "/Name: {2}/,/^Source #/p" | sed -E "s/^[[:space:]]+//" | head -90' \
      --preview-window=right:58%:wrap)" || return 1
  else
    selected="$(print -r -- "$rows" | fzf \
      --prompt="  audio out ▸ " --height=50% --reverse --border=rounded \
      --delimiter=$'\t' --with-nth=1,2 --info=hidden --no-scrollbar \
      --preview='pactl list sinks 2>/dev/null | sed -n "/Name: {2}/,/^Sink #/p" | sed -E "s/^[[:space:]]+//" | head -90' \
      --preview-window=right:58%:wrap)" || return 1
  fi

  [[ -z "$selected" ]] && return 1
  print -r -- "$selected" | awk -F '\t' '{print $2}'
}

_audio__resolve_row(){
  local kind="$1" query="$2" rows matches count selected
  case "$kind" in
    source) rows="$(_audio__source_rows)" ;;
    sink)   rows="$(_audio__sink_rows)" ;;
    *) return 1 ;;
  esac

  [[ -z "$rows" ]] && { _audio__err "no ${kind}s found"; return 1; }
  [[ -z "$query" ]] && { _audio__pick_row "$kind"; return; }

  matches="$(print -r -- "$rows" | awk -F '\t' -v q="$query" '
    BEGIN { ql = tolower(q) }
    {
      name = tolower($2)
      id = tolower($3)
      if (name == ql || id == ql || index(name, ql) > 0) print $0
    }
  ')"

  count="$(print -r -- "$matches" | sed '/^[[:space:]]*$/d' | wc -l | tr -d '[:space:]')"
  if [[ "$count" == "0" ]]; then
    _audio__err "${kind} not found: ${query}"
    return 1
  fi

  if [[ "$count" == "1" ]]; then
    print -r -- "$matches" | awk -F '\t' '{print $2}'
    return
  fi

  selected="$(print -r -- "$matches" | fzf \
    --prompt="  audio ${kind} ▸ " --height=50% --reverse --border=rounded \
    --delimiter=$'\t' --with-nth=1,2 --info=hidden --no-scrollbar)" || return 1
  [[ -z "$selected" ]] && return 1
  print -r -- "$selected" | awk -F '\t' '{print $2}'
}

_audio__set_source(){
  local name="$1" id
  [[ -z "$name" ]] && return 1

  pactl set-default-source "$name" 2>/dev/null || { _audio__err "failed to set source: ${name}"; return 1; }

  id="$(_audio__node_id_for_name "$name")"
  [[ -n "$id" ]] && wpctl set-default "$id" 2>/dev/null || true

  local moved=0 stream
  for stream in ${(f)$(_audio__stream_rows_in | awk '{print $1}')}; do
    [[ -n "$stream" ]] || continue
    pactl move-source-output "$stream" "$name" >/dev/null 2>&1 && (( moved++ )) || true
  done

  _audio__ok "input      ${name}"
  [[ "$moved" -gt 0 ]] && _audio__note "streams    moved ${moved} active capture stream(s)"
  _audio__notify "input → ${name}"
}

_audio__set_sink(){
  local name="$1" id
  [[ -z "$name" ]] && return 1

  pactl set-default-sink "$name" 2>/dev/null || { _audio__err "failed to set sink: ${name}"; return 1; }

  id="$(_audio__node_id_for_name "$name")"
  [[ -n "$id" ]] && wpctl set-default "$id" 2>/dev/null || true

  local moved=0 stream
  for stream in ${(f)$(_audio__stream_rows_out | awk '{print $1}')}; do
    [[ -n "$stream" ]] || continue
    pactl move-sink-input "$stream" "$name" >/dev/null 2>&1 && (( moved++ )) || true
  done

  _audio__ok "output     ${name}"
  [[ "$moved" -gt 0 ]] && _audio__note "streams    moved ${moved} active playback stream(s)"
  _audio__notify "output → ${name}"
}

_audio__pick_matching(){
  local kind="$1" pattern="$2" rows matches count selected
  local label="${kind/source/input}"
  label="${label/sink/output}"
  rows="$(_audio__${kind}_rows)"
  matches="$(print -r -- "$rows" | grep -Ei "$pattern" || true)"
  count="$(print -r -- "$matches" | sed '/^[[:space:]]*$/d' | wc -l | tr -d '[:space:]')"

  if [[ "$count" == "0" ]]; then
    _audio__err "no ${label} found"
    _audio__note "open picker instead"
    _audio__pick_row "$kind"
    return
  fi

  if [[ "$count" == "1" ]]; then
    print -r -- "$matches" | awk -F '\t' '{print $2}'
    return
  fi

  selected="$(print -r -- "$matches" | fzf \
    --prompt="  ${label} ▸ " --height=50% --reverse --border=rounded \
    --delimiter=$'\t' --with-nth=1,2 --info=hidden --no-scrollbar)" || return 1
  [[ -z "$selected" ]] && return 1
  print -r -- "$selected" | awk -F '\t' '{print $2}'
}

