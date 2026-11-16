_have(){ command -v "$1" >/dev/null 2>&1; }
_err(){ print -P "%F{1}❌ $1%f" >&2; }
_ok(){  print -P "%F{2}$1%f"; }

# Detect session backend
_session(){
  if [[ -n ${WAYLAND_DISPLAY:-} || ${XDG_SESSION_TYPE:-} == wayland ]]; then
    printf "wayland"
  elif [[ -n ${DISPLAY:-} ]]; then
    printf "x11"
  else
    printf "none"
  fi
}

# OSC52 copy to terminal, works even over SSH and inside tmux
_osc52_copy(){
  local data b64 esc="\x1b" bel="\x07"
  data="$(cat)"
  if (( ${#data} > 1048576 )); then _err "OSC52 payload too large (>1 MB)"; return 1; fi
  b64="$(printf "%s" "$data" | base64 | tr -d '\r\n')"
  if [[ -n ${TMUX:-} ]]; then
    printf "${esc}Ptmux;${esc}]52;c;%s${bel}${esc}\\" "$b64"
  else
    printf "${esc}]52;c;%s${bel}" "$b64"
  fi
}

# Write to clipboard. Reads stdin. Optional: set CLIP_BACKEND=wl|x|xsel|osc52 to force.
_clip(){
  local be="${CLIP_BACKEND:-$(_session)}"
  case "$be" in
    wl|wayland)
      if _have wl-copy; then wl-copy "$@"; return; fi
      ;;
    x|x11)
      if _have xclip; then xclip -selection clipboard "$@"; return; fi
      if _have xsel;  then xsel --clipboard "$@"; return; fi
      ;;
    xsel)
      if _have xsel;  then xsel --clipboard "$@"; return; fi
      ;;
    osc52)
      _osc52_copy; return
      ;;
  esac

  case "$(_session)" in
    wayland)
      if _have wl-copy; then wl-copy "$@"; return; fi
      if _have xclip;   then xclip -selection clipboard "$@"; return; fi
      if _have xsel;    then xsel --clipboard "$@"; return; fi
      ;;
    x11)
      if _have xclip;   then xclip -selection clipboard "$@"; return; fi
      if _have xsel;    then xsel --clipboard "$@"; return; fi
      ;;
    none)
      _osc52_copy; return
      ;;
  esac

  _osc52_copy
}

# Read from clipboard to stdout
_paste(){
  local be="${CLIP_BACKEND:-$(_session)}"
  case "$be" in
    wl|wayland)
      if _have wl-paste; then wl-paste "$@"; return; fi
      ;;
    x|x11)
      if _have xclip; then xclip -selection clipboard -o "$@"; return; fi
      if _have xsel;  then xsel --clipboard -o "$@"; return; fi
      ;;
    xsel)
      if _have xsel;  then xsel --clipboard -o "$@"; return; fi
      ;;
    osc52)
      _err "paste via OSC52 is not possible"; return 1
      ;;
  esac

  case "$(_session)" in
    wayland)
      if _have wl-paste; then wl-paste "$@"; return; fi
      if _have xclip;    then xclip -selection clipboard -o "$@"; return; fi
      if _have xsel;     then xsel --clipboard -o "$@"; return; fi
      ;;
    x11)
      if _have xclip;    then xclip -selection clipboard -o "$@"; return; fi
      if _have xsel;     then xsel --clipboard -o "$@"; return; fi
      ;;
    none)
      _err "no GUI clipboard in this session"; return 1
      ;;
  esac

  _err "no clipboard tool found. install wl-clipboard or xclip"
  return 1
}

copy(){ _clip; }     # usage: echo hi | copy
paste(){ _paste; }   # prints clipboard


# create a new directory & cd into it
mdd () { mkdir -p "$@" && cd "$@"; }


