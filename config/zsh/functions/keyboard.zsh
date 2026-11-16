kb() {
  emulate -L zsh
  setopt localoptions errreturn pipefail

  local layout variant
  layout="${1:-}"
  variant="${2:-}"

  if [[ -z "$layout" ]]; then
    echo "usage: keyboard <layout> [variant]"
    return 1
  fi

  if [[ -n "$variant" ]]; then
    sudo localectl set-x11-keymap "$layout" "" "$variant"
  else
    sudo localectl set-x11-keymap "$layout"
  fi

  if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl keyword input:kb_layout "$layout" >/dev/null
    hyprctl keyword input:kb_variant "$variant" >/dev/null
  fi

  printf 'keyboard: %s%s\n' "$layout" "${variant:+ ($variant)}"
}
