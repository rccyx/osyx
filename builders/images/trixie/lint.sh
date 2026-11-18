#!/usr/bin/env bash
set -euo pipefail

for builder in gcc-builder hypr-builder; do
  bash -n "$builder/main"
  for source in "$builder/config.sh" "$builder"/lib/*.sh; do
    bash -n "$source"
  done
  shellcheck -x -P "$builder" "$builder/main"
done

for script in /usr/local/lib/builders-tests/*.sh; do
  bash -n "$script"
  shellcheck -x -P SCRIPTDIR "$script"
done