cpd() {
  # copy readable text files to clipboard from dir (default .),
  # ignoring vcs junk, deps, caches, build outputs, images, videos, fonts, and lockfiles
  emulate -L zsh
  setopt err_return

  local dir="${1:-.}" max_mb=10
  [[ -d "$dir" ]] || { _err "'$dir' is not a directory"; return 1; }

  local list; list="$(mktemp)" || { _err "mktemp failed"; return 1; }
  (
    cd "$dir" || exit 1
    if _have git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git ls-files -z --cached --others --exclude-standard -- .
    else
      if _have fd; then
        fd -t f --hidden --follow \
          --exclude .git --exclude .github --exclude .gitlab \
          --exclude node_modules --exclude .pnpm-store --exclude .yarn --exclude .npm \
          --exclude .venv --exclude venv --exclude __pycache__ --exclude .cache \
          --exclude dist --exclude build --exclude .next --exclude out --exclude .turbo --exclude .vercel \
          --exclude target --exclude vendor --exclude .idea --exclude .vscode \
          . -0
      else
        find . \( \
          -name .git -o -name .github -o -name .gitlab -o \
          -name node_modules -o -name .pnpm-store -o -name .yarn -o -name .npm -o \
          -name .venv -o -name venv -o -name __pycache__ -o -name .cache -o \
          -name dist -o -name build -o -name .next -o -name out -o -name .turbo -o -name .vercel -o \
          -name target -o -name vendor -o -name .idea -o -name .vscode \
        \) -prune -o -type f -print0
      fi
    fi
  ) >"$list" || { rm -f "$list"; _err "failed to enumerate files"; return 1; }

  _skip() {
    local p="${1#./}"
    local lp="${p:l}"
    case "$lp" in
      .git|.git/*|*/.git/*|.github*|*/.github/*|.gitlab*|*/.gitlab/*) return 0 ;;
      node_modules/*|.pnpm-store/*|.yarn/*|.npm/*) return 0 ;;
      .venv/*|venv/*|__pycache__/*|.cache/*) return 0 ;;
      dist/*|build/*|.next/*|out/*|.turbo/*|.vercel/*) return 0 ;;
      target/*|vendor/*|.idea/*|.vscode/*) return 0 ;;
      .ds_store|*/.ds_store|thumbs.db|*/thumbs.db) return 0 ;;
    esac
    case "$lp" in
      *.ttf|*.otf|*.ttc|*.otc|*.woff|*.woff2|*.eot) return 0 ;;   # fonts
      *.jpg|*.jpeg|*.png|*.gif|*.webp|*.avif|*.bmp|*.tif|*.tiff|*.ico|*.heic|*.heif|*.svg) return 0 ;;
      *.mp4|*.m4v|*.mov|*.avi|*.mkv|*.webm|*.mpg|*.mpeg|*.flv|*.wmv) return 0 ;;
      package-lock.json|pnpm-lock.yaml|yarn.lock|npm-shrinkwrap.json|deno.lock|bun.lock|bun.lockb|cargo.lock|poetry.lock|pipfile.lock|uv.lock|requirements*.lock) return 0 ;;
    esac
    return 1
  }

  _is_text() {
    local lp="${1:l}"
    case "$lp" in
      *.ttf|*.otf|*.ttc|*.otc|*.woff|*.woff2|*.eot|*.png|*.jpg|*.jpeg|*.gif|*.webp|*.mp4|*.mkv|*.mov) return 1 ;;
    esac
    if _have file; then
      file --mime --brief -- "$1" | grep -qiE 'charset=(utf-8|us-ascii|iso-|text)'
    else
      LC_ALL=C grep -Iq . -- "$1"
    fi
  }

  _fmt_size() {
    local b="$1"
    if _have numfmt; then
      numfmt --to=iec --suffix=B "$b"
    else
      if (( b < 1024 )); then printf "%d B" "$b"
      elif (( b < 1048576 )); then awk -v x="$b" 'BEGIN{printf "%.1f KiB", x/1024}'
      elif (( b < 1073741824 )); then awk -v x="$b" 'BEGIN{printf "%.2f MiB", x/1048576}'
      else awk -v x="$b" 'BEGIN{printf "%.2f GiB", x/1073741824}'
      fi
    fi
  }

  local -i total=0 sz
  while IFS= read -r -d '' f; do
    _skip "$f" && continue
    [[ -f "$dir/$f" ]] || continue
    if _is_text "$dir/$f"; then
      sz=$(stat -c %s -- "$dir/$f" 2>/dev/null || echo 0)
      total=$(( total + sz ))
    fi
  done <"$list"

  if (( total == 0 )); then
    rm -f "$list"; _err "no text files to copy after applying ignores"; return 1
  fi

  if (( total > max_mb*1024*1024 )); then
    read -q "REPLY?⚠️ $(_fmt_size "$total") > $max_mb MiB, copy anyway? [y/N] "; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { rm -f "$list"; _err "aborted"; return 1; }
  fi

  (
    cd "$dir" || exit 1
    while IFS= read -r -d '' f; do
      _skip "$f" && continue
      if ! _is_text "$f"; then
        continue
      fi
      echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
      echo "<ROOT>/${f#./}"
      sed -e 's/\x1b\[[0-9;]*m//g' -- "$f"
      echo
    done <"$list"
  ) | _clip || { rm -f "$list"; _err "copy failed"; return 1; }

  local human; human="$(_fmt_size "$total")"
  rm -f "$list"
  _ok "copied files from '$dir' to clipboard ($human)"
}

