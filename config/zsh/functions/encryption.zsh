# ---------- tiny UI helpers ----------
_ok(){ print -P "%F{2}✔%f $*"; }
_note(){ print -P "%F{4}ℹ️ %f $*"; }
_warn(){ print -P "%F{3}‼%f $*"; }
_err(){ print -P "%F{1}✖%f $*"; }
_hr(){ print -P "%F{244}${(l:60::-:)}%f"; }

# ---------- deps and env ----------
_need(){ command -v "$1" >/dev/null 2>&1 || { _err "missing dep: $1"; return 1; } }

_gpg_env(){
  export GPG_TTY="${GPG_TTY:-$(tty 2>/dev/null || true)}"
  export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-$HOME/.gnupg/S.gpg-agent.ssh}"
}

_gpg_check(){
  _need gpg || return 1
  _need fzf || return 1
  _need tar || return 1
  _gpg_env
  gpgconf --launch gpg-agent >/dev/null 2>&1 || true
}

# ---------- clipboard ----------
_clip(){
  if command -v wl-copy >/dev/null 2>&1; then wl-copy
  elif command -v xclip >/dev/null 2>&1; then xclip -selection clipboard
  elif command -v pbcopy >/dev/null 2>&1; then pbcopy
  else cat
  fi
}

# ---------- pickers ----------
_gpg_list_pub_tsv(){
  gpg --list-keys --with-colons --fingerprint 2>/dev/null \
  | awk -F: '
    $1=="pub"{algo=$4;len=$3;created=$6;expires=$7;trust=$2}
    $1=="fpr"{fpr=$10}
    $1=="uid"{uid=$10; printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", fpr, uid, algo, created, expires, trust, len }
  '
}

_gpg_list_sec_tsv(){
  gpg --list-secret-keys --with-colons --fingerprint 2>/dev/null \
  | awk -F: '
    $1=="sec"{algo=$4;len=$3;created=$6;expires=$7;trust=$2}
    $1=="fpr"{fpr=$10}
    $1=="uid"{uid=$10; printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", fpr, uid, algo, created, expires, trust, len }
  '
}

_gpg_pick_pub_multi(){
  local rows; rows="$(_gpg_list_pub_tsv)"
  [[ -z "$rows" ]] && { _err "no public keys found"; return 1; }
  print -r -- "$rows" \
  | fzf --multi --with-nth=2 --delimiter='\t' --height=70% \
        --prompt="pick recipient(s) ⇢ " \
        --preview-window=down,8 \
        --preview 'printf "FPR: %s\nUID: %s\nAlgo: %s Len: %s\nCreated: %s\nExpires: %s\nTrust: %s\n" {1} {2} {3} {7} {4} {5} {6}' \
  | awk -F'\t' '{print $1}'
}

_gpg_pick_sec_one(){
  local rows; rows="$(_gpg_list_sec_tsv)"
  [[ -z "$rows" ]] && { _err "no secret keys found"; return 1; }
  print -r -- "$rows" \
  | fzf --with-nth=2 --delimiter='\t' --height=70% \
        --prompt="pick signing key ⇢ " \
        --preview-window=down,8 \
        --preview 'printf "FPR: %s\nUID: %s\nAlgo: %s Len: %s\nCreated: %s\nExpires: %s\nTrust: %s\n" {1} {2} {3} {7} {4} {5} {6}' \
  | awk -F'\t' 'NR==1{print $1}'
}

_gpg_pick_files(){
  if (( $# > 0 )); then print -r -- "$@"; return 0; fi
  if command -v fd >/dev/null 2>&1; then
    # -H: hidden, -I: ignore .gitignore, -E .git: don't touch the repo guts
    fd -H -I -E .git -d 1 -t f -t d . | sort | fzf --multi --height=70% --prompt="pick files or dirs ⇢ "
  else
    find . -maxdepth 1 -mindepth 1 -not -name ".git" -printf "%P\n" | sort | fzf --multi --height=70% --prompt="pick files or dirs ⇢ "
  fi
}

# ---------- small helpers ----------
_bytes_of(){
  local p="$1"
  if [[ -d "$p" ]]; then du -sb "$p" 2>/dev/null | awk '{print $1}'
  else stat --printf="%s" "$p" 2>/dev/null || wc -c <"$p"
  fi
}
_hsize(){
  local b="$1" kib=1024 mib=$((1024*1024)) gib=$((1024*1024*1024)) tib=$((1024*1024*1024*1024))
  if   (( b >= tib )); then printf "%.2f TiB" "$((b*100/tib))e-2"
  elif (( b >= gib )); then printf "%.2f GiB" "$((b*100/gib))e-2"
  elif (( b >= mib )); then printf "%.2f MiB" "$((b*100/mib))e-2"
  elif (( b >= kib )); then printf "%.2f KiB" "$((b*100/kib))e-2"
  else printf "%d B" "$b"; fi
}

# Build --recipient args for an array of fingerprints/emails
_gpg_build_recip_args(){
  local -a out=()
  local r
  for r in "$@"; do out+=( --recipient "$r" ); done
  print -r -- "${(q)out[@]}"
}

# ---------- actions ----------
# Encrypt one or more files for selected recipients. Adds .gpg
gpg.enc(){
  emulate -L zsh; setopt pipefail
  _gpg_check || return 1

  local -a picks; picks=("${(@f)$(_gpg_pick_files "$@")}")
  (( ${#picks[@]} )) || { _err "nothing selected"; return 1; }

  _note "select recipient(s) or Esc for symmetric"
  local -a rcpts; rcpts=("${(@f)$(_gpg_pick_pub_multi)}")
  local mode="pub"; (( ${#rcpts[@]} )) || mode="sym"

  _hr
  print -P "%F{244}PLAN: encrypt%f ${#picks[@]} item(s) as ${mode}"
  local total=0 p; for p in "${picks[@]}"; do local b="$(_bytes_of "$p")"; (( total+=b )); print -P "  ${p}  ($(_hsize "$b"))"; done
  print -P "total ~ %F{6}$(_hsize "$total")%f"
  _hr

  local ans; read -r "ans?Proceed [y/N]: "; [[ "$ans" =~ ^[Yy]$ ]] || { _warn "aborted"; return 1; }

  local rc=0 out
  local -a recip_args=()
  if [[ "$mode" == "pub" ]]; then
    local r; for r in "${rcpts[@]}"; do recip_args+=( --recipient "$r" ); done
  fi

  for p in "${picks[@]}"; do
    out="${p}.gpg"
    if [[ "$mode" == "sym" ]]; then
      print -P "%F{244}→%f gpg --symmetric --cipher-algo AES256 -o ${(q)out} ${(q)p}"
      gpg --symmetric --cipher-algo AES256 -o "$out" "$p" || rc=$?
    else
      print -P "%F{244}→%f gpg --yes --encrypt ${(q)recip_args} -o ${(q)out} ${(q)p}"
      gpg --yes --encrypt "${recip_args[@]}" -o "$out" "$p" || rc=$?
    fi
  done
  (( rc == 0 )) && _ok "encrypt complete" || _err "encrypt finished with errors (rc=$rc)"
  return $rc
}

# Encrypt a directory by tarring then encrypting. Produces .tar.zst.gpg or .tar.gz.gpg
gpg.dir(){
  emulate -L zsh; setopt pipefail
  _gpg_check || return 1

  local -a picks; picks=("${(@f)$(_gpg_pick_files "$@")}")
  (( ${#picks[@]} )) || { _err "nothing selected"; return 1; }

  _note "select recipient(s) or Esc for symmetric"
  local -a rcpts; rcpts=("${(@f)$(_gpg_pick_pub_multi)}")
  local mode="pub"; (( ${#rcpts[@]} )) || mode="sym"

  local -a recip_args=()
  if [[ "$mode" == "pub" ]]; then
    local r; for r in "${rcpts[@]}"; do recip_args+=( --recipient "$r" ); done
  fi

  local rc=0 d base tmp
  for d in "${picks[@]}"; do
    [[ -d "$d" ]] || { _warn "skip non-dir: $d"; continue; }
    base="${d:t}"
    if command -v zstd >/dev/null 2>&1; then
      tmp="${base}.tar.zst"
      print -P "%F{244}→%f tar -C ${(q)d:h} -cf - ${(q)base} | zstd -q -T0 -19 -o ${(q)tmp}"
      tar -C "${d:h}" -cf - "${base}" | zstd -q -T0 -19 -o "${tmp}" || { rc=$?; continue; }
    else
      tmp="${base}.tar.gz"
      print -P "%F{244}→%f tar -C ${(q)d:h} -czf ${(q)tmp} ${(q)base}"
      tar -C "${d:h}" -czf "${tmp}" "${base}" || { rc=$?; continue; }
    fi
    if [[ "$mode" == "sym" ]]; then
      print -P "%F{244}→%f gpg --symmetric --cipher-algo AES256 -o ${(q)tmp}.gpg ${(q)tmp}"
      gpg --symmetric --cipher-algo AES256 -o "${tmp}.gpg" "${tmp}" || rc=$?
    else
      print -P "%F{244}→%f gpg --yes --encrypt ${(q)recip_args} -o ${(q)tmp}.gpg ${(q)tmp}"
      gpg --yes --encrypt "${recip_args[@]}" -o "${tmp}.gpg" "${tmp}" || rc=$?
    fi
    rm -f -- "$tmp"
    (( rc == 0 )) && _ok "encrypted dir: ${d} -> ${tmp}.gpg"
  done
  return $rc
}

# Decrypt file(s). If output is a tar.* then offer to extract.
gpg.dec(){
  emulate -L zsh; setopt pipefail
  _gpg_check || return 1
  local -a picks; picks=("${(@f)$(_gpg_pick_files "$@")}")
  (( ${#picks[@]} )) || { _err "nothing selected"; return 1; }

  local rc=0 f out
  for f in "${picks[@]}"; do
    if [[ "$f" != *.gpg && "$f" != *.asc ]]; then _warn "skip non gpg file: $f"; continue; fi
    if [[ "$f" == *.gpg ]]; then out="${f%.gpg}"
    elif [[ "$f" == *.asc ]]; then out="${f%.asc}"
    fi
    print -P "%F{244}→%f gpg --use-agent --batch --yes --decrypt -o ${(q)out} ${(q)f}"
    gpg --use-agent --batch --yes --decrypt -o "$out" "$f" 2>/dev/null || { rc=$?; continue; }

    if [[ "$out" == *.tar.zst || "$out" == *.tar.gz || "$out" == *.tar ]]; then
      local ans; read -r "ans?Extract ${out} to ./${out:r}/ [y/N]: "
      if [[ "$ans" =~ ^[Yy]$ ]]; then
        local dest="./${out:r}"
        mkdir -p -- "$dest"
        if [[ "$out" == *.tar.zst ]]; then
          print -P "%F{244}→%f zstd -d -c ${(q)out} | tar -C ${(q)dest} -xf -"
          zstd -d -c "$out" | tar -C "$dest" -xf - || rc=$?
        elif [[ "$out" == *.tar.gz ]]; then
          print -P "%F{244}→%f tar -C ${(q)dest} -xzf ${(q)out}"
          tar -C "$dest" -xzf "$out" || rc=$?
        else
          print -P "%F{244}→%f tar -C ${(q)dest} -xf ${(q)out}"
          tar -C "$dest" -xf "$out" || rc=$?
        fi
      fi
    fi
  done
  (( rc == 0 )) && _ok "decrypt complete" || _err "decrypt finished with errors (rc=$rc)"
  return $rc
}

# Decrypt to stdout, useful for piping
gpg.dec_stdout(){
  _gpg_check || return 1
  local f="$1"; [[ -z "$f" ]] && { _err "usage: gpg.dec_stdout file.gpg"; return 1; }
  gpg --decrypt "$f"
}

# Sign files. Choose clearsign or detached, pick secret key.
gpg.sign(){
  emulate -L zsh; setopt pipefail
  _gpg_check || return 1
  local mode
  mode=$(printf "%s\n" "clearsign" "detach-sign" | fzf --prompt="sign mode ⇢ ") || return 1
  local key; key="$(_gpg_pick_sec_one)" || return 1
  local -a picks; picks=("${(@f)$(_gpg_pick_files "$@")}")
  (( ${#picks[@]} )) || { _err "nothing selected"; return 1; }

  local rc=0 f
  for f in "${picks[@]}"; do
    if [[ "$mode" == "clearsign" ]]; then
      print -P "%F{244}→%f gpg --local-user ${(q)key} --clearsign ${(q)f}"
      gpg --local-user "$key" --clearsign "$f" || rc=$?
    else
      print -P "%F{244}→%f gpg --local-user ${(q)key} --detach-sign ${(q)f}"
      gpg --local-user "$key" --detach-sign "$f" || rc=$?
    fi
  done
  (( rc == 0 )) && _ok "sign complete" || _err "sign finished with errors (rc=$rc)"
  return $rc
}

# Verify signatures
gpg.verify(){
  _gpg_check || return 1
  local -a picks; picks=("${(@f)$(_gpg_pick_files "$@")}")
  (( ${#picks[@]} )) || { _err "nothing selected"; return 1; }
  local f rc=0
  for f in "${picks[@]}"; do
    print -P "%F{244}→%f gpg --verify ${(q)f}"
    gpg --verify "$f" && _ok "verified $f" || { _err "verify failed: $f"; rc=1; }
  done
  return $rc
}

# Export and import keys
gpg.export_pub(){
  _gpg_check || return 1
  local fpr="$(_gpg_pick_pub_multi | head -n1)" || return 1
  [[ -z "$fpr" ]] && { _err "no key selected"; return 1; }
  gpg --armor --export "$fpr" | tee "pubkey-${fpr}.asc" | _clip >/dev/null
  _ok "exported to pubkey-${fpr}.asc and copied to clipboard"
}
gpg.export_sec(){
  _gpg_check || return 1
  local fpr="$(_gpg_pick_sec_one)" || return 1
  [[ -z "$fpr" ]] && { _err "no key selected"; return 1; }
  local out="seckey-${fpr}.asc"
  _warn "exporting secret key. protect this file."
  gpg --armor --export-secret-keys "$fpr" > "$out" && _ok "wrote $out"
}
gpg.import(){
  _gpg_check || return 1
  local -a picks; picks=("${(@f)$(_gpg_pick_files "$@")}")
  (( ${#picks[@]} )) || { _err "nothing selected"; return 1; }
  gpg --import "${picks[@]}"
}

# Locate and import by email or fingerprint (WKD/keyserver)
gpg.recv(){
  _gpg_check || return 1
  local q="$1"
  [[ -z "$q" ]] && read -r "q?email or fingerprint: "
  [[ -z "$q" ]] && { _err "no query"; return 1; }
  gpg --auto-key-locate wkd,keyserver --locate-keys "$q"
}

# Edit ownertrust for a key
gpg.trust(){
  _gpg_check || return 1
  local fpr; fpr="$(_gpg_pick_pub_multi | head -n1)" || return 1
  [[ -z "$fpr" ]] && { _err "no key selected"; return 1; }
  gpg --edit-key "$fpr" trust quit
}

# Generate new key using quick mode
gpg.gen(){
  _gpg_check || return 1
  local name email
  read -r "name?Real name: " name
  read -r "email?Email: " email
  [[ -z "$name" || -z "$email" ]] && { _err "need name and email"; return 1; }
  gpg --quick-gen-key "$name <$email>" rsa4096 cert,sign,auth,encr 2y
}

# Delete key (pub and secret) with confirmation
gpg.del(){
  _gpg_check || return 1
  local fpr; fpr="$(_gpg_pick_pub_multi | head -n1)" || return 1
  [[ -z "$fpr" ]] && { _err "no key selected"; return 1; }
  print -n "Type the fingerprint to confirm delete: "
  local conf; read -r conf
  [[ "$conf" == "$fpr" ]] || { _warn "mismatch. aborted."; return 1; }
  gpg --batch --yes --delete-secret-and-public-key "$fpr"
}

# Armor and dearmor helpers
gpg.armor(){ _gpg_check || return 1; local f="$1"; [[ -z "$f" ]] && { _err "usage: gpg.armor file.bin"; return 1; }; gpg --armor --enarmor <"$f"; }
gpg.dearmor(){ _gpg_check || return 1; local f="$1"; [[ -z "$f" ]] && { _err "usage: gpg.dearmor file.asc"; return 1; }; gpg --dearmor <"$f"; }

# Inspect recipients of an encrypted file
gpg.inspect(){
  _gpg_check || return 1
  local f="$1"; [[ -z "$f" ]] && { _err "usage: gpg.inspect file.gpg"; return 1; }
  gpg --list-packets --verbose "$f" | sed -n '1,160p'
}

# Agent control and quick status
gpg.agent(){
  _gpg_check || true
  local mode="${1:-status}"
  case "$mode" in
    restart) gpgconf --kill gpg-agent; gpgconf --launch gpg-agent; _ok "agent restarted";;
    status) gpgconf --list-dirs; gpgconf --show-versions;;
    ssh) gpgconf --launch gpg-agent; print -P "SSH_AUTH_SOCK=${SSH_AUTH_SOCK}";;
    *) _err "usage: gpg.agent [status|restart|ssh]"; return 1;;
  esac
}

# Pretty list of keys
gpg.ls(){
  _gpg_check || return 1
  local kind="${1:-pub}"
  if [[ "$kind" == "sec" ]]; then
    _gpg_list_sec_tsv | fzf --with-nth=2 --delimiter='\t' --preview-window=down,8 \
    --preview 'printf "FPR: %s\nUID: %s\nAlgo: %s Len: %s\nCreated: %s\nExpires: %s\nTrust: %s\n" {1} {2} {3} {7} {4} {5} {6}'
  else
    _gpg_list_pub_tsv | fzf --with-nth=2 --delimiter='\t' --preview-window=down,8 \
    --preview 'printf "FPR: %s\nUID: %s\nAlgo: %s Len: %s\nCreated: %s\nExpires: %s\nTrust: %s\n" {1} {2} {3} {7} {4} {5} {6}'
  fi
}

# Top level menu
gpg.help(){
cat <<'EOF'
gpg. menu
  enc            Encrypt file(s) for selected recipients or symmetric
  dir            Tar-compress directory then encrypt
  dec            Decrypt file(s), optional extract if tar.*
  dec_stdout     Decrypt to stdout
  sign           Clearsign or detached-sign with picked key
  verify         Verify signature files
  export_pub     Export public key to .asc and clipboard
  export_sec     Export secret key to .asc
  import         Import .asc or .gpg key files
  recv           Locate and import by email or fingerprint
  trust          Edit ownertrust for a key
  gen            Quick gen rsa4096 key with 2y validity
  del            Delete pub and secret key with confirmation
  armor          Convert binary to ASCII armor (stdout)
  dearmor        Convert ASCII armor to binary (stdout)
  inspect        Show recipients and packets for an encrypted file
  agent          Agent helper: gpg.agent [status|restart|ssh]
  ls             Fuzzy list keys; usage: gpg.ls [pub|sec]

compat helpers kept as requested: passenc, passdec, loadpg and password gens.
EOF
}

gpg.(){
  _gpg_check || return 1
  local cmd="$1"
  if [[ -n "$cmd" ]]; then
    shift # safe: we only shift when $1 existed
  else
    cmd=$(
      printf "%s\n" \
        "enc" "dir" "dec" "dec_stdout" "sign" "verify" \
        "export_pub" "export_sec" "import" "recv" "trust" "gen" "del" \
        "armor" "dearmor" "inspect" "agent" "ls" \
        "passenc" "passdec" "loadpg" \
        "genpass_easy" "genpass_mid" "genpass_hard" \
        "help" \
      | fzf --prompt="gpg. ⇢ "
    )
    [[ -z "$cmd" ]] && return 1
  fi
  "gpg.${cmd}" "$@"
}

# ---------- zsh completion for gpg. ----------
_gpgdot_complete(){
  local -a sub=(enc dir dec dec_stdout sign verify export_pub export_sec import recv trust gen del armor dearmor inspect agent ls help passenc passdec loadpg genpass_easy genpass_mid genpass_hard)
  _describe -t commands 'gpg. subcommands' sub
}
compdef _gpgdot_complete gpg.

genpass_easy() { openssl rand -hex 16; }
genpass_mid() { openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 32; }
genpass_hard() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9!@#$%^&*()_+[]{}<>?,.:;' | head -c 32; }

# encrypt a file with a passphrase
passenc() {
  emulate -L zsh
  setopt pipefail

  (( $# )) || { echo -e "\e[1;31musage: passenc file1 [file2 ...]\e[0m"; return 1; }

  local pass=""
  if [[ -n "${PASSENC_PASS:-}" ]]; then
    pass="$PASSENC_PASS"
  else
    local pass2=""
    read -rs "pass?passphrase: "
    echo
    [[ -n "$pass" ]] || { echo -e "\e[1;31mempty passphrase\e[0m"; return 1; }
    read -rs "pass2?repeat passphrase: "
    echo
    [[ "$pass" == "$pass2" ]] || { echo -e "\e[1;31mpassphrases do not match\e[0m"; return 1; }
  fi

  local rc=0 input_file output_file
  for input_file in "$@"; do
    [[ -f "$input_file" ]] || { echo -e "\e[1;33mskipping (not a file): $input_file\e[0m"; rc=1; continue; }
    [[ "$input_file" == *.gpg ]] && { echo -e "\e[1;33mskipping (already .gpg): $input_file\e[0m"; continue; }

    output_file="${input_file}.gpg"

    if print -r -- "$pass" | gpg --symmetric --cipher-algo AES256 --pinentry-mode loopback --passphrase-fd 0 --quiet --batch --yes --output "$output_file" "$input_file"; then
      shred -u -- "$input_file" 2>/dev/null || rm -f -- "$input_file"
      echo -e "\e[1;32mEncrypted $input_file -> $output_file\e[0m"
    else
      echo -e "\e[1;31mEncryption failed for $input_file\e[0m"
      rc=1
    fi
  done

  return $rc
}

passdec() {
  emulate -L zsh
  setopt pipefail

  (( $# )) || { echo -e "\e[1;31musage: passdec file1.gpg [file2.gpg ...]\e[0m"; return 1; }

  local pass=""
  if [[ -n "${PASSENC_PASS:-}" ]]; then
    pass="$PASSENC_PASS"
  else
    read -rs "pass?passphrase: "
    echo
    [[ -n "$pass" ]] || { echo -e "\e[1;31mempty passphrase\e[0m"; return 1; }
  fi

  local rc=0 input_file output_file
  for input_file in "$@"; do
    [[ -f "$input_file" ]] || { echo -e "\e[1;33mskipping (not a file): $input_file\e[0m"; rc=1; continue; }
    [[ "$input_file" == *.gpg ]] || { echo -e "\e[1;33mskipping (not .gpg): $input_file\e[0m"; rc=1; continue; }

    output_file="${input_file%.gpg}"

    if print -r -- "$pass" | gpg --pinentry-mode loopback --passphrase-fd 0 --quiet --batch --yes --decrypt --output "$output_file" "$input_file" 2>/dev/null; then
      shred -u -- "$input_file" 2>/dev/null || rm -f -- "$input_file"
      echo -e "\e[1;32mDecrypted $input_file -> $output_file\e[0m"
    else
      echo -e "\e[1;31mDecryption failed for $input_file\e[0m"
      rc=1
    fi
  done

  return $rc
}

loadpg() { pkill -9 gpg-agent; export GPG_TTY=$(tty); }
