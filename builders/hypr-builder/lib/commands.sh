validate_library_family()
{
  local name="$1" pattern root manifest path target soname dir found=0
  pattern="$(library_family_pattern "$name" 2>/dev/null || true)"
  [ -n "$pattern" ] || return 0
  root="$(library_family_root "$name")"

  manifest="$(manifest_files "$name")"
  [ -s "$manifest" ] || die "missing library manifest: $name"

  while IFS= read -r -d '' path; do
    grep -Fxq "$path" "$manifest" || die "stale unmanaged ABI file: $path"

    if [ -L "$path" ]; then
      target="$(readlink -f "$path" 2>/dev/null || true)"
      [ -e "$target" ] || die "broken library symlink: $path"
      continue
    fi

    file -b "$path" 2>/dev/null | grep -q 'ELF.*shared object' || continue
    found=1

    soname="$(
      readelf -d "$path" 2>/dev/null |
        sed -n 's/.*(SONAME).*\[\([^]]*\)\].*/\1/p' |
        head -n1
    )"

    [ -n "$soname" ] || die "missing SONAME: $path"
    dir="$(dirname "$path")"
    [ -e "$dir/$soname" ] || die "missing SONAME target: $dir/$soname"

    case "$name" in
      _dep_*)
        ldconfig -p 2>/dev/null |
          awk -v wanted="$soname" -v prefix="$DEP_PREFIX/lib/" '
            $1 == wanted && index($NF, prefix) == 1 { found=1 }
            END { exit found ? 1 : 0 }
          ' || die "private dependency is exposed through ldconfig: $soname"
        ;;
      *)
        ldconfig -p 2>/dev/null |
          awk -v wanted="$soname" -v prefix="$PREFIX/lib/" '
            $1 == wanted && index($NF, prefix) == 1 { found=1 }
            END { exit found ? 0 : 1 }
          ' || die "ldconfig does not resolve $soname from $PREFIX/lib"
        ;;
    esac
  done < <(
    find "$root" -maxdepth 2 \
      \( -type f -o -type l \) \
      -name "$pattern" -print0 2>/dev/null
  )

  [ "$found" -eq 1 ] || die "missing shared library: $name"
}

runtime_requires_prefix()
{
  case "$1" in
    libhypr*.so.*|libaquamarine.so.*)
      return 0
      ;;
    libinput.so.*)
      [ -s "$(manifest_files _dep_libinput)" ]
      return
      ;;
    libxkbcommon.so.*)
      [ -s "$(manifest_files _dep_libxkbcommon)" ]
      return
      ;;
    *)
      return 1
      ;;
  esac
}

