8safe_name()
{
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'
}

manifest_files()
{
  printf '%s/%s.files' "$MANIFEST_DIR" "$(safe_name "$1")"
}

manifest_dirs()
{
  printf '%s/%s.dirs' "$MANIFEST_DIR" "$(safe_name "$1")"
}

installed_key_path()
{
  printf '%s/%s.key' "$MANIFEST_DIR" "$(safe_name "$1")"
}

manifest_present()
{
  local manifest path
  manifest="$(manifest_files "$1")"
  [ -s "$manifest" ] || return 1

  while IFS= read -r path || [ -n "$path" ]; do
    [ -n "$path" ] || continue
    [ -e "$path" ] || [ -L "$path" ] || return 1
  done <"$manifest"
}

remove_component()
{
  local name="$1" files dirs path
  files="$(manifest_files "$name")"
  dirs="$(manifest_dirs "$name")"

  if [ -f "$files" ]; then
    while IFS= read -r path || [ -n "$path" ]; do
      [ -n "$path" ] || continue
      as_root rm -f -- "$path"
    done < <(LC_ALL=C sort -r "$files")
  fi

  if [ -f "$dirs" ]; then
    while IFS= read -r path || [ -n "$path" ]; do
      [ -n "$path" ] || continue
      case "$path" in
        /|/usr|/usr/local|/usr/share|/usr/local/share|/usr/local/lib|/usr/local/bin)
          continue
          ;;
      esac
      as_root rmdir --ignore-fail-on-non-empty -- "$path" 2>/dev/null || true
    done < <(awk '{ print length, $0 }' "$dirs" | sort -rn | cut -d' ' -f2-)
  fi

  if [ -f "$files" ]; then
    while IFS= read -r path || [ -n "$path" ]; do
      [ -n "$path" ] || continue
      [ ! -e "$path" ] && [ ! -L "$path" ] ||
        die "failed to remove owned file: $path"
    done <"$files"
  fi

  rm -f "$files" "$dirs" "$(installed_key_path "$name")"
}

record_owned_file()
{
  local manifest
  manifest="$(manifest_files "$1")"
  mkdir -p "$MANIFEST_DIR"
  grep -Fxq "$2" "$manifest" 2>/dev/null || printf '%s\n' "$2" >>"$manifest"
}

library_family_pattern()
{
  case "$1" in
    hyprutils) printf 'libhyprutils.so*' ;;
    hyprlang) printf 'libhyprlang.so*' ;;
    hyprcursor) printf 'libhyprcursor.so*' ;;
    hyprgraphics) printf 'libhyprgraphics.so*' ;;
    hyprwire) printf 'libhyprwire.so*' ;;
    hyprtoolkit) printf 'libhyprtoolkit.so*' ;;
    aquamarine) printf 'libaquamarine.so*' ;;
    _dep_libxkbcommon) printf 'libxkbcommon.so*' ;;
    _dep_libinput) printf 'libinput.so*' ;;
    *) return 1 ;;
  esac
}

library_family_root()
{
  case "$1" in
    _dep_*) printf '%s/lib' "$DEP_PREFIX" ;;
    *) printf '%s/lib' "$PREFIX" ;;
  esac
}

prune_library_family()
{
  local pattern root path
  pattern="$(library_family_pattern "$1" 2>/dev/null || true)"
  [ -n "$pattern" ] || return 0
  root="$(library_family_root "$1")"

  for root in "$root" "$PREFIX/lib"; do
    [ -d "$root" ] || continue
    while IFS= read -r -d '' path; do
      as_root rm -f -- "$path"
    done < <(
      find "$root" -maxdepth 2 \
        \( -type f -o -type l \) \
        -name "$pattern" -print0 2>/dev/null
    )
  done
}

install_stage()
{
  local name="$1" stage="$2" key="$3"
  local files_tmp dirs_tmp

  [ -d "$stage" ] || die "stage missing for $name"
  [ -n "$(find "$stage" -mindepth 1 -print -quit 2>/dev/null)" ] ||
    die "stage is empty for $name"

  mkdir -p "$STATE_DIR" "$MANIFEST_DIR"

  files_tmp="$STATE_DIR/.$(safe_name "$name").files.tmp"
  dirs_tmp="$STATE_DIR/.$(safe_name "$name").dirs.tmp"

  find "$stage" -mindepth 1 \( -type f -o -type l \) -printf '/%P\n' |
    LC_ALL=C sort -u >"$files_tmp"
  find "$stage" -mindepth 1 -type d -printf '/%P\n' |
    LC_ALL=C sort -u >"$dirs_tmp"

  [ -s "$files_tmp" ] || die "no files staged for $name"

  remove_component "$name"
  prune_library_family "$name"
	as_root cp -a --remove-destination "$stage"/. /

  mv "$files_tmp" "$(manifest_files "$name")"
  mv "$dirs_tmp" "$(manifest_dirs "$name")"
  printf '%s\n' "$key" >"$(installed_key_path "$name")"

  as_root ldconfig >/dev/null 2>&1 || true
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  hash -r
}

copy_session_file()
{
  local source="$PREFIX/share/wayland-sessions/hyprland.desktop"
  local target="/usr/share/wayland-sessions/hyprland.desktop"

  [ -f "$source" ] || return 1

  as_root install -d -m 0755 /usr/share/wayland-sessions
  as_root install -m 0644 "$source" "$target"
  record_owned_file Hyprland "$target"
}

managed_install_without_manifests()
{
  if [ -x "$PREFIX/bin/Hyprland" ]; then
    return 0
  fi

  find "$PREFIX/lib" -maxdepth 2 \
    \( -name 'libhyprutils.so*' -o -name 'libhyprlang.so*' -o -name 'libaquamarine.so*' \) \
    -print -quit 2>/dev/null | grep -q .
}

remove_all_managed()
{
  local file name
  shopt -s nullglob
  local manifests=("$MANIFEST_DIR"/*.files)
  shopt -u nullglob

  if [ "${#manifests[@]}" -eq 0 ]; then
    if managed_install_without_manifests; then
      die "managed Hypr files exist but ownership manifests are missing"
    fi
    return 0
  fi

  for file in "${manifests[@]}"; do
    name="$(basename "$file" .files)"
    remove_component "$name"
  done

  as_root ldconfig >/dev/null 2>&1 || true
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  hash -r
}
