stage_path()
{
  printf '%s/%s' "$STAGE_DIR" "$(safe_name "$1")"
}

stage_key_path()
{
  printf '%s/.keys/%s.key' "$STAGE_DIR" "$(safe_name "$1")"
}

build_key_path()
{
  printf '%s/%s/.hypr-builder-key' "$BUILD_DIR" "$1"
}

build_logic_hash()
{
  sha256sum "$HYPR_BUILDER_ROOT/lib/build.sh" | awk '{print $1}'
}

system_dep_key()
{
  local wanted="$1" line name

  for line in "${SYSTEM_DEPS[@]}"; do
    IFS='|' read -r name _ <<<"$line"
    if [ "$name" = "$wanted" ]; then
      {
        printf '%s\n' "$(toolchain_fingerprint)"
        printf '%s\n' "$PREFIX"
        printf '%s\n' "$DEP_PREFIX"
        printf '%s\n' "$(build_logic_hash)"
        printf '%s\n' "$line"
      } | sha256sum | awk '{print $1}'
      return 0
    fi
  done

  return 1
}

component_key()
{
  local wanted="$1" line name found=0

  {
    printf '%s\n' "$(toolchain_fingerprint)"
    printf '%s\n' "$PREFIX"
    printf '%s\n' "$DEP_PREFIX"
    printf '%s\n' "$(build_logic_hash)"
    printf '%s\n' "${SYSTEM_DEPS[@]}"
    system_dep_resolution_fingerprint

    for line in "${REPOS[@]}"; do
      printf '%s\n' "$line"
      IFS='|' read -r name _ <<<"$line"
      if [ "$name" = "$wanted" ]; then
        found=1
        break
      fi
    done

    [ "$found" -eq 1 ] || return 1
  } | sha256sum | awk '{print $1}'
}

system_dep_resolution_fingerprint()
{
  local line name module version libdir bindir

  for line in "${SYSTEM_DEPS[@]}"; do
    IFS='|' read -r name _ _ module _ _ _ _ <<<"$line"
    version="$(pkg_version "$module")"
    libdir="$(pkgconfig_libdir_realpath "$module" 2>/dev/null || true)"
    bindir="$(pkg-config --variable=bindir "$module" 2>/dev/null || true)"
    printf '%s|%s|%s|%s\n' "$name" "$version" "$libdir" "$bindir"
  done
}

build_current()
{
  local marker
  marker="$(build_key_path "$1")"
  [ -f "$marker" ] && [ "$(cat "$marker")" = "$2" ]
}

stage_current()
{
  local stage marker
  stage="$(stage_path "$1")"
  marker="$(stage_key_path "$1")"

  [ -f "$marker" ] &&
    [ "$(cat "$marker")" = "$2" ] &&
    [ -d "$stage" ] &&
    [ -n "$(find "$stage" -mindepth 1 -print -quit 2>/dev/null)" ]
}

probe_component()
{
  case "$1" in
    pc:*) pkg-config --exists "${1#pc:}" ;;
    path:*) [ -e "${1#path:}" ] || [ -L "${1#path:}" ] ;;
    bin:*) command -v "${1#bin:}" >/dev/null 2>&1 ;;
    *) die "unknown probe: $1" ;;
  esac
}

installed_current()
{
  local key_file
  key_file="$(installed_key_path "$1")"

  [ -f "$key_file" ] &&
    [ "$(cat "$key_file")" = "$2" ] &&
    manifest_present "$1" &&
    probe_component "$3"
}

managed_pkgconfig_libraries()
{
  cat <<'MAP'
libinput|input
xkbcommon|xkbcommon
hyprutils|hyprutils
hyprlang|hyprlang
hyprgraphics|hyprgraphics
hyprcursor|hyprcursor
aquamarine|aquamarine
hyprwire|hyprwire
hyprtoolkit|hyprtoolkit
MAP
}