# clipboard with real actions, progress, and safe defaults
clipdir() {
  emulate -L zsh
  setopt err_return pipe_fail no_unset

  # If no subcommand, show a simple picker that maps to real args
  if [[ -z ${1-} ]]; then
    if _have fzf; then
      local choice
      choice=$(
        printf "%s\n" \
          "copy   archive current dir to clipboard" \
          "paste  extract from clipboard to here" \
          "paste-to  extract from clipboard to chosen dir" \
          "help   show usage" |
        fzf --prompt='📦 clipdir ⇢ ' --height=40% --border --reverse --ansi \
            --header=$'↑↓ to move • Enter to run • Esc to quit'
      ) || return 1
      choice=${choice%% *}  # first token only
      case "$choice" in
        copy)      set -- copy ;;
        paste)     set -- paste ;;
        paste-to)
          print -P -n "%F{6}Target directory%f: "
          local t; read -r t || return 1
          [[ -z $t ]] && { _err "no directory given"; return 1; }
          mkdir -p -- "$t" || { _err "cannot create '$t'"; return 1; }
          set -- paste "$t"
          ;;
        help|*)    set -- --help ;;
      esac
    else
      set -- --help
    fi
  fi

  local sub="$1"; shift || true

  if [[ "$sub" == "-h" || "$sub" == "--help" ]]; then
    print -P "%F{6}Usage%f:"
    print -P "  %F{3}clipdir copy%f [--all] [--zstd|--gzip|--no-compress] [--exclude PATTERN]... [--include GLOB]... [--force]"
    print -P "  %F{3}clipdir paste%f [TARGET_DIR] [--force]"
    print -P "%F{8}Defaults%f: excludes heavy junk, uses zstd or gzip if available, shows progress if pv exists."
    return 1
  fi

  case "$sub" in
    copy)
      local all=false comp="auto" force=false
      local -a ex includes exopts tarpaths
      local use_pv=false
      local max_mb="${CLIPDIR_MAX_MB:-200}"
      _have pv && use_pv=true

      # sane default excludes
      ex=(
        .git .github .gitlab
        node_modules .pnpm-store .yarn .npm
        .venv venv __pycache__ .cache
        dist build .next out .turbo .vercel
        target vendor
        .idea .vscode
        "*.iso" "*.zip" "*.tar*" "*.mp4" "*.mp3" "*.mov" "*.avi" "*.mkv"
        "*.jpg" "*.jpeg" "*.png" "*.webp" "*.gif" "*.pdf"
      )

      while [[ $# -gt 0 ]]; do
        case "$1" in
          --all) all=true ;;
          --exclude) shift; [[ -n ${1-} ]] && ex+=("$1") ;;
          --include) shift; [[ -n ${1-} ]] && includes+=("$1") ;;
          --zstd|--compress=zstd) comp="zstd" ;;
          --gzip|--compress=gzip) comp="gzip" ;;
          --no-compress) comp="none" ;;
          --force) force=true ;;
          *) _err "unknown option $1"; return 1 ;;
        esac
        shift
      done

      # build tar args
      if ! $all; then
        for p in "${ex[@]}"; do exopts+=("--exclude=$p"); done
      fi
      if [[ ${#includes[@]} -gt 0 ]]; then
        tarpaths=("${includes[@]}")
      else
        tarpaths=(".")
      fi

      # pick compressor
      local comp_cmd="" comp_tag=""
      if [[ "$comp" == "zstd" || "$comp" == "auto" ]]; then
        if _have zstd; then comp_cmd="zstd -q -T0 -3"; comp_tag="zstd"; fi
      fi
      if [[ -z "$comp_cmd" && ( "$comp" == "gzip" || "$comp" == "auto" ) ]]; then
        if _have pigz; then comp_cmd="pigz -c -6"; comp_tag="gzip"
        elif _have gzip; then comp_cmd="gzip -c -6"; comp_tag="gzip"; fi
      fi
      [[ -z "$comp_cmd" ]] && comp_tag="none"

      # estimate uncompressed size for progress and limit (can skip with CLIPDIR_SKIP_SIZE=1)
      local bytes=0
      if [[ -z ${CLIPDIR_SKIP_SIZE-} ]]; then
        bytes=$(tar -cf - "${exopts[@]}" "${tarpaths[@]}" 2>/dev/null | wc -c | tr -d '[:space:]') || bytes=0
      fi
      local limit=$(( max_mb * 1024 * 1024 ))
      if (( bytes > 0 && bytes > limit )) && ! $force; then
        local human; if _have numfmt; then human=$(numfmt --to=iec --suffix=B "$bytes"); else human="${bytes}B"; fi
        read -q "REPLY?⚠️ $human exceeds ${max_mb}MiB. Copy anyway? [y/N] "; echo
        [[ $REPLY =~ ^[Yy]$ ]] || { _err "aborted"; return 1; }
      fi

      # archive → optional compress → clipboard, with progress if pv exists
      if [[ "$comp_tag" != "none" ]]; then
        if $use_pv && (( bytes > 0 )); then
          tar -cf - "${exopts[@]}" "${tarpaths[@]}" 2>/dev/null \
            | pv -ptebar -i 0.2 -s "${bytes:-0}" \
            | eval "$comp_cmd" \
            | _clip
        else
          tar -cf - "${exopts[@]}" "${tarpaths[@]}" 2>/dev/null \
            | eval "$comp_cmd" \
            | _clip
        fi
        _ok "copied ${PWD##*/} to clipboard (compressed: $comp_tag)"
      else
        if $use_pv && (( bytes > 0 )); then
          tar -cf - "${exopts[@]}" "${tarpaths[@]}" 2>/dev/null \
            | pv -ptebar -i 0.2 -s "${bytes:-0}" \
            | _clip
        else
          tar -cf - "${exopts[@]}" "${tarpaths[@]}" 2>/dev/null | _clip
        fi
        _ok "copied ${PWD##*/} to clipboard"
      fi
      ;;
    paste)
      local target="${1:-.}"; shift || true
      local force=false
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --force) force=true ;;
          *) _err "unknown option $1"; return 1 ;;
        esac
        shift
      done
      [[ -d "$target" ]] || { _err "'$target' is not a directory"; return 1; }
      if [[ -n "$(ls -A "$target" 2>/dev/null)" ]] && ! $force; then
        print -P "%F{3}📂 '%f%F{6}$target%f%F{3}' is not empty%f"
        read -q "REPLY?Extract here anyway? [y/N] "; echo
        [[ $REPLY =~ ^[Yy]$ ]] || { _err "aborted"; return 1; }
      fi

      local tmp; tmp="$(mktemp -t clipdir.XXXXXX)" || { _err "mktemp failed"; return 1; }
      _paste > "$tmp" || { rm -f "$tmp"; _err "no clipboard data"; return 1; }

      # detect format
      local fmt="tar"
      if _have file; then
        case "$(file -b --mime-type "$tmp")" in
          application/zstd) fmt="zst" ;;
          application/gzip) fmt="gz" ;;
        esac
      else
        local magic; magic=$(head -c 4 "$tmp" | od -An -t x1 | tr -d ' \n')
        case "$magic" in
          28b52ffd) fmt="zst" ;;
          1f8b08*)  fmt="gz" ;;
        esac
      fi

      # extract with progress when possible
      case "$fmt" in
        zst)
          _have zstd || { rm -f "$tmp"; _err "zstd not installed"; return 1; }
          if _have pv; then pv -ptebar -i 0.2 "$tmp" | zstd -q -d | tar -xvf - -C "$target"
          else zstd -q -d <"$tmp" | tar -xvf - -C "$target"; fi
          ;;
        gz)
          local gzcat
          if _have pigz; then gzcat="pigz -dc"
          elif _have gzip; then gzcat="gzip -dc"
          else gzcat="cat"; fi
          if _have pv && [[ "$gzcat" != "cat" ]]; then
            pv -ptebar -i 0.2 "$tmp" | eval "$gzcat" | tar -xvf - -C "$target"
          else
            eval "$gzcat <\"$tmp\"" | tar -xvf - -C "$target"
          fi
          ;;
        *)
          if _have pv; then pv -ptebar -i 0.2 "$tmp" | tar -xvf - -C "$target"
          else tar -xvf "$tmp" -C "$target"; fi
          ;;
      esac

      rm -f "$tmp"
      _ok "pasted into $(realpath "$target")"
      ;;
    *)
      _err "usage: clipdir {copy|paste} [...]"
      return 1
      ;;
  esac
}

