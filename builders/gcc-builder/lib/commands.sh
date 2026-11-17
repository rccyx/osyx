plan()
{
  local missing=()
  mapfile -t missing < <(missing_packages)
  [ "${#missing[@]}" -eq 0 ] || printf '[install] packages: %s\n' "${missing[*]}"

  if compiler_installed; then
    info cache "gcc installed"
  elif stage_current; then
    info cache "gcc stage"
  elif build_current; then
    info resume "gcc build"
  elif source_current; then
    info compile "gcc $GCC_VERSION"
  elif archive_current; then
    info extract "gcc $GCC_VERSION"
  else
    info download "gcc $GCC_VERSION"
  fi
}

apply()
{
  install_packages
  need curl
  need make
  need sha256sum
  need sha512sum
  need tar

  if compiler_installed; then
    info cache "gcc installed"
    return 0
  fi

  if ! stage_current; then
    ensure_source
    compile_gcc
  fi

  install_gcc
  compiler_installed || fail "gcc validation failed"
  info done "gcc"
}

doctor()
{
  printf 'gcc: %s\n' "$(readlink -f "$LINK_DIR/gcc" 2>/dev/null || printf missing)"
  printf 'g++: %s\n' "$(readlink -f "$LINK_DIR/g++" 2>/dev/null || printf missing)"
  compiler_installed || fail "gcc is not installed correctly"
  printf 'version: %s\n' "$($INSTALL_DIR/bin/gcc -dumpfullversion -dumpversion)"
  printf 'target: %s\n' "$($INSTALL_DIR/bin/gcc -dumpmachine)"
  info ok "c++26"
}

reset()
{
  remove_installation
  rm -rf "$CACHE_DIR"
  [ ! -e "$CACHE_DIR" ] || fail "failed to remove cache"
  info done "gcc reset"
}
