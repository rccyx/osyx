compiler_is_gnu()
{
  printf '\n' | "$1" -dM -E -x "$2" - 2>/dev/null |
    awk '$1 == "#define" && $2 == "__GNUC__" { found=1 } END { exit found ? 0 : 1 }'
}

compiler_probe()
{
  local dir
  dir="$(mktemp -d)"
  printf 'ok\n' >"$dir/embed.txt"

  cat >"$dir/probe.cpp" <<'CPP'
#include <algorithm>
#include <array>
#include <string>
#include <string_view>
#include <vector>

static constexpr unsigned char embedded[] = {
#embed "embed.txt"
};

int main()
{
  constexpr std::array values{1, 2, 3};
  constexpr std::array prefix{1, 2};
  static_assert(std::ranges::starts_with(values, prefix));

  std::vector<int> output{1};
  const std::array<int, 2> input{2, 3};
  output.append_range(input);
  output.insert_range(output.end(), input);

  const std::string root{"/tmp/"};
  const std::string_view leaf{"hyprland"};

  return embedded[0] == 'o' &&
         output.size() == 5 &&
         root + leaf == "/tmp/hyprland" ? 0 : 1;
}
CPP

  if ! (
    cd "$dir" &&
    "$CXX" -std=gnu++26 "${TOOLCHAIN_LINK_ARGS[@]}" probe.cpp -o probe &&
    ./probe
  ); then
    rm -rf "$dir"
    return 1
  fi

  rm -rf "$dir"
}

choose_compilers()
{
  hash -r

  CC="$(type -P gcc 2>/dev/null || true)"
  CXX="$(type -P g++ 2>/dev/null || true)"

  [ -x "$CC" ] || die "gcc is not available through PATH"
  [ -x "$CXX" ] || die "g++ is not available through PATH"

  compiler_is_gnu "$CC" c || die "gcc is not GNU GCC: $CC"
  compiler_is_gnu "$CXX" c++ || die "g++ is not GNU G++: $CXX"

  local cc_version cxx_version cc_target cxx_target libstdcxx libgcc dir
  cc_version="$("$CC" -dumpfullversion -dumpversion)"
  cxx_version="$("$CXX" -dumpfullversion -dumpversion)"
  [ "$cc_version" = "$cxx_version" ] || die "gcc and g++ versions differ"

  cc_target="$("$CC" -dumpmachine)"
  cxx_target="$("$CXX" -dumpmachine)"
  [ "$cc_target" = "$cxx_target" ] || die "gcc and g++ targets differ"

  libstdcxx="$("$CXX" -print-file-name=libstdc++.so.6)"
  libgcc="$("$CC" -print-file-name=libgcc_s.so.1)"

  TOOLCHAIN_LIBSTDCXX="$(readlink -f "$libstdcxx" 2>/dev/null || true)"
  TOOLCHAIN_LIBGCC="$(readlink -f "$libgcc" 2>/dev/null || true)"

  [ -f "$TOOLCHAIN_LIBSTDCXX" ] || die "g++ cannot resolve libstdc++.so.6"
  [ -f "$TOOLCHAIN_LIBGCC" ] || die "gcc cannot resolve libgcc_s.so.1"

  TOOLCHAIN_RUNTIME_DIRS=()
  for dir in \
    "$(dirname "$TOOLCHAIN_LIBSTDCXX")" \
    "$(dirname "$TOOLCHAIN_LIBGCC")" \
    "$DEP_PREFIX/lib" \
    "$PREFIX/lib"
  do
    local found=0 existing
    for existing in "${TOOLCHAIN_RUNTIME_DIRS[@]}"; do
      if [ "$existing" = "$dir" ]; then
        found=1
        break
      fi
    done
    [ "$found" -eq 1 ] || TOOLCHAIN_RUNTIME_DIRS+=("$dir")
  done

  TOOLCHAIN_CMAKE_RPATH="$(IFS=';'; printf '%s' "${TOOLCHAIN_RUNTIME_DIRS[*]}")"
  TOOLCHAIN_LINK_ARGS=()

  for dir in "${TOOLCHAIN_RUNTIME_DIRS[@]}"; do
    TOOLCHAIN_LINK_ARGS+=("-Wl,-rpath,$dir")
  done

  TOOLCHAIN_LINK_FLAGS="${TOOLCHAIN_LINK_ARGS[*]}"

  export CC CXX
  export TOOLCHAIN_LIBSTDCXX TOOLCHAIN_LIBGCC
  export TOOLCHAIN_CMAKE_RPATH TOOLCHAIN_LINK_FLAGS

  compiler_probe || die "default GNU toolchain cannot build the pinned Hypr stack"
}

toolchain_fingerprint()
{
  {
    printf 'cc=%s\n' "$(readlink -f "$CC")"
    printf 'cxx=%s\n' "$(readlink -f "$CXX")"
    sha256sum \
      "$(readlink -f "$CC")" \
      "$(readlink -f "$CXX")" \
      "$TOOLCHAIN_LIBSTDCXX" \
      "$TOOLCHAIN_LIBGCC"
    "$CC" -dumpmachine
    "$CXX" -print-search-dirs
  } | sha256sum | awk '{print $1}'
}
