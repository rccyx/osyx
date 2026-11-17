GCC_VERSION="16.1.0"
GCC_URL="https://sourceware.org/pub/gcc/releases/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz"
GCC_SHA512="b3454958891ab47e1e5b6cb9396c0ad3b04f32fe2a7bf1153a143f21013fdb6b295ca94c98964698a688e4c1d7555ffd8ffbc20187507cce6b1c32cbcc09897a"

INSTALL_DIR="/usr/local/lib/gccyx"
LINK_DIR="/usr/local/bin"
LD_CONF="/etc/ld.so.conf.d/gccyx.conf"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/gcc-builder"
ARCHIVE="$CACHE_DIR/gcc.tar.xz"
SOURCE_DIR="$CACHE_DIR/source"
BUILD_DIR="$CACHE_DIR/build"
STAGE_DIR="$CACHE_DIR/stage"

GCC_FLAGS=(
  --enable-languages=c,c++
  --disable-bootstrap
  --disable-multilib
  --disable-nls
  --disable-libsanitizer
  --disable-libstdcxx-pch
  --disable-werror
  --with-system-zlib
)

PACKAGES=(
  build-essential bison flex gawk make texinfo
  ca-certificates curl xz-utils
  libgmp-dev libmpfr-dev libmpc-dev libisl-dev zlib1g-dev libzstd-dev
)