# FZF mv
mvw() {
  emulate -L zsh
  setopt pipefail

  if ! command -v fzf >/dev/null 2>&1; then
    print "mvw: fzf is required" >&2
    return 1
  fi

  local -a candidates
  if command -v fd >/dev/null 2>&1; then
    candidates=("${(@f)$(fd . . 2>/dev/null)}")
  else
    candidates=("${(@f)$(find . -mindepth 1 -maxdepth 10 -print 2>/dev/null)}")
  fi

  (( ${#candidates} )) || return 0

  local src_raw
  src_raw=$(
    printf '%s\n' "${candidates[@]}" \
    | fzf --multi \
          --prompt='mvw source> ' \
          --preview 'ls -la --color=always {} 2>/dev/null || stat {} 2>/dev/null'
  ) || return 0

  [[ -z "$src_raw" ]] && return 0

  local -a src
  src=("${(@f)src_raw}")

  local dest_root="/"
  local dest
  if command -v fd >/dev/null 2>&1; then
    dest=$(
      fd . "$dest_root" -t d --hidden --follow --exclude .git --absolute-path 2>/dev/null \
      | fzf --prompt='mvw dest> ' \
            --preview 'ls -la --color=always {} 2>/dev/null'
    ) || return 0
  else
    dest=$(
      find "$dest_root" -maxdepth 15 -type d 2>/dev/null \
      | fzf --prompt='mvw dest> ' \
            --preview 'ls -la --color=always {} 2>/dev/null'
    ) || return 0
  fi

  [[ -z "$dest" ]] && return 0

  mv -iv -- "${src[@]}" "$dest"/
}

cpw() {
  emulate -L zsh
  setopt pipefail

  if ! command -v fzf >/dev/null 2>&1; then
    print "cpw: fzf is required" >&2
    return 1
  fi

  local -a candidates
  if command -v fd >/dev/null 2>&1; then
    candidates=("${(@f)$(fd . . 2>/dev/null)}")
  else
    candidates=("${(@f)$(find . -mindepth 1 -maxdepth 10 -print 2>/dev/null)}")
  fi

  (( ${#candidates} )) || return 0

  local src_raw
  src_raw=$(
    printf '%s\n' "${candidates[@]}" \
    | fzf --multi \
          --prompt='cpw source> ' \
          --preview 'ls -la --color=always {} 2>/dev/null || stat {} 2>/dev/null'
  ) || return 0

  [[ -z "$src_raw" ]] && return 0

  local -a src
  src=("${(@f)src_raw}")

  local dest_root="/"
  local dest
  if command -v fd >/dev/null 2>&1; then
    dest=$(
      fd . "$dest_root" -t d --hidden --follow --exclude .git --absolute-path 2>/dev/null \
      | fzf --prompt='cpw dest> ' \
            --preview 'ls -la --color=always {} 2>/dev/null'
    ) || return 0
  else
    dest=$(
      find "$dest_root" -maxdepth 15 -type d 2>/dev/null \
      | fzf --prompt='cpw dest> ' \
            --preview 'ls -la --color=always {} 2>/dev/null'
    ) || return 0
  fi

  [[ -z "$dest" ]] && return 0

  cp -ivr -- "${src[@]}" "$dest"/
}


# FZF delete picker
rmw() {
  _have fzf || { echo "fzf missing"; return 1; }
  local finder selection
  if _have fd; then finder='fd --hidden --follow --exclude .git .'
  else finder='find . -mindepth 1 -not -path "*/\.git/*"'; fi
  selection=$(
    eval "$finder" | fzf --multi --height 60% --reverse --border \
      --prompt="🗑️  select items to delete ⇢ " \
      --preview '
        [[ -d {} ]] && { command -v tree >/dev/null && tree -C -L 2 {} || ls -a {} ; } ||
        { command -v bat >/dev/null && bat --style=numbers --color=always --line-range :200 {} || head -n 200 {} ; }'
  )
  [[ -z $selection ]] && echo "nothing chosen, aborting" && return 1
  echo "about to delete:"; echo "$selection" | sed 's/^/   🔸 /'
  read -q "REPLY?confirm? [y/N] "; echo
  [[ $REPLY =~ ^[Yy]$ ]] || { echo "aborted"; return 1 }
  echo "$selection" | xargs -r rm -rf
  echo "deleted"
}

# Copy picked files to clipboard
cpf() {
  local -a picks; local max_mb=10
  if (( $# )); then picks=("$@")
  else
    _have fzf || { _err "fzf not found, pass a file path"; return 1 }
    local finder; _have fd && finder="fd -t f --hidden --exclude .git ." || finder="find . -type f -not -path '*/\.git/*'"
    picks=("${(@f)$(eval "$finder" | fzf --multi --height 60% --border --reverse \
      --prompt='📋 pick file ⇢ ' \
      --preview 'command -v bat >/dev/null && bat --style=numbers --color=always --line-range :300 {} || head -n 300 {}')}")
    [[ -z $picks ]] && _err "cancelled" && return 1
  fi

  for f in "${picks[@]}"; do [[ -f $f ]] || { _err "'$f' is not a regular file"; return 1; } done
  local total_bytes=$(du -cb "${picks[@]}" | tail -1 | awk '{print $1}')
  if (( total_bytes > max_mb*1024*1024 )); then
    read -q "REPLY?⚠️ ${total_bytes} bytes > ${max_mb} MB, copy anyway? [y/N] "; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { _err "aborted"; return 1; }
  fi

  cat "${picks[@]}" | _clip || return 1
  _ok "copied ${#picks[@]} file(s) to clipboard (${total_bytes} bytes)"
}

# copy stdout of any command to clipboard
ccmd(){ eval "$@" | _clip; }
