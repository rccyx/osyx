#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/stage-cache.sh"

_test_install()
{
  local builder="$1"
  printf '\nTesting %s\n' "$builder"
  "./$builder/main" plan
  "./$builder/main" apply --yes
  "./$builder/main" doctor
  "./$builder/main" plan
  "./$builder/main" apply --yes
  "./$builder/main" doctor
}

_assert_removed()
{
  local path
  while IFS= read -r path; do
    if [ -e "$path" ] || [ -L "$path" ]; then
      printf 'reset left %s\n' "$path" >&2
      return 1
    fi
  done
}

restore_stages
trap save_stages EXIT

_test_install gcc-builder
_test_install hypr-builder

owned_files="$(mktemp)"
cat "$HOME"/.local/state/hypr-builder/manifests/*.files > "$owned_files"
test -s "$owned_files"

save_stages
./hypr-builder/main reset --yes
_assert_removed < "$owned_files"
printf '%s\n' \
  "$HOME/.cache/hypr-builder" \
  "$HOME/.local/state/hypr-builder" | _assert_removed

./gcc-builder/main doctor
./gcc-builder/main reset --yes
printf '%s\n' \
  /usr/local/lib/gccyx \
  /usr/local/bin/gcc \
  /usr/local/bin/g++ \
  /etc/ld.so.conf.d/gccyx.conf \
  "$HOME/.cache/gcc-builder" | _assert_removed
