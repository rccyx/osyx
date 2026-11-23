_install_supported_file() {
  local file="${1:l}"

  case "$file" in
    *.deb|*.appimage|*.tar.gz|*.tar.xz|*.tar.bz2|*.tar.zst|*.tgz|*.tbz2|*.tzst|*.tar|*.zip|*.7z)
      return 0
      ;;
    *.apk|*.apkm|*.xapk|*.asc|*.sig|*.sha256|*.sha1|*.md5)
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

_install_stem() {
  local name="${1:t}"

  case "$name" in
    *.tar.gz)  print -r -- "${name%.tar.gz}" ;;
    *.tar.xz)  print -r -- "${name%.tar.xz}" ;;
    *.tar.bz2) print -r -- "${name%.tar.bz2}" ;;
    *.tar.zst) print -r -- "${name%.tar.zst}" ;;
    *.tgz)     print -r -- "${name%.tgz}" ;;
    *.tbz2)    print -r -- "${name%.tbz2}" ;;
    *.tzst)    print -r -- "${name%.tzst}" ;;
    *.tar)     print -r -- "${name%.tar}" ;;
    *.zip)     print -r -- "${name%.zip}" ;;
    *.7z)      print -r -- "${name%.7z}" ;;
    *.deb)     print -r -- "${name%.deb}" ;;
    *.AppImage|*.appimage) print -r -- "${name%.*}" ;;
    *)         print -r -- "${name%.*}" ;;
  esac
}

