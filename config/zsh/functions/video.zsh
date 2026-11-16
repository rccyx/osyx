# ==============================================================================
# Elite Video toolkit for Zsh: video
# deps: ffmpeg, fzf; optional: fd
# ==============================================================================
# ---------- tiny UI helpers ----------
_v_ok(){ print -P "%F{2}✔%f $*"; }
_v_err(){ print -P "%F{1}✖%f $*"; }
# ---------- deps ----------
_video_check(){
  command -v ffmpeg >/dev/null 2>&1 || { _v_err "missing dep: ffmpeg"; return 1; }
  command -v fzf >/dev/null 2>&1 || { _v_err "missing dep: fzf"; return 1; }
}
# ---------- pickers ----------
_video_pick_file(){
  if command -v fd >/dev/null 2>&1; then
    fd -t f -e mp4 -e mkv -e mov -e webm -e avi . | sort | fzf --height=50% --prompt="pick video ⇢ "
  else
    find . -maxdepth 1 -type f \( -iname \*.mp4 -o -iname \*.mkv -o -iname \*.mov -o -iname \*.webm -o -iname \*.avi \) -printf "%P\n" | sort | fzf --height=50% --prompt="pick video ⇢ "
  fi
}
# ---------- actions ----------
# Compress video drastically using libx264 and CRF
video_compress(){
  emulate -L zsh; setopt pipefail
  _video_check || return 1
  local f; f="$(_video_pick_file)"
  [[ -z "$f" ]] && { _v_err "nothing selected"; return 1; }
  local crf
  read -r "crf?Enter CRF [0-51] (default 30, lower=better qual, higher=smaller size): "
  crf=${crf:-30}
  local out="compressed-${f:t}"
  print -P "%F{244}→%f ffmpeg -i ${(q)f} -vcodec libx264 -crf $crf ${(q)out}"
  
  ffmpeg -i "$f" -vcodec libx264 -crf "$crf" "$out" </dev/null && _v_ok "Compression complete: $out" || _v_err "Compression failed"
}
# Cut a specific segment from a video without re-encoding (instant)
video_cut(){
  emulate -L zsh; setopt pipefail
  _video_check || return 1
  local f; f="$(_video_pick_file)"
  [[ -z "$f" ]] && { _v_err "nothing selected"; return 1; }
  local start duration
  read -r "start?Start time in seconds (e.g., 0 or 12.5): "
  [[ -z "$start" ]] && { _v_err "start time required"; return 1; }
  read -r "duration?Duration in seconds (e.g., 6 or 10): "
  [[ -z "$duration" ]] && { _v_err "duration required"; return 1; }
  local out="cut-${f:t}"
  print -P "%F{244}→%f ffmpeg -ss $start -i ${(q)f} -t $duration -c copy ${(q)out}"
  
  ffmpeg -ss "$start" -i "$f" -t "$duration" -c copy "$out" </dev/null && _v_ok "Cut complete: $out" || _v_err "Cut failed"
}
# Convert video to a high-quality GIF
video_gif(){
  emulate -L zsh; setopt pipefail
  _video_check || return 1
  local f; f="$(_video_pick_file)"
  [[ -z "$f" ]] && { _v_err "nothing selected"; return 1; }
  local out="${f:r}.gif"
  print -P "%F{244}→%f Generating GIF..."
  ffmpeg -i "$f" -vf "fps=15,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 "$out" </dev/null && _v_ok "GIF created: $out" || _v_err "GIF creation failed"
}
# Top level menu
video_help(){
cat <<'EOF'
video menu
  compress       Crush video file size (H.264, default CRF 30)
  cut            Extract a segment instantly without re-encoding
  gif            Convert video to a high-quality, palette-optimized GIF
EOF
}
# Master interactive trigger
video(){
  _video_check || return 1
  local cmd="$1"
  if [[ -n "$cmd" ]]; then
    shift
  else
    cmd=$(
      printf "%s\n" \
        "compress" "cut" "gif" "help" \
      | fzf --prompt="video ⇢ "
    )
    [[ -z "$cmd" ]] && return 1
  fi
  "video_${cmd}" "$@"
}
# ---------- zsh completion for video ----------
_video_complete(){
  local -a sub=(compress cut gif help)
  _describe -t commands 'video subcommands' sub
}
compdef _video_complete video
