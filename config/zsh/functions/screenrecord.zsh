#!/usr/bin/env zsh
# screenrecord.zsh — wl-screenrec wrapper for Hyprland
# Source this file in your ~/.zshrc

rec() {
  # ====================================================================
  # NOTIFICATION & BRANDING SETTINGS
  # Edit these to rename your setup or tweak the notification messages
  # ====================================================================
  local APP_NAME="jarvis"
  local TITLE_START="screen - recording..."
  local TITLE_SAVED="Recording saved"
  local TITLE_ERROR="Recording error!"

  local TEXT_SCREEN="screen"
  local TEXT_REGION="region"
  local TEXT_PLUS_ALL_AUDIO=" + all audio"
  local TEXT_PLUS_DESKTOP=" + desktop audio"
  local TEXT_PLUS_MIC=" + mic"
  # ====================================================================

  local state_base="${XDG_RUNTIME_DIR:-/tmp}/screenrec-${UID}"
  mkdir -p "$state_base"
  
  local lock_dir="${state_base}/lock"
  local pid_file="${state_base}/rec.pid"
  local path_file="${state_base}/rec.path"

  # ── 1. ATOMIC LOCK ──────────────────────────────────────────────────
  if ! mkdir "$lock_dir" 2>/dev/null; then
    local holder
    holder=$(cat "${lock_dir}/owner" 2>/dev/null || true)
    if [[ -n "$holder" ]] && kill -0 "$holder" 2>/dev/null; then
      return 0
    fi
    rm -rf "$lock_dir"
    mkdir "$lock_dir" 2>/dev/null || return 0
  fi
  echo "$$" > "${lock_dir}/owner"

  {
    # ── 2. STOP RECORDING ─────────────────────────────────────────────
    local active_pid
    active_pid=$(cat "$pid_file" 2>/dev/null || true)

    if [[ -n "$active_pid" ]] && kill -0 "$active_pid" 2>/dev/null; then
      local fname
      fname=$(cat "$path_file" 2>/dev/null || true)

      kill -TERM "$active_pid" 2>/dev/null || true

      local i=0
      while kill -0 "$active_pid" 2>/dev/null && (( i < 300 )); do
        sleep 0.1
        (( i++ ))
      done

      if kill -0 "$active_pid" 2>/dev/null; then
        kill -9 "$active_pid" 2>/dev/null || true
        notify-send -a "$APP_NAME" "$TITLE_ERROR" "Force-killed — file may be corrupt" -u critical -t 6000 2>/dev/null
      fi

      rm -f "$pid_file" "$path_file"

      # Clean up all virtual mixer loops
      for mod_file in $(find "$state_base" -maxdepth 1 -name "pa_mod_*.id" 2>/dev/null); do
        pactl unload-module "$(cat "$mod_file")" 2>/dev/null || true
        rm -f "$mod_file"
      done

      pkill -RTMIN+8 waybar 2>/dev/null || true

      if [[ -n "$fname" && -f "$fname" ]]; then
        echo -n "$fname" | wl-copy 2>/dev/null || true
        local preview="${fname%.mp4}-thumb.png"
        ffmpeg -y -i "$fname" -ss 0.1 -vframes 1 -q:v 2 "$preview" -loglevel quiet 2>/dev/null || true

        (
          local action
          action=$(notify-send -a "$APP_NAME" "$TITLE_SAVED" "Click to open\n$(basename "$fname")" \
            -t 12000 -i "${preview:-video-x-generic}" -A "open=Open" 2>/dev/null)
          [[ "$action" == "open" ]] && mpv "$fname" >/dev/null 2>&1
          rm -f "$preview"
        ) &!
      fi
      
      # Clear the screen so 'rec' doesn't stay on the terminal
      clear
      return 0
    fi

    # ── 3. START RECORDING ────────────────────────────────────────────
    local mic=false desktop=false no_cursor=false region=false
    local resolution="" output=""

    for arg in "$@"; do
      case "$arg" in
        --mic)         mic=true ;;
        --desktop)     desktop=true ;;
        --no-cursor)   no_cursor=true ;;
        --res=*)       resolution="${arg#*=}" ;;
        --output=*)    output="${arg#*=}" ;;
        region)        region=true ;;
      esac
    done

    local out_dir="$HOME/recordings"
    mkdir -p "$out_dir"
    local fname="$out_dir/rec-$(date +'%Y-%m-%d_%H-%M-%S').mp4"
    local args=(-f "$fname")

    if [[ "$region" == true ]]; then
      local geom
      geom=$(slurp 2>/dev/null) || return 1
      args+=(-g "$geom")
    else
      if [[ -z "$output" ]]; then
        output=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name')
      fi
      args+=(-o "$output")
    fi

    # ── 4. AUDIO SELECTION (fzf) ──────────────────────────────────────
    local d_src=""
    local m_src=""

    if [[ "$desktop" == true ]]; then
      local selected_sink
      selected_sink=$(pactl list short sinks | awk '{print $2}' | fzf --prompt="🔊 Select Desktop Output > " --height=40% --reverse)
      if [[ -n "$selected_sink" ]]; then
        d_src="${selected_sink}.monitor"
      else
        echo "Canceled desktop selection."
        return 1
      fi
    fi

    if [[ "$mic" == true ]]; then
      m_src=$(pactl list short sources | grep -v '\.monitor' | awk '{print $2}' | fzf --prompt="🎤 Select Microphone > " --height=40% --reverse)
      if [[ -z "$m_src" ]]; then
        echo "Canceled mic selection."
        return 1
      fi
    fi

    # ── 5. AUDIO MIXING & DOWNMIXING ──────────────────────────────────
    if [[ "$desktop" == true || "$mic" == true ]]; then
      args+=(--audio)
      
      local mix_sink="rec_mix_$$"
      local mod_sink=$(pactl load-module module-null-sink sink_name=$mix_sink sink_properties=device.description="Screenrec-Mix" 2>/dev/null)
      echo "$mod_sink" > "${state_base}/pa_mod_sink.id"
      
      if [[ "$desktop" == true ]]; then
        local mod_loop1=$(pactl load-module module-loopback source="$d_src" sink=$mix_sink latency_msec=20 2>/dev/null)
        echo "$mod_loop1" > "${state_base}/pa_mod_loop1.id"
      fi
      
      if [[ "$mic" == true ]]; then
        local mod_loop2=$(pactl load-module module-loopback source="$m_src" sink=$mix_sink latency_msec=20 channels=1 2>/dev/null)
        echo "$mod_loop2" > "${state_base}/pa_mod_loop2.id"
      fi
      
      args+=(--audio-device "${mix_sink}.monitor")
    fi

    [[ "$no_cursor" == true ]] && args+=(--no-cursor)
    [[ -n "$resolution" ]]     && args+=(--encode-resolution "$resolution")

    # ── 6. LAUNCH ─────────────────────────────────────────────────────
    wl-screenrec "${args[@]}" >/dev/null 2>&1 &!
    local pid=$!

    sleep 0.4
    if ! kill -0 "$pid" 2>/dev/null; then
      notify-send -a "$APP_NAME" "$TITLE_ERROR" "Screen recorder failed to start." -u critical -t 5000 2>/dev/null
      for mod_file in $(find "$state_base" -maxdepth 1 -name "pa_mod_*.id" 2>/dev/null); do
        pactl unload-module "$(cat "$mod_file")" 2>/dev/null || true
        rm -f "$mod_file"
      done
      return 1
    fi

    echo "$pid" > "$pid_file"
    echo "$fname" > "$path_file"

    # Assemble notification target string based on variables
    local target_msg="$TEXT_SCREEN"
    [[ "$region" == true ]] && target_msg="$TEXT_REGION"

    if [[ "$desktop" == true && "$mic" == true ]]; then
      target_msg="$target_msg$TEXT_PLUS_ALL_AUDIO"
    elif [[ "$desktop" == true ]]; then
      target_msg="$target_msg$TEXT_PLUS_DESKTOP"
    elif [[ "$mic" == true ]]; then
      target_msg="$target_msg$TEXT_PLUS_MIC"
    fi

    notify-send -a "$APP_NAME" "$TITLE_START" "$target_msg" -u normal -t 2000 2>/dev/null
    
    # Clear the screen so 'rec' doesn't stay on the terminal
    clear

  } always {
    # ── 7. RELEASE LOCK ───────────────────────────────────────────────
    rm -rf "$lock_dir"
  }
}