_install_clean_stem() {
  local stem="$1"
  local cleaned

  cleaned=$(print -r -- "$stem" | sed -E '
    s/[[:space:]]+/ /g;
    s/[-_ ]+(amd64|x86_64|arm64|aarch64|i[3-6]86|linux|gnu|musl|universal|portable)$//I;
    s/[-_ ]+v?[0-9]+([._-][0-9A-Za-z]+)*$//;
    s/[-_ ]+(amd64|x86_64|arm64|aarch64|i[3-6]86|linux|gnu|musl|universal|portable)$//I;
    s/[[:space:]]+/ /g;
    s/^ //;
    s/ $//
  ')

  [[ -z "$cleaned" ]] && cleaned="$stem"
  print -r -- "$cleaned"
}

_install_slug_from_text() {
  local text="$1"
  local slug

  slug=$(print -r -- "$text" | tr '[:upper:]' '[:lower:]' | sed -E 's/[[:space:]_]+/-/g; s/[^a-z0-9.+-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')
  [[ -z "$slug" ]] && slug="app"
  print -r -- "$slug"
}

_install_slug() {
  local stem="$(_install_clean_stem "$(_install_stem "$1")")"
  _install_slug_from_text "$stem"
}

_install_display_name_from_text() {
  local text="$1"
  local name

  name=$(print -r -- "$text" | sed -E 's/[_-]+/ /g; s/[[:space:]]+/ /g; s/^ //; s/ $//')
  [[ -z "$name" ]] && name="App"
  print -r -- "$name"
}

_install_display_name() {
  local stem="$(_install_clean_stem "$(_install_stem "$1")")"
  _install_display_name_from_text "$stem"
}

_install_deb_package_name() {
  local file="$1"
  local package_name

  command -v dpkg-deb >/dev/null 2>&1 || return 1
  package_name=$(dpkg-deb -f "$file" Package 2>/dev/null | head -n 1)
  [[ -n "$package_name" ]] || return 1
  print -r -- "$package_name"
}

_install_choose_file() {
  local query="$1"
  local -a matches
  local file lower_query

  lower_query="${query:l}"

  for file in *(.N); do
    _install_supported_file "$file" || continue
    if [[ -n "$lower_query" && "${file:l}" != *${lower_query}* ]]; then
      continue
    fi
    matches+=("$file")
  done

  if (( ${#matches[@]} == 0 )); then
    return 1
  fi

  if (( ${#matches[@]} == 1 )); then
    print -r -- "$matches[1]"
    return 0
  fi

  if command -v fzf >/dev/null 2>&1; then
    printf '%s\n' "${matches[@]}" | fzf --prompt='[install] select file: '
    return $?
  fi

  print -r -- "$matches[1]"
}

_install_ensure_local_bin_in_path() {
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) return 0 ;;
  esac

  export PATH="$HOME/.local/bin:$PATH"
  rehash 2>/dev/null || true
  print -P "%F{3}[install]%f added %B$HOME/.local/bin%b to PATH for this shell"
}

_install_make_bin_link() {
  local target="$1"
  local link_name="$2"
  local link_path

  [[ -n "$target" && -n "$link_name" ]] || return 1

  command mkdir -p "$HOME/.local/bin"
  link_path="$HOME/.local/bin/$link_name"
  command ln -sfn "$target" "$link_path"
  print -r -- "$link_path"
}

_install_read_key_value() {
  local key="$1"
  local file="$2"
  local line

  [[ -r "$file" ]] || return 1

  while IFS= read -r line; do
    [[ "$line" == "${key}="* ]] || continue
    print -r -- "${line#*=}"
    return 0
  done < "$file"

  return 1
}

_install_write_desktop() {
  local desktop_file="$1"
  local name="$2"
  local exec_path="$3"
  local icon_path="$4"
  local terminal="$5"
  local categories="$6"
  local comment="$7"

  command mkdir -p "$HOME/.local/share/applications"

  {
    print '[Desktop Entry]'
    print 'Version=1.0'
    print 'Type=Application'
    print "Name=$name"
    [[ -n "$comment" ]] && print "Comment=$comment"
    print "Exec=$exec_path"
    [[ -n "$icon_path" ]] && print "Icon=$icon_path"
    print "Terminal=$terminal"
    [[ -n "$categories" ]] && print "Categories=$categories"
  } > "$desktop_file"

  command chmod 644 "$desktop_file"
}

_install_pick_exec_from_paths() {
  local stem="$1"
  local slug="$2"
  shift 2

  local lower_stem="${stem:l}"
  local normalized_stem="${${lower_stem// /-}//_/-}"
  local -a exact bin_candidates candidates
  local candidate base lower_base

  for candidate in "$@"; do
    [[ -n "$candidate" ]] || continue
    [[ -f "$candidate" && -x "$candidate" ]] || continue

    base="${candidate:t}"
    lower_base="${base:l}"

    case "$lower_base" in
      *.so|*.so.*|*.dll|*.dylib|*.desktop|appimaged|chrome-sandbox) continue ;;
    esac

    case "$candidate" in
      */node_modules/*|*/resources/app/node_modules/*|*/share/doc/*|*/share/man/*|*/lib/debug/*) continue ;;
    esac

    if [[ "$lower_base" == "$slug" || "$lower_base" == "$lower_stem" || "$lower_base" == "$normalized_stem" || "$lower_base" == ${slug}* || "$lower_base" == ${normalized_stem}* ]]; then
      exact+=("$candidate")
      continue
    fi

    if [[ "$candidate" == */bin/* || "$candidate" == */usr/bin/* ]]; then
      bin_candidates+=("$candidate")
      continue
    fi

    candidates+=("$candidate")
  done

  if (( ${#exact[@]} == 1 )); then
    print -r -- "$exact[1]"
    return 0
  fi

  if (( ${#exact[@]} > 1 )); then
    if command -v fzf >/dev/null 2>&1; then
      printf '%s\n' "${exact[@]}" | fzf --prompt='[install] select executable: '
    else
      print -r -- "$exact[1]"
    fi
    return $?
  fi

  if (( ${#bin_candidates[@]} == 1 )); then
    print -r -- "$bin_candidates[1]"
    return 0
  fi

  if (( ${#bin_candidates[@]} > 1 )); then
    if command -v fzf >/dev/null 2>&1; then
      printf '%s\n' "${bin_candidates[@]}" | fzf --prompt='[install] select executable: '
    else
      print -r -- "$bin_candidates[1]"
    fi
    return $?
  fi

  if (( ${#candidates[@]} == 1 )); then
    print -r -- "$candidates[1]"
    return 0
  fi

  if (( ${#candidates[@]} > 1 )); then
    if command -v fzf >/dev/null 2>&1; then
      printf '%s\n' "${candidates[@]}" | fzf --prompt='[install] select executable: '
    else
      print -r -- "$candidates[1]"
    fi
    return $?
  fi

  return 1
}

_install_pick_desktop_file() {
  local stem="$1"
  local slug="$2"
  shift 2

  local lower_stem="${stem:l}"
  local normalized_stem="${${lower_stem// /-}//_/-}"
  local -a exact candidates
  local candidate base

  for candidate in "$@"; do
    [[ -n "$candidate" ]] || continue
    [[ "$candidate" == *.desktop ]] || continue

    base="${candidate:t:l}"

    case "$base" in
      *url-handler*|*mimeinfo*|*defaults*) continue ;;
    esac

    if [[ "$base" == "${slug}.desktop" || "$base" == "${lower_stem}.desktop" || "$base" == "${normalized_stem}.desktop" ]]; then
      exact+=("$candidate")
      continue
    fi

    candidates+=("$candidate")
  done

  if (( ${#exact[@]} == 1 )); then
    print -r -- "$exact[1]"
    return 0
  fi

  if (( ${#exact[@]} > 1 )); then
    if command -v fzf >/dev/null 2>&1; then
      printf '%s\n' "${exact[@]}" | fzf --prompt='[install] select desktop entry: '
    else
      print -r -- "$exact[1]"
    fi
    return $?
  fi

  if (( ${#candidates[@]} == 1 )); then
    print -r -- "$candidates[1]"
    return 0
  fi

  if (( ${#candidates[@]} > 1 )); then
    if command -v fzf >/dev/null 2>&1; then
      printf '%s\n' "${candidates[@]}" | fzf --prompt='[install] select desktop entry: '
    else
      print -r -- "$candidates[1]"
    fi
    return $?
  fi

  return 1
}

_install_try_appimage_metadata() {
  local appimage_path="$1"
  local slug="$2"
  local display_name="$3"
  local desktop_target="$HOME/.local/share/applications/${slug}.desktop"
  local tmpdir desktop_src icon_src icon_target terminal categories comment extracted_name

  tmpdir=$(mktemp -d)

  if (cd "$tmpdir" && "$appimage_path" --appimage-extract >/dev/null 2>&1); then
    desktop_src=$(find "$tmpdir/squashfs-root" -type f -name '*.desktop' 2>/dev/null | head -n 1)
    icon_src=$(find "$tmpdir/squashfs-root" -type f \( -name '*.png' -o -name '*.svg' -o -name '*.xpm' \) 2>/dev/null | head -n 1)

    if [[ -n "$icon_src" ]]; then
      command mkdir -p "$HOME/.local/share/icons/hicolor/256x256/apps"
      icon_target="$HOME/.local/share/icons/hicolor/256x256/apps/${slug}.${icon_src##*.}"
      command cp -f "$icon_src" "$icon_target"
    fi

    if [[ -n "$desktop_src" ]]; then
      extracted_name="$(_install_read_key_value "Name" "$desktop_src")"
      [[ -n "$extracted_name" ]] && display_name="$extracted_name"
      terminal="$(_install_read_key_value "Terminal" "$desktop_src")"
      categories="$(_install_read_key_value "Categories" "$desktop_src")"
      comment="$(_install_read_key_value "Comment" "$desktop_src")"
    fi
  fi

  command rm -rf "$tmpdir"

  [[ -z "$terminal" ]] && terminal=false
  _install_write_desktop "$desktop_target" "$display_name" "$appimage_path" "$icon_target" "$terminal" "$categories" "$comment"
}

_install_install_deb() {
  local file="$1"
  local abs_file package_name slug display_name
  local -a installed_files
  local exec_path desktop_src bin_link alt_link desktop_name terminal categories comment icon_value file_item

  abs_file=$(realpath "$file" 2>/dev/null || readlink -f "$file")
  if [[ -z "$abs_file" ]]; then
    print -P "%F{1}[install]%f could not resolve path for %B$file%b"
    return 1
  fi

  if ! command -v apt >/dev/null 2>&1; then
    print -P "%F{1}[install]%f apt is not available on this system"
    return 1
  fi

  package_name="$(_install_deb_package_name "$abs_file")"
  if [[ -z "$package_name" ]]; then
    package_name="$(_install_clean_stem "$(_install_stem "$file")")"
  fi

  slug="$(_install_slug_from_text "$package_name")"
  display_name="$(_install_display_name_from_text "$package_name")"

  print -P "%F{4}[install]%f installing %B${file:t}%b through apt"
  sudo apt install -y "$abs_file" || return $?

  while IFS= read -r file_item; do
    [[ -n "$file_item" ]] && installed_files+=("$file_item")
  done < <(dpkg -L "$package_name" 2>/dev/null)

  exec_path="$(_install_pick_exec_from_paths "$package_name" "$slug" "${installed_files[@]}")"

  if [[ -n "$exec_path" ]]; then
    _install_ensure_local_bin_in_path
    bin_link="$(_install_make_bin_link "$exec_path" "$slug")"
    if [[ -n "$bin_link" && "${exec_path:t}" != "$slug" ]]; then
      alt_link="$(_install_make_bin_link "$exec_path" "${exec_path:t}")"
    fi
    rehash 2>/dev/null || true
  fi

  desktop_src="$(_install_pick_desktop_file "$package_name" "$slug" "${installed_files[@]}")"
  if [[ -n "$desktop_src" && -n "$bin_link" ]]; then
    desktop_name="$(_install_read_key_value "Name" "$desktop_src")"
    [[ -z "$desktop_name" ]] && desktop_name="$display_name"
    terminal="$(_install_read_key_value "Terminal" "$desktop_src")"
    categories="$(_install_read_key_value "Categories" "$desktop_src")"
    comment="$(_install_read_key_value "Comment" "$desktop_src")"
    icon_value="$(_install_read_key_value "Icon" "$desktop_src")"
    [[ -z "$terminal" ]] && terminal=false
    _install_write_desktop "$HOME/.local/share/applications/${slug}.desktop" "$desktop_name" "$bin_link" "$icon_value" "$terminal" "$categories" "$comment"
  fi

  print -P "%F{2}[install]%f deb installed"
  print -P "  %F{6}pkg%f  $package_name"
  [[ -n "$exec_path" ]] && print -P "  %F{6}app%f  $exec_path"
  [[ -n "$bin_link" ]] && print -P "  %F{6}bin%f  $bin_link"
  [[ -n "$alt_link" && "$alt_link" != "$bin_link" ]] && print -P "  %F{6}alt%f  $alt_link"

  if [[ -z "$exec_path" ]]; then
    print -P "%F{3}[install]%f installed the package but could not infer a launchable binary"
  fi
}

_install_install_appimage() {
  local src="$1"
  local slug display_name app_dir app_path bin_link

  slug="$(_install_slug "$src")"
  display_name="$(_install_display_name "$src")"
  app_dir="$HOME/.local/opt/$slug"
  app_path="$app_dir/${slug}.AppImage"

  _install_ensure_local_bin_in_path

  command mkdir -p "$HOME/.local/bin" "$HOME/.local/opt" "$HOME/.local/share/applications" "$app_dir"
  command cp -f "$src" "$app_path"
  command chmod +x "$app_path"

  bin_link="$(_install_make_bin_link "$app_path" "$slug")"
  _install_try_appimage_metadata "$app_path" "$slug" "$display_name"
  rehash 2>/dev/null || true

  print -P "%F{2}[install]%f appimage installed"
  print -P "  %F{6}app%f  $app_path"
  print -P "  %F{6}bin%f  $bin_link"
}

_install_extract_archive() {
  local archive="$1"
  local dest="$2"

  case "${archive:l}" in
    *.tar.gz|*.tgz) tar -xzf "$archive" -C "$dest" ;;
    *.tar.xz) tar -xJf "$archive" -C "$dest" ;;
    *.tar.bz2|*.tbz2) tar -xjf "$archive" -C "$dest" ;;
    *.tar.zst|*.tzst) tar --zstd -xf "$archive" -C "$dest" ;;
    *.tar) tar -xf "$archive" -C "$dest" ;;
    *.zip) unzip -q "$archive" -d "$dest" ;;
    *.7z) 7z x -y "-o$dest" "$archive" >/dev/null ;;
    *) return 1 ;;
  esac
}

_install_pick_candidate_exec() {
  local root="$1"
  local stem="$2"
  local slug="$3"
  local -a found
  local candidate

  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] && found+=("$candidate")
  done < <(
    find "$root" -type f \( -perm -u+x -o -perm -g+x -o -perm -o+x \) \
      ! -path '*/.git/*' \
      ! -path '*/__MACOSX/*' \
      ! -path '*/share/doc/*' \
      ! -path '*/share/man/*' \
      ! -path '*/lib/debug/*' \
      ! -path '*/node_modules/*' 2>/dev/null
  )

  _install_pick_exec_from_paths "$stem" "$slug" "${found[@]}"
}

_install_install_archive() {
  local archive="$1"
  local stem slug display_name tmpdir content_root target_dir picked_exec rel_exec installed_exec bin_link alt_link
  local -a embedded_appimages embedded_debs top_entries
  local file desktop_src rel_desktop installed_desktop desktop_name terminal categories comment icon_path

  stem="$(_install_clean_stem "$(_install_stem "$archive")")"
  slug="$(_install_slug "$archive")"
  display_name="$(_install_display_name "$archive")"
  tmpdir=$(mktemp -d)

  if ! _install_extract_archive "$archive" "$tmpdir"; then
    command rm -rf "$tmpdir"
    print -P "%F{1}[install]%f failed to extract %B${archive:t}%b"
    return 1
  fi

  top_entries=("$tmpdir"/*(N))
  if (( ${#top_entries[@]} == 1 )) && [[ -d "$top_entries[1]" ]]; then
    content_root="$top_entries[1]"
  else
    content_root="$tmpdir"
  fi

  while IFS= read -r file; do
    [[ -n "$file" ]] && embedded_appimages+=("$file")
  done < <(find "$content_root" -type f \( -iname '*.AppImage' -o -iname '*.appimage' \) 2>/dev/null)

  if (( ${#embedded_appimages[@]} == 1 )); then
    _install_install_appimage "$embedded_appimages[1]"
    command rm -rf "$tmpdir"
    return $?
  fi

  while IFS= read -r file; do
    [[ -n "$file" ]] && embedded_debs+=("$file")
  done < <(find "$content_root" -type f -iname '*.deb' 2>/dev/null)

  if (( ${#embedded_debs[@]} == 1 )); then
    _install_install_deb "$embedded_debs[1]"
    command rm -rf "$tmpdir"
    return $?
  fi

  picked_exec="$(_install_pick_candidate_exec "$content_root" "$stem" "$slug")"
  if [[ -z "$picked_exec" ]]; then
    command rm -rf "$tmpdir"
    print -P "%F{1}[install]%f no obvious executable found in %B${archive:t}%b"
    return 1
  fi

  target_dir="$HOME/.local/opt/$slug"
  _install_ensure_local_bin_in_path

  command mkdir -p "$HOME/.local/bin" "$HOME/.local/opt"
  command rm -rf "$target_dir"
  command mkdir -p "$target_dir"

  command cp -R "$content_root"/. "$target_dir"/

  rel_exec="${picked_exec#$content_root/}"
  installed_exec="$target_dir/$rel_exec"
  command chmod +x "$installed_exec" 2>/dev/null || true

  bin_link="$(_install_make_bin_link "$installed_exec" "$slug")"
  if [[ -n "$bin_link" && "${installed_exec:t}" != "$slug" ]]; then
    alt_link="$(_install_make_bin_link "$installed_exec" "${installed_exec:t}")"
  fi
  rehash 2>/dev/null || true

  desktop_src=$(find "$content_root" -type f -name '*.desktop' 2>/dev/null | head -n 1)

  if [[ -n "$desktop_src" ]]; then
    rel_desktop="${desktop_src#$content_root/}"
    installed_desktop="$target_dir/$rel_desktop"
    desktop_name="$(_install_read_key_value "Name" "$installed_desktop")"
    [[ -z "$desktop_name" ]] && desktop_name="$display_name"
    terminal="$(_install_read_key_value "Terminal" "$installed_desktop")"
    categories="$(_install_read_key_value "Categories" "$installed_desktop")"
    comment="$(_install_read_key_value "Comment" "$installed_desktop")"
    icon_path="$(_install_read_key_value "Icon" "$installed_desktop")"

    if [[ -n "$icon_path" && "$icon_path" != /* ]]; then
      if [[ -f "$target_dir/$icon_path" ]]; then
        icon_path="$target_dir/$icon_path"
      else
        icon_path=$(find "$target_dir" -type f \( -name "${icon_path}.png" -o -name "${icon_path}.svg" -o -name "${icon_path}.xpm" \) 2>/dev/null | head -n 1)
      fi
    fi

    [[ -z "$terminal" ]] && terminal=false
    _install_write_desktop "$HOME/.local/share/applications/${slug}.desktop" "$desktop_name" "$bin_link" "$icon_path" "$terminal" "$categories" "$comment"
  fi

  command rm -rf "$tmpdir"

  print -P "%F{2}[install]%f archive installed"
  print -P "  %F{6}dir%f  $target_dir"
  print -P "  %F{6}bin%f  $bin_link"
  [[ -n "$alt_link" && "$alt_link" != "$bin_link" ]] && print -P "  %F{6}alt%f  $alt_link"
}

install() {
  local bold=$'\e[1m'
  local reset=$'\e[0m'
  local red=$'\e[31m'
  local yellow=$'\e[33m'
  local blue=$'\e[34m'
  local cyan=$'\e[36m'

  local input="$1"
  local file

  if [[ "$input" == "--help" ]]; then
    echo "${bold}${cyan}Usage:${reset} install [partial-name]"
    echo "${bold}${cyan}Supports:${reset} .deb, .AppImage, .tar.gz, .tar.xz, .tar.bz2, .tar.zst, .tgz, .tbz2, .tzst, .tar, .zip, .7z"
    echo "${bold}${cyan}Notes:${reset} .deb installs through apt and then writes local shims into ~/.local/bin when a binary is discoverable"
    return 0
  fi

  file="$(_install_choose_file "$input")"
  if [[ -z "$file" ]]; then
    echo "${red}[install] No installable files matched.${reset}"
    return 1
  fi

  [[ ! -f "$file" ]] && echo "${red}[install] '$file' is not a valid file.${reset}" && return 1

  echo "${bold}${blue}[install]${reset} Installing ${yellow}$file${reset}..."

  case "${file:l}" in
    *.deb)
      _install_install_deb "$file"
      ;;
    *.appimage)
      _install_install_appimage "$file"
      ;;
    *.tar.gz|*.tar.xz|*.tar.bz2|*.tar.zst|*.tgz|*.tbz2|*.tzst|*.tar|*.zip|*.7z)
      _install_install_archive "$file"
      ;;
    *.apk|*.apkm|*.xapk)
      echo "${red}[install] Android packages are ignored.${reset}"
      return 1
      ;;
    *)
      echo "${red}[install] Unsupported install target:${reset} $file"
      return 1
      ;;
  esac
}
