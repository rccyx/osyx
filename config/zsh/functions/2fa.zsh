# Set this to your GPG key's full fingerprint.
# github.com/rccyx/totpyx
typeset -gr TFA_GPG_FINGERPRINT='79821E0224D34EC4969FF6A8E5168EE090AE80D0'
(( ${+TFA_STORE_DIR} )) || typeset -gr TFA_STORE_DIR="${PASSWORD_STORE_DIR:-$HOME/.2fa}"

tfa.init(){
  emulate -L zsh
  _tfa_require pass || return $?
  [[ -f "$TFA_STORE_DIR/.gpg-id" ]] && {
    _tfa_error "store already initialized"
    return 1
  }
  _tfa_require gpg || return $?
  command gpg --list-secret-keys "$TFA_GPG_FINGERPRINT" >/dev/null || return $?
  _tfa_pass init "$TFA_GPG_FINGERPRINT"
}

tfa.add(){
  emulate -L zsh
  _tfa_ready || return $?
  local name
  read -r 'name?account name: ' || return 1
  _tfa_validate_name "$name" || return $?
  [[ -e "$TFA_STORE_DIR/$name.gpg" ]] && {
    _tfa_error "account exists; use tfa.change"
    return 1
  }
  _tfa_store_secret "$name"
}

tfa.list(){
  emulate -L zsh
  _tfa_ready || return $?
  local -a files=("$TFA_STORE_DIR"/*.gpg(.N:t:r))
  (( ${#files} )) || return 0
  print -rl -- "${(@o)files}"
}

tfa.change(){
  emulate -L zsh
  _tfa_ready || return $?
  local name
  name="$(_tfa_pick)" || return $?
  _tfa_store_secret "$name" --force
}

tfa.remove(){
  emulate -L zsh
  _tfa_ready || return $?
  local name
  name="$(_tfa_pick)" || return $?
  _tfa_pass rm "$name" || return $?
  _tfa_sync
}

tfa.use(){
  emulate -L zsh
  _tfa_ready || return $?
  local name secret code
  name="$(_tfa_pick)" || return $?
  secret="$(_tfa_pass show "$name")" || return $?
  code="$(_tfa_code "$secret")" || return $?
  local left=$(( 30 - $(date +%s) % 30 ))
  if print -rn -- "$code" | _tfa_clip; then
    print -r -- "$code  copied (${left}s left)"
  else
    print -r -- "$code  (${left}s left)"
    _tfa_error "clipboard copy failed"
    return 1
  fi
}

tfa(){
  emulate -L zsh
  [[ -f "$TFA_STORE_DIR/.gpg-id" ]] || tfa.init || return $?
  _tfa_require fzf || return $?
  local action
  action="$(printf '%s\n' use add list change remove | fzf --height=40% --prompt='tfa > ')" || return $?
  case "$action" in
    use|add|list|change|remove) "tfa.$action" ;;
    *) return 1 ;;
  esac
}

_tfa_error(){ print -ru2 -- "2fa: $*"; }

_tfa_require(){
  command -v "$1" >/dev/null 2>&1 && return 0
  _tfa_error "missing dependency: $1"
  return 127
}

_tfa_pass(){
  PASSWORD_STORE_DIR="$TFA_STORE_DIR" PASSWORD_STORE_KEY="$TFA_GPG_FINGERPRINT" \
    command pass "$@"
}

_tfa_ready(){
  _tfa_require pass || return $?
  [[ -f "$TFA_STORE_DIR/.gpg-id" ]] || {
    _tfa_error "initialize the store with tfa.init first"
    return 1
  }
  [[ "$(<"$TFA_STORE_DIR/.gpg-id")" == "$TFA_GPG_FINGERPRINT" ]] && return 0
  _tfa_error "store recipient differs from the pinned GPG key"
  return 1
}

_tfa_validate_name(){
  emulate -L zsh
  setopt extendedglob
  [[ "$1" == [A-Za-z0-9][A-Za-z0-9._-]# ]] && return 0
  _tfa_error "use letters, digits, dots, underscores or hyphens; start with a letter or digit"
  return 1
}

_tfa_pick(){
  _tfa_require fzf || return $?
  local accounts name
  accounts="$(tfa.list)" || return $?
  [[ -n "$accounts" ]] || { _tfa_error "no accounts yet"; return 1; }
  name="$(print -r -- "$accounts" | fzf --height=60% --prompt='2FA account > ')" || return $?
  _tfa_validate_name "$name" || return $?
  print -r -- "$name"
}

_tfa_store_secret(){
  local secret
  read -rs 'secret?raw 2FA secret: ' || return 1
  print -u2
  secret="${secret//[[:space:]-]/}"
  secret="${(U)secret}"
  [[ -n "$secret" ]] || { _tfa_error "empty secret"; return 1; }
  _tfa_code "$secret" >/dev/null || return $?
  print -r -- "$secret" | _tfa_pass insert --multiline ${2:+$2} "$1" >/dev/null || return $?
  _tfa_sync || return $?
  print -r -- "saved $1 (encrypted)"
}

_tfa_sync(){
  command git -C "$TFA_STORE_DIR" rev-parse --git-dir >/dev/null 2>&1 || return 0
  command git -C "$TFA_STORE_DIR" push
}

_tfa_code(){
  emulate -L zsh
  setopt extendedglob
  _tfa_require totpyx || return $?
  local code
  # Keep generator diagnostics out of the terminal: they may contain the seed.
  code="$(command totpyx "$1" 2>/dev/null)" || {
    _tfa_error "totpyx rejected the secret"
    return 1
  }
  [[ "$code" == [0-9](#c6) ]] || {
    _tfa_error "totpyx returned an invalid code"
    return 1
  }
  print -r -- "$code"
}

_tfa_clip(){
  if command -v wl-copy >/dev/null 2>&1; then
    command wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    command xclip -selection clipboard
  elif command -v pbcopy >/dev/null 2>&1; then
    command pbcopy
  else
    return 1
  fi
}