pkgconfig_shared_library_path()
{
  local module="$1" library="$2"
  local libdir candidate resolved

  libdir="$(pkgconfig_libdir_realpath "$module" 2>/dev/null || true)"
  [ -n "$libdir" ] || die "cannot resolve pkg-config libdir for $module"

  for candidate in \
    "$libdir/lib${library}.so" \
    "$libdir/lib${library}.so."*
  do
    [ -e "$candidate" ] || continue
    resolved="$(readlink -f "$candidate" 2>/dev/null || true)"
    [ -n "$resolved" ] && [ -f "$resolved" ] || continue
    printf '%s' "$resolved"
    return 0
  done

  die "$module pkg-config points at $libdir, but no lib${library}.so exists there"
}

cmake_cached_pkg_library_entries()
{
  local build="$1" library="$2"
  local cache="$build/CMakeCache.txt"

  [ -f "$cache" ] || return 0

  awk -F= -v library="$library" '
    /^pkgcfg_lib_/ {
      key = $1
      sub(/:[^:]*$/, "", key)
      if (key ~ ("_" library "$")) {
        print key "|" substr($0, index($0, "=") + 1)
      }
    }
  ' "$cache"
}

cmake_cached_pkg_library_paths()
{
  cmake_cached_pkg_library_entries "$1" "$2" | cut -d'|' -f2-
}

cmake_managed_pkg_override_args()
{
  local build="$1"
  local module library entries expected key current

  while IFS='|' read -r module library; do
    [ -n "$module" ] && [ -n "$library" ] || continue

    entries="$(cmake_cached_pkg_library_entries "$build" "$library")"
    [ -n "$entries" ] || continue

    expected="$(pkgconfig_shared_library_path "$module" "$library")"

    while IFS='|' read -r key current; do
      [ -n "$key" ] || continue
      printf -- '-D%s:FILEPATH=%s\n' "$key" "$expected"
    done <<<"$entries"
  done < <(managed_pkgconfig_libraries)
}

assert_cmake_pkg_library_matches_pkgconfig()
{
  local name="$1" build="$2" module="$3" library="$4"
  local required="${5:-0}"
  local expected_dir path resolved
  local -a paths=()

  mapfile -t paths < <(cmake_cached_pkg_library_paths "$build" "$library")

  if [ "${#paths[@]}" -eq 0 ]; then
    if [ "$required" -ne 0 ]; then
      die "$name did not resolve required pkg-config library: $library"
    fi
    return 0
  fi

  expected_dir="$(pkgconfig_libdir_realpath "$module" 2>/dev/null || true)"
  [ -n "$expected_dir" ] || die "$name cannot resolve pkg-config libdir for $module"

  for path in "${paths[@]}"; do
    case "$path" in
      ''|*-NOTFOUND)
        die "$name resolved invalid pkg-config library: $library => $path"
        ;;
    esac

    resolved="$(readlink -f "$path" 2>/dev/null || true)"
    [ -n "$resolved" ] || die "$name resolved missing library: $path"

    [ "$(dirname "$resolved")" = "$expected_dir" ] ||
      die "$name mixed $module headers and libraries: pkg-config=$expected_dir, CMake=$resolved"
  done
}

assert_component_dependency_resolution()
{
  local name="$1" build="$2"
  local module library

  if [ "$name" = Hyprland ]; then
    assert_usable_libinput
    assert_cmake_pkg_library_matches_pkgconfig "$name" "$build" libinput input 1
    assert_cmake_pkg_library_matches_pkgconfig "$name" "$build" xkbcommon xkbcommon 1
  fi

  while IFS='|' read -r module library; do
    [ -n "$module" ] && [ -n "$library" ] || continue

    if [ -n "$(cmake_cached_pkg_library_paths "$build" "$library")" ]; then
      assert_cmake_pkg_library_matches_pkgconfig "$name" "$build" "$module" "$library"
    fi
  done < <(managed_pkgconfig_libraries)
}

