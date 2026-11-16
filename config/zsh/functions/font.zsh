# Usage: font [set|show]
# Deps: fzf, gsettings, xsettingsd, fc-cache
font() {
  local _cmd="${1:-set}"

  case "$_cmd" in
    show)
      echo "=== Current Font Configuration ==="
      echo -n "• gsettings (GNOME): "
      gsettings get org.gnome.desktop.interface font-name 2>/dev/null || echo "N/A"
      
      local _gtk3="${HOME}/.config/gtk-3.0/settings.ini"
      if [[ -f "$_gtk3" ]]; then
        echo "• GTK3 settings.ini:   $(grep '^gtk-font-name' "$_gtk3" | cut -d'=' -f2)"
      else
        echo "• GTK3 settings.ini:   Not found"
      fi

      local _gtk4="${HOME}/.config/gtk-4.0/settings.ini"
      if [[ -f "$_gtk4" ]]; then
        echo "• GTK4 settings.ini:   $(grep '^gtk-font-name' "$_gtk4" | cut -d'=' -f2)"
      else
        echo "• GTK4 settings.ini:   Not found"
      fi

      local _xsd="${HOME}/.config/xsettingsd/xsettingsd.conf"
      if [[ -f "$_xsd" ]]; then
        echo "• xsettingsd:          $(grep '^Gtk/FontName' "$_xsd" | cut -d'"' -f2)"
      else
        echo "• xsettingsd:          Not found"
      fi

      echo -n "• fontconfig resolved: "
      fc-match sans-serif 2>/dev/null || echo "N/A"
      return 0
      ;;

    set)
      # GTK omits "Regular" weight by convention; 18pt variant used for UI sizes
      local -a _opts=(
        "Inter Regular 9|Inter 18pt 9|inter"
        "Inter Regular 10|Inter 18pt 10|inter"
        "Inter Regular 11|Inter 18pt 11|inter"
        "Inter Regular 12|Inter 18pt 12|inter"
        "Inter Medium 9|Inter 18pt Medium 9|inter"
        "Inter Medium 10|Inter 18pt Medium 10|inter"
        "Inter Medium 11|Inter 18pt Medium 11|inter"
        "Inter Bold 10|Inter 18pt Bold 10|inter"
        "Inter Bold 11|Inter 18pt Bold 11|inter"
        "Inter Black 10|Inter 18pt Black 10|inter"
        "Inter Black 11|Inter 18pt Black 11|inter"
        "Satoshi Regular 9|Satoshi 9|satoshi"
        "Satoshi Regular 10|Satoshi 10|satoshi"
        "Satoshi Regular 11|Satoshi 11|satoshi"
        "Satoshi Regular 12|Satoshi 12|satoshi"
        "Satoshi Medium 9|Satoshi Medium 9|satoshi"
        "Satoshi Medium 10|Satoshi Medium 10|satoshi"
        "Satoshi Medium 11|Satoshi Medium 11|satoshi"
        "Satoshi Bold 10|Satoshi Bold 10|satoshi"
        "Satoshi Bold 11|Satoshi Bold 11|satoshi"
        "Satoshi Black 10|Satoshi Black 10|satoshi"
        "Plus Jakarta Sans Regular 10|Plus Jakarta Sans 10|jakarta"
        "Plus Jakarta Sans Regular 11|Plus Jakarta Sans 11|jakarta"
        "Plus Jakarta Sans Medium 10|Plus Jakarta Sans Medium 10|jakarta"
        "Plus Jakarta Sans Medium 11|Plus Jakarta Sans Medium 11|jakarta"
        "Plus Jakarta Sans Bold 10|Plus Jakarta Sans Bold 10|jakarta"
      )

      # ── fzf: show only display name (field 1) ──────────────────────────
      local _selected
      _selected=$(printf '%s\n' "${_opts[@]}" \
        | fzf --delimiter='|' --with-nth=1 \
              --prompt='font ❯ ' \
              --height=50% --border=rounded \
              --preview-window=hidden)

      [[ -z "$_selected" ]] && return 0

      local _gtk_font="${${_selected#*|}%%|*}"   # field 2
      local _fc_family="${_selected##*|}"         # field 3

      echo "→ applying: $_gtk_font"

      # ── GTK3 ────────────────────────────────────────────────────────────
      local _gtk3="${HOME}/.config/gtk-3.0/settings.ini"
      if [[ -f "$_gtk3" ]]; then
        sed -i "s/^gtk-font-name=.*/gtk-font-name=${_gtk_font}/" "$_gtk3"
      else
        mkdir -p "${HOME}/.config/gtk-3.0"
        printf '[Settings]\ngtk-font-name=%s\n' "$_gtk_font" > "$_gtk3"
      fi

      # ── GTK4 ────────────────────────────────────────────────────────────
      local _gtk4="${HOME}/.config/gtk-4.0/settings.ini"
      if [[ -f "$_gtk4" ]]; then
        sed -i "s/^gtk-font-name=.*/gtk-font-name=${_gtk_font}/" "$_gtk4"
      else
        mkdir -p "${HOME}/.config/gtk-4.0"
        printf '[Settings]\ngtk-font-name=%s\n' "$_gtk_font" > "$_gtk4"
      fi

      # ── GTK2 ────────────────────────────────────────────────────────────
      local _gtk2="${HOME}/.gtkrc-2.0"
      if [[ -f "$_gtk2" ]]; then
        sed -i "s/^gtk-font-name=.*/gtk-font-name=\"${_gtk_font}\"/" "$_gtk2"
      else
        printf 'gtk-font-name="%s"\n' "$_gtk_font" > "$_gtk2"
      fi

      # ── xsettingsd ──────────────────────────────────────────────────────
      local _xsd="${HOME}/.config/xsettingsd/xsettingsd.conf"
      if [[ -f "$_xsd" ]]; then
        if grep -q '^Gtk/FontName' "$_xsd"; then
          sed -i "s|^Gtk/FontName.*|Gtk/FontName \"${_gtk_font}\"|" "$_xsd"
        else
          printf 'Gtk/FontName "%s"\n' "$_gtk_font" >> "$_xsd"
        fi
      fi

      # ── gsettings ───────────────────────────────────────────────────────
      gsettings set org.gnome.desktop.interface font-name "${_gtk_font}" 2>/dev/null

      # ── nwg-look: overwrite its saved font so it can't revert us ────────
      local _nwg="${HOME}/.config/nwg-look/config"
      if [[ -f "$_nwg" ]]; then
        sed -i "s/\"gtk-font-name\":.*$/\"gtk-font-name\": \"${_gtk_font}\",/" "$_nwg" 2>/dev/null || true
      fi

      # ── fontconfig: regenerate fonts.conf ───────────────────────────────
      local _fc="${HOME}/.config/fontconfig/fonts.conf"
      mkdir -p "${HOME}/.config/fontconfig"

      _fc_inter() {
        cat << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>

  <!-- Rendering (1080p optimized) -->
  <match target="font">
    <edit name="antialias"  mode="assign"><bool>true</bool></edit>
    <edit name="hinting"    mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle"  mode="assign"><const>hintslight</const></edit>
    <edit name="rgba"       mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter"  mode="assign"><const>lcddefault</const></edit>
  </match>

  <!-- Force Light (300) → Regular (400) -->
  <match target="pattern">
    <test name="weight" compare="less_eq"><const>light</const></test>
    <edit name="weight" mode="assign"><const>regular</const></edit>
  </match>

  <!-- Inter optical size routing -->
  <match target="pattern">
    <test name="family"><string>sans-serif</string></test>
    <test name="size" compare="less"><double>18</double></test>
    <edit name="family" mode="prepend"><string>Inter 18pt</string></edit>
  </match>
  <match target="pattern">
    <test name="family"><string>sans-serif</string></test>
    <test name="size" compare="more_eq"><double>18</double></test>
    <edit name="family" mode="prepend"><string>Inter 28pt</string></edit>
  </match>

  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Inter 18pt</family>
      <family>Inter 28pt</family>
      <family>Satoshi</family>
      <family>Plus Jakarta Sans</family>
    </prefer>
  </alias>

  <alias>
    <family>serif</family>
    <prefer>
      <family>Inter 28pt</family>
    </prefer>
  </alias>

  <alias>
    <family>monospace</family>
    <prefer>
      <family>Iosevka Fixed SS18</family>
      <family>Meslo LG S</family>
      <family>MesloLGS NF</family>
    </prefer>
  </alias>

</fontconfig>
EOF
      }

      _fc_satoshi() {
        cat << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>

  <!-- Rendering (1080p optimized) -->
  <match target="font">
    <edit name="antialias"  mode="assign"><bool>true</bool></edit>
    <edit name="hinting"    mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle"  mode="assign"><const>hintslight</const></edit>
    <edit name="rgba"       mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter"  mode="assign"><const>lcddefault</const></edit>
  </match>

  <!-- Force Light (300) → Regular (400) -->
  <match target="pattern">
    <test name="weight" compare="less_eq"><const>light</const></test>
    <edit name="weight" mode="assign"><const>regular</const></edit>
  </match>

  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Satoshi</family>
      <family>Plus Jakarta Sans</family>
      <family>Inter 18pt</family>
      <family>Inter 28pt</family>
    </prefer>
  </alias>

  <alias>
    <family>serif</family>
    <prefer>
      <family>Satoshi</family>
    </prefer>
  </alias>

  <alias>
    <family>monospace</family>
    <prefer>
      <family>Iosevka Fixed SS18</family>
      <family>Meslo LG S</family>
      <family>MesloLGS NF</family>
    </prefer>
  </alias>

</fontconfig>
EOF
      }

      _fc_jakarta() {
        cat << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>

  <!-- Rendering (1080p optimized) -->
  <match target="font">
    <edit name="antialias"  mode="assign"><bool>true</bool></edit>
    <edit name="hinting"    mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle"  mode="assign"><const>hintslight</const></edit>
    <edit name="rgba"       mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter"  mode="assign"><const>lcddefault</const></edit>
  </match>

  <!-- Force Light (300) → Regular (400) -->
  <match target="pattern">
    <test name="weight" compare="less_eq"><const>light</const></test>
    <edit name="weight" mode="assign"><const>regular</const></edit>
  </match>

  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Plus Jakarta Sans</family>
      <family>Satoshi</family>
      <family>Inter 18pt</family>
      <family>Inter 28pt</family>
    </prefer>
  </alias>

  <alias>
    <family>serif</family>
    <prefer>
      <family>Plus Jakarta Sans</family>
    </prefer>
  </alias>

  <alias>
    <family>monospace</family>
    <prefer>
      <family>Iosevka Fixed SS18</family>
      <family>Meslo LG S</family>
      <family>MesloLGS NF</family>
    </prefer>
  </alias>

</fontconfig>
EOF
      }

      case "$_fc_family" in
        inter)   _fc_inter   > "$_fc" ;;
        satoshi) _fc_satoshi > "$_fc" ;;
        jakarta) _fc_jakarta > "$_fc" ;;
      esac

      # ── Reload everything ────────────────────────────────────────────────
      fc-cache -fv &>/dev/null

      # restart xsettingsd if it's running
      if pgrep -x xsettingsd &>/dev/null; then
        pkill xsettingsd
        sleep 0.2
        xsettingsd &>/dev/null &
      fi

      echo "✓ font set to: ${_gtk_font}"
      ;;

    *)
      echo "Usage: font [set|show]"
      return 1
      ;;
  esac
}