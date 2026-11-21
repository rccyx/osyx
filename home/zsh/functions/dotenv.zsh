# le: fuzzy-pick .env files and export them safely
le() {
  emulate -L zsh
  setopt localoptions pipefail extendedglob typesetsilent no_bang_hist no_nomatch

  local TRUST=0 ROOT=""
  for arg in "$@"; do
    case "$arg" in
      -t|--trust) TRUST=1 ;;
      *) ROOT="$arg" ;;
    esac
  done

  if ! command -v fzf >/dev/null 2>&1; then
    print -r -- "fzf not found."
    return 1
  fi

  # Resolve root
  if [[ -z "$ROOT" ]]; then
    if command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
      ROOT="$(git rev-parse --show-toplevel)"
    else
      ROOT="$PWD"
    fi
  fi
  ROOT="${~ROOT}"
  [[ -d "$ROOT" ]] || { print -r -- "Directory not found: $ROOT"; return 1; }

  # Finder for env-like files
  _env_find() {
    command find "$1" \
      -name .git -prune -o \
      -name node_modules -prune -o \
      -name target -prune -o \
      -name .venv -prune -o \
      -name venv -prune -o \
      -name dist -prune -o \
      -name build -prune -o \
      -type f \( -name ".env" -o -name ".env.*" -o -name "*.env" -o -name "*.env.*" -o -name ".envrc" \) \
      -print 2>/dev/null | sed -e "s#^$1/##"
  }

  # Preview without leaking values
  _env_preview() {
    local f="$1"
    if command -v bat >/dev/null 2>&1; then
      awk 'BEGIN{FS="="}
        /^[[:space:]]*#/ || /^[[:space:]]*$/ {next}
        {
          k=$1; sub(/^[ \t]*/,"",k); sub(/[ \t]*$/,"",k);
          $1=""; v=substr($0,2); sub(/^[ \t]*/,"",v);
          gsub(/\r$/,"",v)
          mv=(length(v)>12?substr(v,1,3)"***":(v==""?"":(length(v)<=3?"***":substr(v,1,1)"**")))
          printf "%-30s = %s\n", k, mv
        }' -- "$f" | bat --style=plain --paging=never --language=env -
    else
      awk 'BEGIN{FS="="}
        /^[[:space:]]*#/ || /^[[:space:]]*$/ {next}
        {
          k=$1; sub(/^[ \t]*/,"",k); sub(/[ \t]*$/,"",k);
          $1=""; v=substr($0,2); sub(/^[ \t]*/,"",v);
          gsub(/\r$/,"",v)
          mv=(length(v)>12?substr(v,1,3)"***":(v==""?"":(length(v)<=3?"***":substr(v,1,1)"**")))
          printf "%-30s = %s\n", k, mv
        }' -- "$f"
    fi
  }

  local -a rel files
  local sel
  while true; do
    rel=("${(@f)$(_env_find "$ROOT")}")
    if (( ${#rel} == 0 )); then
      vared -p "No env files under $ROOT. New folder to scan: " -c ROOT
      [[ -z "$ROOT" ]] && return 1
      [[ -d "$ROOT" ]] || { print -r -- "Not a dir: $ROOT"; return 1; }
      continue
    fi

    sel=$(
      printf '%s\n' "${rel[@]}" | fzf --multi \
        --prompt="ENV files in ${ROOT:t} › " \
        --header="$([[ $TRUST -eq 1 ]] && print -r -- 'Mode: TRUST' || print -r -- 'Mode: SAFE'); Space select, Enter load, Alt-d change dir, Ctrl-r rescan" \
        --bind 'alt-d:cancel' \
        --bind "ctrl-r:reload(eval _env_find \"$ROOT\")" \
        --preview='_env_preview "'"$ROOT"'"/{}' \
        --preview-window='right,60%,border-rounded' \
        --border=rounded --height=90% --min-height=20 --layout=reverse
    )

    if [[ -z "$sel" ]]; then
      vared -p "New folder to scan (current: $ROOT): " -c ROOT
      [[ -z "$ROOT" ]] && return 1
      [[ -d "$ROOT" ]] || { print -r -- "Not a dir: $ROOT"; return 1; }
      continue
    fi

    files=("${(@f)sel}")
    break
  done

  print -r -- "Loading ${#files} file(s). Later files override earlier ones."
  for f in "${files[@]}"; do print -r -- "  + $f"; done

  # Safe loader that ignores comments, trims, and exports k=v
  _safe_load_one() {
    local file="$1" line key val
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" == \#* ]] && continue
      line="${line//$'\r'/}"
      line="${line/#export /}"

      key="${line%%=*}"
      val="${line#*=}"

      # Trim whitespace without using [!…] which trips history expansion
      key="${key##[[:space:]]##}"
      key="${key%%[[:space:]]##}"
      val="${val##[[:space:]]##}"
      val="${val%%[[:space:]]##}"

      # Strip surrounding quotes if present
      if [[ "$val" == \"*\" && "$val" == *\" ]]; then
        val="${val:1:-1}"
      elif [[ "$val" == \'*\' && "$val" == *\' ]]; then
        val="${val:1:-1}"
      fi

      # Basic KEY validation
      if [[ "$key" != [A-Za-z_][A-Za-z0-9_]* ]]; then
        print -r -- "Skip invalid key in $file: $key"
        continue
      fi

      typeset -gx -- "$key=$val"
    done < "$file"
  }

  # Trust loader: honors shell syntax inside files
  _trust_load_one() {
    local file="$1"
    set -a
    source "$file"
    set +a
  }

  local abs
  for relpath in "${files[@]}"; do
    abs="$ROOT/$relpath"
    if (( TRUST )); then
      _trust_load_one "$abs"
    else
      _safe_load_one "$abs"
    fi
  done

  print -r -- "Done. Environment updated in this shell."
}

# Completion for loadEnv: flags and directory
#compdef loadEnv
_loadEnv() {
  _arguments \
    '(-t --trust)'{-t,--trust}'[trust and source files with set -a]' \
    '*:directory:_files -/'
}
compdef _loadEnv loadEnv

