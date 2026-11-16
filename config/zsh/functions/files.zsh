files(){
    nautilus
}
#   - Requires: shred (coreutils), fzf. Uses fd if available for faster listing.
#   - On SSDs or journaled FS, secure deletion is not guaranteed. Consider full disk crypto.

shatter() {
  emulate -L zsh
  setopt ERR_RETURN PIPE_FAIL NO_NOMATCH

  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf not found. On Debian: sudo apt install fzf"
    return 1
  fi

  local -a targets
  if (( $# == 0 )); then
    local selection
    if command -v fd >/dev/null 2>&1; then
      selection=$(
        fd --hidden --follow --exclude .git --type f \
        | fzf --multi --height=80% --reverse \
              --prompt="shatter> " \
              --header="select files to destroy" \
              --preview 'stat --printf="Size: %s bytes\n" {} 2>/dev/null || stat -f "%z bytes" {}' \
              --preview-window=down:5:wrap
      ) || return 1
    else
      selection=$(
        find . -type f -not -path '*/.git/*' -print \
        | sed 's#^\./##' \
        | fzf --multi --height=80% --reverse \
              --prompt="shatter> " \
              --header="select files to destroy" \
              --preview 'stat --printf="Size: %s bytes\n" {} 2>/dev/null || stat -f "%z bytes" {}' \
              --preview-window=down:5:wrap
      ) || return 1
    fi
    [[ -z "$selection" ]] && return 1
    targets=("${(@f)selection}")
  else
    local p
    for p in "$@"; do
      if [[ -d "$p" ]]; then
        targets+=("${(@f)$(find "$p" -type f -not -path '*/.git/*')}")
      elif [[ -e "$p" ]]; then
        targets+=("$p")
      fi
    done
  fi

  targets=(${(u)targets})
  (( ${#targets} )) || return 1

  local need_sudo=0 f
  for f in "${targets[@]}"; do
    [[ -w "$f" ]] || { need_sudo=1; break; }
  done

  local can_sudo=0
  if (( need_sudo )); then
    if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
      can_sudo=1
    else
      echo "need privileges for at least one target, but sudo would prompt. fix perms or run from a root shell."
      return 1
    fi
  fi

  local first="${targets[1]}"
  local src pk rota kind="unknown"

  if command -v findmnt >/dev/null 2>&1; then
    src=$(findmnt -no SOURCE --target "$first" 2>/dev/null | head -n1)
  else
    src=$(df -P -- "$first" 2>/dev/null | awk 'NR==2{print $1}')
  fi

  if command -v lsblk >/dev/null 2>&1 && [[ -n "$src" ]]; then
    pk=$(lsblk -no PKNAME -- "$src" 2>/dev/null | head -n1 | tr -d ' ')
    [[ -z "$pk" ]] && pk=$(lsblk -no PKNAME -- "$(readlink -f -- "$src" 2>/dev/null)" 2>/dev/null | head -n1 | tr -d ' ')
    if [[ -n "$pk" && -r "/sys/block/$pk/queue/rotational" ]]; then
      rota=$(cat "/sys/block/$pk/queue/rotational" 2>/dev/null)
      if [[ "$rota" == "0" ]]; then
        kind="ssd"
      elif [[ "$rota" == "1" ]]; then
        kind="hdd"
      fi
    fi
  fi

  if [[ "$kind" == "hdd" ]]; then
    command -v shred >/dev/null 2>&1 || { echo "shred not found. On Debian: sudo apt install coreutils"; return 1; }
    for f in "${targets[@]}"; do
      if [[ -w "$f" ]]; then
        shred -n 1 -u -z -- "$f" >/dev/null 2>&1 || { echo "failed: $f"; return 1; }
      else
        sudo -n shred -n 1 -u -z -- "$f" >/dev/null 2>&1 || { echo "failed: $f"; return 1; }
      fi
    done
    return 0
  fi

  for f in "${targets[@]}"; do
    if [[ -w "$f" ]]; then
      rm -f -- "$f" >/dev/null 2>&1 || { echo "failed: $f"; return 1; }
    else
      sudo -n rm -f -- "$f" >/dev/null 2>&1 || { echo "failed: $f"; return 1; }
    fi
  done
}

# zsh completion: files and dirs
compdef _files shatter