prepare_stage()
{
  local stage
  stage="$(stage_path "$1")"
  rm -rf "$stage"
  mkdir -p "$stage"
  printf '%s' "$stage"
}

cmake_build()
{
  local name="$1" flags="$2" key="$3" install_prefix="$4"
  local src="$SRC_DIR/$name" build="$BUILD_DIR/$name" stage
  local -a extra=()
  local -a configure_args=()
  local -a override_args=()

  if [ -n "$flags" ]; then
    read -r -a extra <<<"$flags"
  fi

  if ! build_current "$name" "$key"; then
    rm -rf "$build"
    mkdir -p "$build"
  fi

  configure_args=(
    --no-warn-unused-cli
    -G Ninja
    -S "$src"
    -B "$build"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="$install_prefix"
    -DCMAKE_INSTALL_LIBDIR=lib
    -DCMAKE_INSTALL_LIBEXECDIR=libexec
    -DCMAKE_C_COMPILER="$CC"
    -DCMAKE_CXX_COMPILER="$CXX"
    -DCMAKE_CXX_FLAGS=-Wno-clobbered
    -DCMAKE_EXE_LINKER_FLAGS="$TOOLCHAIN_LINK_FLAGS"
    -DCMAKE_SHARED_LINKER_FLAGS="$TOOLCHAIN_LINK_FLAGS"
    -DCMAKE_MODULE_LINKER_FLAGS="$TOOLCHAIN_LINK_FLAGS"
    -DCMAKE_BUILD_RPATH="$TOOLCHAIN_CMAKE_RPATH"
    -DCMAKE_INSTALL_RPATH="$TOOLCHAIN_CMAKE_RPATH"
    -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=OFF
    -DCMAKE_PREFIX_PATH="$DEP_PREFIX;$PREFIX"
    -DCMAKE_LIBRARY_PATH="$DEP_PREFIX/lib;$PREFIX/lib"
    -DCMAKE_INCLUDE_PATH="$DEP_PREFIX/include;$PREFIX/include"
    -DPKG_CONFIG_USE_CMAKE_PREFIX_PATH=ON
    -DBUILD_TESTING=OFF
    -DINSTALL_TESTS=OFF
    "${extra[@]}"
  )

  PKG_CONFIG_ALLOW_SYSTEM_LIBS=1 cmake \
    -U '__pkg_config_checked_*' \
    -U 'pkgcfg_lib_*' \
    "${configure_args[@]}"

  mapfile -t override_args < <(cmake_managed_pkg_override_args "$build")

  if [ "${#override_args[@]}" -gt 0 ]; then
    info "pin managed libraries for $name"
    PKG_CONFIG_ALLOW_SYSTEM_LIBS=1 cmake \
      "${override_args[@]}" \
      "${configure_args[@]}"
  fi

  assert_component_dependency_resolution "$name" "$build"

  mkdir -p "$(dirname "$(build_key_path "$name")")"
  printf '%s\n' "$key" >"$(build_key_path "$name")"

  info "compile $name"
  cmake --build "$build" --parallel "$(jobs)"

  rm -f "$build/install_manifest.txt" 2>/dev/null ||
    as_root rm -f "$build/install_manifest.txt"

  stage="$(prepare_stage "$name")"
  DESTDIR="$stage" cmake --install "$build"

  mkdir -p "$(dirname "$(stage_key_path "$name")")"
  printf '%s\n' "$key" >"$(stage_key_path "$name")"
}

