repo_is_commit()
{
  [[ "$1" =~ ^[0-9a-fA-F]{40}$ ]]
}

reset_repo()
{
  local dir="$1"

  git -C "$dir" reset --hard -q HEAD
  git -C "$dir" clean -ffdqx
  git -C "$dir" submodule sync --recursive >/dev/null 2>&1 || true
  git -C "$dir" submodule update --init --recursive --force >/dev/null 2>&1 ||
    die "failed to restore submodules in $dir"
  git -C "$dir" submodule foreach --recursive \
    'git reset --hard -q HEAD && git clean -ffdqx' >/dev/null 2>&1 || true
}

assert_repo_pristine()
{
  local name="$1" ref="$2"
  local dir="$SRC_DIR/$name" head

  head="$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)"

  if repo_is_commit "$ref"; then
    [ "$head" = "$ref" ] || die "$name source is at ${head:-missing}, expected $ref"
  else
    [ -n "$head" ] || die "$name source has no checked-out commit"
  fi

  git -C "$dir" diff --quiet --ignore-submodules=none ||
    die "$name source contains tracked modifications"
  git -C "$dir" diff --cached --quiet --ignore-submodules=none ||
    die "$name source contains staged modifications"

  [ -z "$(git -C "$dir" status --porcelain --untracked-files=all 2>/dev/null)" ] ||
    die "$name source is not pristine"
}

ensure_repo()
{
  local name="$1" url="$2" ref="$3"
  local dir="$SRC_DIR/$name" marker expected head=""

  if [ ! -d "$dir/.git" ]; then
    info "clone $name"
    git clone --filter=blob:none --no-checkout "$url" "$dir" >/dev/null 2>&1 ||
      git clone --no-checkout "$url" "$dir" >/dev/null
  fi

  marker="$dir/.git/hypr-builder-ref"
  expected="$url|$ref"
  head="$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)"

  if repo_is_commit "$ref" && [ "$head" = "$ref" ]; then
    reset_repo "$dir"
    assert_repo_pristine "$name" "$ref"
    return 0
  fi

  if ! repo_is_commit "$ref" &&
     [ -f "$marker" ] &&
     [ "$(cat "$marker")" = "$expected" ] &&
     [ -n "$head" ]; then
    reset_repo "$dir"
    assert_repo_pristine "$name" "$ref"
    return 0
  fi

  info "fetch $name $ref"
  git -C "$dir" remote set-url origin "$url"
  git -C "$dir" fetch --force --prune --depth=1 origin "$ref" >/dev/null 2>&1 ||
    git -C "$dir" fetch --force --prune origin "$ref" >/dev/null

  git -C "$dir" checkout --detach --force -q FETCH_HEAD
  git -C "$dir" submodule sync --recursive >/dev/null 2>&1 || true
  git -C "$dir" submodule update --init --recursive --force --depth=1 >/dev/null 2>&1 ||
    git -C "$dir" submodule update --init --recursive --force >/dev/null 2>&1

  head="$(git -C "$dir" rev-parse HEAD)"
  if repo_is_commit "$ref" && [ "$head" != "$ref" ]; then
    die "$name checked out $head, expected $ref"
  fi

  printf '%s\n' "$expected" >"$marker"
  reset_repo "$dir"
  assert_repo_pristine "$name" "$ref"
}

ensure_archive_source()
{
  local name="$1" url="$2" checksum="$3"
  local archive="$CACHE_DIR/downloads/$name.tar.gz"
  local dir="$SRC_DIR/$name"

  mkdir -p "$CACHE_DIR/downloads"

  if [ ! -f "$archive" ] ||
     ! printf '%s  %s\n' "$checksum" "$archive" | sha256sum -c - >/dev/null 2>&1; then
    info "download $name"
    rm -f "$archive" "$archive.tmp"
    curl -fL --retry 3 "$url" -o "$archive.tmp"
    printf '%s  %s\n' "$checksum" "$archive.tmp" | sha256sum -c - >/dev/null ||
      die "$name checksum failed"
    mv "$archive.tmp" "$archive"
  fi

  if [ -f "$dir/.sha256" ] && [ "$(cat "$dir/.sha256")" = "$checksum" ]; then
    return 0
  fi

  rm -rf "$dir"
  mkdir -p "$dir"
  tar -xzf "$archive" --strip-components=1 -C "$dir"
  printf '%s\n' "$checksum" >"$dir/.sha256"
}
