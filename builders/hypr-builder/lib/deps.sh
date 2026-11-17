pkg_version()
{
  pkg-config --modversion "$1" 2>/dev/null || true
}

pkg_config_path_without_dep_prefix()
{
  local entry

  tr ':' '\n' <<<"${PKG_CONFIG_PATH:-}" |
    while IFS= read -r entry; do
      [ -n "$entry" ] || continue
      case "$entry" in
        "$DEP_PREFIX"|"$DEP_PREFIX"/*) continue ;;
      esac
      printf '%s\n' "$entry"
    done |
    paste -sd:
}

host_pkg_config()
{
  PKG_CONFIG_PATH="$(pkg_config_path_without_dep_prefix)" pkg-config "$@"
}

host_pkg_version()
{
  host_pkg_config --modversion "$1" 2>/dev/null || true
}

version_ge()
{
  [ -n "$1" ] && dpkg --compare-versions "$1" ge "$2"
}

pkgconfig_libdir_realpath()
{
  local dir
  dir="$(pkg-config --variable=libdir "$1" 2>/dev/null || true)"
  [ -n "$dir" ] || return 1
  readlink -f "$dir"
}

host_pkgconfig_libdir_realpath()
{
  local dir
  dir="$(host_pkg_config --variable=libdir "$1" 2>/dev/null || true)"
  [ -n "$dir" ] || return 1
  readlink -f "$dir"
}

missing_packages()
{
  local package

  all_apt_packages |
    awk 'NF && !seen[$0]++' |
    while IFS= read -r package; do
      dpkg_installed "$package" || printf '%s\n' "$package"
    done
}

all_apt_packages()
{
  local line name

  for line in "${SYSTEM_DEPS[@]}"; do
    IFS='|' read -r name _ <<<"$line"
    system_dep_apt_packages "$name"
  done

  for line in "${REPOS[@]}"; do
    IFS='|' read -r name _ <<<"$line"
    component_apt_packages "$name"
  done
}

system_dep_apt_line()
{
  local wanted="$1" line name packages

  for line in "${SYSTEM_DEP_APT_DEPS[@]}"; do
    IFS='|' read -r name packages <<<"$line"
    if [ "$name" = "$wanted" ]; then
      printf '%s\n' "$line"
      return 0
    fi
  done

  die "missing apt dependency ownership for system dependency: $wanted"
}

component_apt_line()
{
  local wanted="$1" line name packages

  for line in "${COMPONENT_APT_DEPS[@]}"; do
    IFS='|' read -r name packages <<<"$line"
    if [ "$name" = "$wanted" ]; then
      printf '%s\n' "$line"
      return 0
    fi
  done

  die "missing apt dependency ownership for component: $wanted"
}

system_dep_apt_packages()
{
  local line packages

  line="$(system_dep_apt_line "$1")"
  IFS='|' read -r _ packages <<<"$line"
  printf '%s\n' $packages
}

component_apt_packages()
{
  local line packages

  line="$(component_apt_line "$1")"
  IFS='|' read -r _ packages <<<"$line"
  printf '%s\n' $packages
}

install_packages()
{
  local missing=()
  mapfile -t missing < <(missing_packages)

  if [ "${#missing[@]}" -eq 0 ]; then
    return 0
  fi

  info "apt install (${#missing[@]})"
  as_root apt-get update
  as_root apt-get install -y --no-install-recommends "${missing[@]}"
}

probe_system_dep()
{
  case "$1" in
    pc:*)
      pkg-config --exists "${1#pc:}"
      ;;
    lua55)
      pkg-config --exists lua5.5 &&
        [ -f "$DEP_PREFIX/include/lua5.5/lua.h" ] &&
        [ -f "$DEP_PREFIX/lib/liblua5.5.a" ] &&
        [ -x "$DEP_PREFIX/bin/lua5.5" ] &&
        [ -x "$DEP_PREFIX/bin/luac5.5" ]
      ;;
    *)
      die "unknown dependency probe: $1"
      ;;
  esac
}

host_probe_system_dep()
{
  case "$1" in
    pc:*)
      host_pkg_config --exists "${1#pc:}"
      ;;
    lua55)
      host_pkg_config --exists lua5.5 &&
        [ -f /usr/include/lua5.5/lua.h ] &&
        [ -f /usr/lib/liblua5.5.a ]
      ;;
    *)
      die "unknown dependency probe: $1"
      ;;
  esac
}

system_dep_probe_is_private()
{
  local probe="$1" module="$2" variable value

  case "$probe" in
    pc:*)
      for variable in prefix libdir pkgdatadir bindir; do
        value="$(pkg-config --variable="$variable" "$module" 2>/dev/null || true)"
        case "$value" in
          "$DEP_PREFIX"|"$DEP_PREFIX"/*) return 0 ;;
        esac
      done
      return 1
      ;;
    lua55)
      return 0
      ;;
    *)
      die "unknown dependency probe: $probe"
      ;;
  esac
}

assert_system_dep_not_global_prefix()
{
  local module="$1" variable value

  for variable in prefix libdir pkgdatadir bindir; do
    value="$(pkg-config --variable="$variable" "$module" 2>/dev/null || true)"
    case "$value" in
      "$DEP_PREFIX"|"$DEP_PREFIX"/*) return 0 ;;
      "$PREFIX"|"$PREFIX"/*) die "$module resolves through global $PREFIX instead of private $DEP_PREFIX" ;;
    esac
  done
}

fallback_system_dep_current()
{
  local module="$1" minimum="$2" probe="$3" have

  have="$(pkg_version "$module")"
  version_ge "$have" "$minimum" &&
    probe_system_dep "$probe" &&
    system_dep_probe_is_private "$probe" "$module"
}

system_dep_current()
{
  local name="$1" module="$2" minimum="$3" probe="$4"
  local host_have

  host_have="$(host_pkg_version "$module")"

  if version_ge "$host_have" "$minimum" && host_probe_system_dep "$probe"; then
    if [ "$name" = libinput ]; then
      assert_usable_libinput host
    fi
    return 0
  fi

  fallback_system_dep_current "$module" "$minimum" "$probe"
}

assert_usable_libinput()
{
  local mode="${1:-active}" libdir library symbol

  if [ "$mode" = host ]; then
    libdir="$(host_pkgconfig_libdir_realpath libinput 2>/dev/null || true)"
  else
    libdir="$(pkgconfig_libdir_realpath libinput 2>/dev/null || true)"
  fi
  [ -n "$libdir" ] || die "libinput library directory missing"

  library="$libdir/libinput.so"

  if [ ! -e "$library" ]; then
    library="$(
      find "$libdir" -maxdepth 1 -type f -name 'libinput.so.*' -print 2>/dev/null |
        LC_ALL=C sort -V |
        tail -n1
    )"
  fi

  [ -e "$library" ] || die "libinput shared library missing"

  for symbol in \
    libinput_tablet_tool_config_eraser_button_set_mode \
    libinput_tablet_tool_config_eraser_button_get_default_button \
    libinput_tablet_tool_config_eraser_button_set_button
  do
    readelf -Ws "$library" 2>/dev/null |
      awk -v wanted="$symbol" '
        $8 == wanted { found=1 }
        END { exit found ? 0 : 1 }
      ' || die "libinput missing required symbol: $symbol"
  done
}

validate_system_deps()
{
  local line name url ref module minimum builder flags probe have

  for line in "${SYSTEM_DEPS[@]}"; do
    IFS='|' read -r name url ref module minimum builder flags probe <<<"$line"
    : "$url" "$ref" "$builder" "$flags"

    system_dep_current "$name" "$module" "$minimum" "$probe" ||
      die "$module dependency is not satisfied by host or private fallback"

    assert_system_dep_not_global_prefix "$module"

    have="$(pkg_version "$module")"
    version_ge "$have" "$minimum" ||
      die "$module ${have:-missing} is below $minimum"

    probe_system_dep "$probe" ||
      die "$name dependency probe failed"

    if [ "$name" = libinput ]; then
      assert_usable_libinput
    fi

    if manifest_present "_dep_$name"; then
      validate_library_family "_dep_$name"
    fi
  done

  return 0
}

ensure_system_deps()
{
  local line name url ref module minimum builder flags probe have host_have key stage

  for line in "${SYSTEM_DEPS[@]}"; do
    IFS='|' read -r name url ref module minimum builder flags probe <<<"$line"

    host_have="$(host_pkg_version "$module")"

    if version_ge "$host_have" "$minimum" && host_probe_system_dep "$probe"; then
      if [ "$name" = libinput ]; then
        assert_usable_libinput host
      fi
      remove_component "_dep_$name"
      prune_library_family "_dep_$name"
      continue
    fi

    if fallback_system_dep_current "$module" "$minimum" "$probe"; then
      if [ "$name" = libinput ]; then
        assert_usable_libinput
      fi
      continue
    fi

    key="$(system_dep_key "$name")"

    if stage_current "$name" "$key"; then
      install_stage "_dep_$name" "$(stage_path "$name")" "$key"
    else
      if [ "$builder" = lua-release ]; then
        ensure_archive_source "$name" "$url" "$flags"
      else
        ensure_repo "$name" "$url" "$ref"
      fi

      build_to_stage "$name" "$builder" "$flags" "$key" "$DEP_PREFIX"
      stage="$(stage_path "$name")"
      install_stage "_dep_$name" "$stage" "$key"
    fi

    have="$(pkg_version "$module")"

    version_ge "$have" "$minimum" ||
      die "$module ${have:-missing} is below $minimum"

    probe_system_dep "$probe" ||
      die "$name dependency probe failed"

    if [ "$name" = libinput ]; then
      assert_usable_libinput
    fi
  done

  return 0
}