meson_build()
{
  local name="$1" flags="$2" key="$3" install_prefix="$4"
  local src="$SRC_DIR/$name" build="$BUILD_DIR/$name" stage
  local -a extra=()

  if [ -n "$flags" ]; then
    read -r -a extra <<<"$flags"
  fi

  if build_current "$name" "$key"; then
    CC="$CC" CXX="$CXX" LDFLAGS="$TOOLCHAIN_LINK_FLAGS" \
      meson setup --reconfigure "$build" "$src" \
      --prefix="$install_prefix" \
      --libdir=lib \
      --buildtype=release \
      "${extra[@]}"
  else
    rm -rf "$build"
    CC="$CC" CXX="$CXX" LDFLAGS="$TOOLCHAIN_LINK_FLAGS" \
      meson setup "$build" "$src" \
      --prefix="$install_prefix" \
      --libdir=lib \
      --buildtype=release \
      "${extra[@]}"
  fi

  mkdir -p "$(dirname "$(build_key_path "$name")")"
  printf '%s\n' "$key" >"$(build_key_path "$name")"

  info "compile $name"
  meson compile -C "$build" -j"$(jobs)"

  stage="$(prepare_stage "$name")"
  DESTDIR="$stage" meson install -C "$build" --no-rebuild

  mkdir -p "$(dirname "$(stage_key_path "$name")")"
  printf '%s\n' "$key" >"$(stage_key_path "$name")"
}

lua_build()
{
  local name="$1" key="$2" install_prefix="$3"
  local src="$SRC_DIR/$name" stage

  if ! build_current "$name" "$key"; then
    make -C "$src" clean >/dev/null 2>&1 || true
  fi

  [ -f "$src/Makefile" ] || die "Lua Makefile missing"

  info "compile $name"
  make -C "$src" -j"$(jobs)" all \
    CC="$CC" \
    MYCFLAGS='-fPIC -DLUA_USE_LINUX' \
    MYLDFLAGS="$TOOLCHAIN_LINK_FLAGS" \
    MYLIBS='-ldl'

  [ -x "$src/src/lua" ] || die "Lua interpreter was not built"
  [ -x "$src/src/luac" ] || die "Lua compiler was not built"
  [ -f "$src/src/liblua.a" ] || die "Lua library was not built"

  mkdir -p "$(dirname "$(build_key_path "$name")")"
  printf '%s\n' "$key" >"$(build_key_path "$name")"

  stage="$(prepare_stage "$name")"
  install -d \
    "$stage$install_prefix/bin" \
    "$stage$install_prefix/include/lua5.5" \
    "$stage$install_prefix/lib/pkgconfig"

  install -m 0755 "$src/src/lua" "$stage$install_prefix/bin/lua5.5"
  install -m 0755 "$src/src/luac" "$stage$install_prefix/bin/luac5.5"
  install -m 0644 "$src/src/liblua.a" "$stage$install_prefix/lib/liblua5.5.a"
  install -m 0644 \
    "$src/src/lua.h" \
    "$src/src/luaconf.h" \
    "$src/src/lauxlib.h" \
    "$src/src/lualib.h" \
    "$stage$install_prefix/include/lua5.5/"

  cat >"$stage$install_prefix/include/lua5.5/lua.hpp" <<'HPP'
#ifndef LUA_HPP
#define LUA_HPP
extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
}
#endif
HPP

cat >"$stage$install_prefix/lib/pkgconfig/lua5.5.pc" <<EOF
prefix=$install_prefix
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include/lua5.5
Name: Lua
Description: Lua 5.5 language engine
Version: 5.5.0
Libs: -L\${libdir} -llua5.5 -lm -ldl
Cflags: -I\${includedir}
EOF

  mkdir -p "$(dirname "$(stage_key_path "$name")")"
  printf '%s\n' "$key" >"$(stage_key_path "$name")"
}

build_to_stage()
{
  local install_prefix="${5:-$PREFIX}"

  case "$2" in
    cmake) cmake_build "$1" "$3" "$4" "$install_prefix" ;;
    meson) meson_build "$1" "$3" "$4" "$install_prefix" ;;
    lua-release) lua_build "$1" "$4" "$install_prefix" ;;
    *) die "unknown builder: $2" ;;
  esac
}
