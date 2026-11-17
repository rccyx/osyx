build_key()
{
  local cc cxx
  cc="$(bootstrap_cc)"
  cxx="$(bootstrap_cxx)"

  {
    printf '%s\n' "$GCC_SHA512" "$INSTALL_DIR"
    printf '%s\n' "${GCC_FLAGS[@]}"
    sha256sum "$root/config.sh" "$root/lib/build.sh"
    "$cc" -dumpfullversion -dumpversion 2>/dev/null || true
    "$cxx" -dumpfullversion -dumpversion 2>/dev/null || true
  } | sha256sum | awk '{print $1}'
}

compiler_probe()
{
  local cxx="${1:-$INSTALL_DIR/bin/g++}"
  [ -x "$cxx" ] || return 1

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
  const std::string_view leaf{"gcc"};
  return embedded[0] == 'o' && output.size() == 5 && root + leaf == "/tmp/gcc" ? 0 : 1;
}
CPP

  if ! (cd "$dir" && "$cxx" -std=gnu++26 probe.cpp -o probe && ./probe); then
    rm -rf "$dir"
    return 1
  fi

  rm -rf "$dir"
}

compiler_installed()
{
  [ -x "$INSTALL_DIR/bin/gcc" ] || return 1
  [ -x "$INSTALL_DIR/bin/g++" ] || return 1
  [ "$(readlink -f "$LINK_DIR/gcc" 2>/dev/null || true)" = "$INSTALL_DIR/bin/gcc" ] || return 1
  [ "$(readlink -f "$LINK_DIR/g++" 2>/dev/null || true)" = "$INSTALL_DIR/bin/g++" ] || return 1
  [ "$($INSTALL_DIR/bin/gcc -dumpfullversion -dumpversion 2>/dev/null)" = "$GCC_VERSION" ] || return 1
  [ "$($INSTALL_DIR/bin/g++ -dumpfullversion -dumpversion 2>/dev/null)" = "$GCC_VERSION" ] || return 1
  compiler_probe "$INSTALL_DIR/bin/g++"
}

archive_current()
{
  [ -f "$ARCHIVE" ] && printf '%s  %s\n' "$GCC_SHA512" "$ARCHIVE" | sha512sum -c - >/dev/null 2>&1
}

source_current()
{
  [ -f "$SOURCE_DIR/.sha512" ] && [ "$(cat "$SOURCE_DIR/.sha512")" = "$GCC_SHA512" ]
}

build_current()
{
  [ -f "$BUILD_DIR/.key" ] && [ "$(cat "$BUILD_DIR/.key")" = "$(build_key)" ]
}

stage_current()
{
  [ -f "$STAGE_DIR/.key" ] || return 1
  [ "$(cat "$STAGE_DIR/.key")" = "$(build_key)" ] || return 1
  [ -x "$STAGE_DIR$INSTALL_DIR/bin/gcc" ] || return 1
  [ -x "$STAGE_DIR$INSTALL_DIR/bin/g++" ]
}

ensure_source()
{
  mkdir -p "$CACHE_DIR"

  if ! archive_current; then
    info download "gcc $GCC_VERSION"
    rm -f "$ARCHIVE" "$ARCHIVE.tmp"
    curl -fL --retry 3 "$GCC_URL" -o "$ARCHIVE.tmp"
    printf '%s  %s\n' "$GCC_SHA512" "$ARCHIVE.tmp" | sha512sum -c - >/dev/null || fail "gcc checksum failed"
    mv "$ARCHIVE.tmp" "$ARCHIVE"
  fi

  if source_current; then
    return 0
  fi

  info extract "gcc $GCC_VERSION"
  rm -rf "$SOURCE_DIR" "$BUILD_DIR" "$STAGE_DIR"
  mkdir -p "$SOURCE_DIR"
  tar -xf "$ARCHIVE" --strip-components=1 -C "$SOURCE_DIR"
  printf '%s\n' "$GCC_SHA512" >"$SOURCE_DIR/.sha512"
}

compile_gcc()
{
  local key
  key="$(build_key)"

  if ! build_current; then
    info configure "gcc $GCC_VERSION"
    rm -rf "$BUILD_DIR" "$STAGE_DIR"
    mkdir -p "$BUILD_DIR"
    (
      cd "$BUILD_DIR"
      CC="$(bootstrap_cc)" CXX="$(bootstrap_cxx)" \
        "$SOURCE_DIR/configure" \
          --prefix="$INSTALL_DIR" \
          --libdir="$INSTALL_DIR/lib" \
          --libexecdir="$INSTALL_DIR/libexec" \
          "${GCC_FLAGS[@]}"
    )
    printf '%s\n' "$key" >"$BUILD_DIR/.key"
  else
    info cache "gcc build"
  fi

  info compile "gcc $GCC_VERSION"
  make -C "$BUILD_DIR" -j"$(jobs)"

  info stage "gcc $GCC_VERSION"
  rm -rf "$STAGE_DIR"
  mkdir -p "$STAGE_DIR"
  make -C "$BUILD_DIR" DESTDIR="$STAGE_DIR" install-strip
  rm -f "$STAGE_DIR$INSTALL_DIR/share/info/dir"
  printf '%s\n' "$key" >"$STAGE_DIR/.key"
}

install_gcc()
{
  local staged="$STAGE_DIR$INSTALL_DIR"
  [ -x "$staged/bin/gcc" ] || fail "staged gcc missing"
  [ -x "$staged/bin/g++" ] || fail "staged g++ missing"

  info install "gcc $GCC_VERSION"
  as_root rm -rf "$INSTALL_DIR"
  as_root mkdir -p "$(dirname "$INSTALL_DIR")" "$LINK_DIR"
  as_root cp -a "$staged" "$INSTALL_DIR"

  as_root rm -f "$LINK_DIR/gcc" "$LINK_DIR/g++"
  as_root ln -s "$INSTALL_DIR/bin/gcc" "$LINK_DIR/gcc"
  as_root ln -s "$INSTALL_DIR/bin/g++" "$LINK_DIR/g++"

  printf '%s\n' "$INSTALL_DIR/lib" | as_root tee "$LD_CONF" >/dev/null
  as_root ldconfig
  hash -r 2>/dev/null || true
}

remove_installation()
{
  local path target

  for path in "$LINK_DIR/gcc" "$LINK_DIR/g++"; do
    target="$(readlink -f "$path" 2>/dev/null || true)"
    case "$target" in
      "$INSTALL_DIR"/*) as_root rm -f "$path" ;;
    esac
  done

  as_root rm -rf "$INSTALL_DIR"
  as_root rm -f "$LD_CONF"
  as_root ldconfig
  hash -r 2>/dev/null || true

  [ ! -e "$INSTALL_DIR" ] || fail "failed to remove $INSTALL_DIR"
  [ "$(readlink -f "$LINK_DIR/gcc" 2>/dev/null || true)" != "$INSTALL_DIR/bin/gcc" ] || fail "failed to remove gcc link"
  [ "$(readlink -f "$LINK_DIR/g++" 2>/dev/null || true)" != "$INSTALL_DIR/bin/g++" ] || fail "failed to remove g++ link"
}
