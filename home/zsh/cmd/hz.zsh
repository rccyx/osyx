hz() {
  if command -v xrandr >/dev/null; then
    DISPLAY="${DISPLAY:-:0}" xrandr -q 2>/dev/null \
    | awk '/\*/ {
        for (i=1; i<=NF; i++) {
          if ($i ~ /\*/) {
            gsub(/\*/, "", $i)
            print $i " Hz"
            exit
          }
        }
      }'
    return
  fi

  if command -v hyprctl >/dev/null; then
    hyprctl monitors | awk -F"[@ ]" '/@/{print $3 " Hz"; exit}'
    return
  fi

  if command -v modetest >/dev/null; then
    modetest -c | awk '
      BEGIN{inconn=0}
      /^Connectors:/{inconn=1; next}
      /^CRTCs:/{inconn=0}
      inconn && /connected/ {seen=1}
      seen && /^[ \t]*[0-9]+x[0-9]+/ {
        hz=$NF
        gsub("[()Hz]","",hz)
        print hz " Hz"
        exit
      }'
    return
  fi

  echo "No tool found. Install xrandr, hyprctl, or modetest." >&2
}