validate_elf_dependencies()
{
  local line name manifest path result needed arrow resolved rest expected fallback_dep

  for line in "${REPOS[@]}"; do
    IFS='|' read -r name _ <<<"$line"
    manifest="$(manifest_files "$name")"
    [ -f "$manifest" ] || continue

    while IFS= read -r path || [ -n "$path" ]; do
      [ -e "$path" ] || continue
      file -b "$path" 2>/dev/null | grep -q ELF || continue

      result="$(ldd "$path" 2>&1 || true)"
      grep -q 'not found' <<<"$result" &&
        die "unresolved runtime dependency: $path"

      while IFS= read -r needed; do
        case "$needed" in
          libhypr*.so|libaquamarine.so)
            die "unversioned managed library in NEEDED: $path -> $needed"
            ;;
        esac
      done < <(
        readelf -d "$path" 2>/dev/null |
          sed -n 's/.*(NEEDED).*Shared library: \[\(.*\)\].*/\1/p'
      )

      while read -r needed arrow resolved rest; do
        [ "$arrow" = '=>' ] || continue

        fallback_dep="$(fallback_dependency_for_needed "$needed" 2>/dev/null || true)"
        if [ -n "$fallback_dep" ]; then
          case "$resolved" in
            "$DEP_PREFIX"/lib/*) ;;
            *)
              report_elf_dependency "$path" "$needed"
              die "$path resolves fallback $needed outside $DEP_PREFIX/lib"
              ;;
          esac
        fi

        if runtime_requires_prefix "$needed"; then
          case "$resolved" in
            "$DEP_PREFIX"/lib/*) ;;
            "$PREFIX"/lib/*) ;;
            *) die "$path resolves $needed outside managed library prefixes" ;;
          esac
        fi

        case "$needed" in
          libstdc++.so.6) expected="$TOOLCHAIN_LIBSTDCXX" ;;
          libgcc_s.so.1) expected="$TOOLCHAIN_LIBGCC" ;;
          *) continue ;;
        esac

        [ "$(readlink -f "$resolved" 2>/dev/null || true)" = "$expected" ] ||
          die "$path resolves $needed from the wrong GNU runtime"
      done <<<"$result"
    done <"$manifest"
  done
}

validate_session()
{
  local desktop="/usr/share/wayland-sessions/hyprland.desktop"
  local exec_line

  [ -x "$PREFIX/bin/start-hyprland" ] || die "start-hyprland missing"
  [ -f "$desktop" ] || die "Hyprland session entry missing"

  exec_line="$(sed -n 's/^Exec=//p' "$desktop" | head -n1)"

  case "$exec_line" in
    *start-hyprland*) ;;
    *) die "session entry does not launch start-hyprland" ;;
  esac
}

validate_stack()
{
  validate_system_deps

  local line name ref builder flags probe key

  for line in "${REPOS[@]}"; do
    IFS='|' read -r name _ ref builder flags probe <<<"$line"
    : "$ref" "$builder" "$flags"

    key="$(component_key "$name")"
    installed_current "$name" "$key" "$probe" ||
      die "component validation failed: $name"

    validate_library_family "$name"
  done

  validate_elf_dependencies
  validate_session
}

fallback_dependency_for_needed()
{
  local needed="$1" line name pattern prefix

  for line in "${SYSTEM_DEPS[@]}"; do
    IFS='|' read -r name _ <<<"$line"
    [ -s "$(manifest_files "_dep_$name")" ] || continue

    pattern="$(library_family_pattern "_dep_$name" 2>/dev/null || true)"
    [ -n "$pattern" ] || continue

    prefix="${pattern%\*}"
    case "$needed" in
      "$prefix"*) printf '%s\n' "$name"; return 0 ;;
    esac
  done

  return 1
}

plan()
{
  setup_build_environment
  choose_compilers

  local missing=()
  local line name url ref module minimum builder flags probe have key

  mapfile -t missing < <(missing_packages)

  if [ "${#missing[@]}" -eq 0 ]; then
    log '[cache] apt packages'
  else
    printf '[install] packages: %s\n' "${missing[*]}"
  fi

  log "[compiler] $CC"

  for line in "${SYSTEM_DEPS[@]}"; do
    IFS='|' read -r name url ref module minimum builder flags probe <<<"$line"
    : "$url" "$ref" "$builder" "$flags"

    have="$(pkg_version "$module")"

    if version_ge "$have" "$minimum" && probe_system_dep "$probe"; then
      log "[cache] $module $have"
    else
      key="$(system_dep_key "$name")"

      if stage_current "$name" "$key"; then
        log "[restore] $name"
      elif build_current "$name" "$key"; then
        log "[resume] $name"
      else
        log "[build] $name"
      fi
    fi
  done

  for line in "${REPOS[@]}"; do
    IFS='|' read -r name url ref builder flags probe <<<"$line"
    : "$url" "$ref" "$builder" "$flags"

    key="$(component_key "$name")"

    if installed_current "$name" "$key" "$probe"; then
      log "[cache] $name"
    elif stage_current "$name" "$key"; then
      log "[restore] $name"
    elif build_current "$name" "$key"; then
      log "[resume] $name"
    else
      log "[build] $name"
    fi
  done
}

apply()
{
  [ "$(detect_codename)" = "$APT_RELEASE" ] ||
    die "Debian $APT_RELEASE required"

  install_packages

  need_cmd cmake
  need_cmd meson
  need_cmd ninja
  need_cmd pkg-config
  need_cmd git
  need_cmd curl
  need_cmd tar
  need_cmd sha256sum
  need_cmd make
  need_cmd readelf
  need_cmd ldd
  need_cmd file

  setup_build_environment
  choose_compilers
  ensure_system_deps
  setup_build_environment

  local line name url ref builder flags probe key stage

  for line in "${REPOS[@]}"; do
    IFS='|' read -r name url ref builder flags probe <<<"$line"
    key="$(component_key "$name")"

    if installed_current "$name" "$key" "$probe"; then
      ok "$name"
      continue
    fi

    if stage_current "$name" "$key"; then
      install_stage "$name" "$(stage_path "$name")" "$key"
    else
      ensure_repo "$name" "$url" "$ref"
      build_to_stage "$name" "$builder" "$flags" "$key"
      stage="$(stage_path "$name")"
      install_stage "$name" "$stage" "$key"
    fi

    if [ "$name" = Hyprland ]; then
      copy_session_file || warn "Hyprland session file was not found"
    fi

    probe_component "$probe" || die "$name probe failed"
    ok "$name"
  done

  configure_seatd
  validate_stack

  "$PREFIX/bin/Hyprland" --version 2>/dev/null | head -n 20 || true
}

doctor()
{
  setup_build_environment
  choose_compilers

  [ -x "$PREFIX/bin/Hyprland" ] || die "Hyprland missing"

  local result
  result="$(ldd "$PREFIX/bin/Hyprland" 2>&1 || true)"
  grep -q 'not found' <<<"$result" &&
    die "Hyprland has unresolved runtime libraries"

  "$PREFIX/bin/Hyprland" --version >/dev/null 2>&1 ||
    die "Hyprland cannot report its version"

  validate_stack
  ok "Hyprland"
}

reset()
{
  remove_all_managed
  rm -rf "$CACHE_DIR" "$STATE_DIR"

  [ ! -e "$CACHE_DIR" ] && [ ! -e "$STATE_DIR" ] ||
    die "reset did not remove cache/state"

  [ ! -e "$PREFIX/bin/Hyprland" ] ||
    die "reset left Hyprland installed"

  ok "hypr reset"
}
