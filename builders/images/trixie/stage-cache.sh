#!/usr/bin/env bash

readonly STAGE_CACHE_DIR="$HOME/.local/share/builders-stage-cache"

restore_stages()
{
  _copy_stages "$STAGE_CACHE_DIR" "$HOME/.cache"
}

save_stages()
{
  _copy_stages "$HOME/.cache" "$STAGE_CACHE_DIR"
}

_copy_stages()
{
  local source_root="$1" target_root="$2" builder
  for builder in gcc-builder hypr-builder; do
    [ -d "$source_root/$builder/stage" ] || continue
    mkdir -p "$target_root/$builder"
    rm -rf -- "$target_root/$builder/stage"
    cp -a "$source_root/$builder/stage" "$target_root/$builder/"
  done
}
