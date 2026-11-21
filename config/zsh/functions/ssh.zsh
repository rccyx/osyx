# ===============================================================
#   SSH POWERKIT — elite UX zsh functions for SSH workflows
#   deps: fzf, xclip, ssh, ssh-agent
# ===============================================================

# colors
clr(){ printf "\e[%sm" "$1"; }
_err(){ clr 31; echo "❌ $1"; clr 0; }
_ok(){ clr 32; echo "✅ $1"; clr 0; }
_note(){ clr 34; echo "ℹ️  $1"; clr 0; }

# ===============================================================
# sshgen [name] — generate new ed25519 keypair with name, copy pub
# ===============================================================
sshgen() {
  local name="${1:-id_ed25519_custom}"
  local path="$HOME/.ssh/$name"

  [[ -f "$path" ]] && {
    _err "Key '$path' already exists. Choose a new name or delete the old one."
    return 1
  }

  ssh-keygen -t ed25519 -f "$path" -C "$USER@$(hostname)" -q -N ""
  [[ $? -ne 0 ]] && _err "ssh-keygen failed" && return 1

  eval "$(ssh-agent -s)" >/dev/null
  ssh-add "$path"

  cat "${path}.pub" | xclip -selection clipboard
  _ok "SSH key '${name}.pub' created and copied to clipboard"
  echo "🧠 Paste it into GitHub or your server now."
}

# ===============================================================
# sshsave [keyname] — send your pubkey to a remote server
# ===============================================================
sshsave() {
  local keyfile="$HOME/.ssh/${1:-id_ed25519}.pub"
  [[ ! -f "$keyfile" ]] && _err "Key $keyfile doesn't exist" && return 1

  echo -n "🔗 Server (user@host): "; read -r remote
  [[ -z "$remote" ]] && _err "missing remote" && return 1

  echo "📤 Sending $keyfile → $remote"
  ssh "$remote" "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" < "$keyfile" \
    && _ok "Key sent and saved on $remote"
}

# ===============================================================
# sshlist — fuzzy-pick host from ~/.ssh/config and connect
# ===============================================================
sshlist() {
  [[ ! -f ~/.ssh/config ]] && _err "No ~/.ssh/config file found" && return 1

  local host=$(awk '/^Host / {print $2}' ~/.ssh/config | fzf --prompt="💻 Pick host ⇢ ")
  [[ -z "$host" ]] && _err "no host chosen" && return 1

  echo "🚀 Connecting to $host"
  ssh "$host"
}

# ===============================================================
# sshconf — create new Host entry in ~/.ssh/config interactively
# ===============================================================
sshconf() {
  echo -n "💾 Host alias (e.g. myserver): "; read -r alias
  echo -n "🔗 HostName (IP or domain): "; read -r host
  echo -n "👤 User (default: $USER): "; read -r user
  [[ -z "$user" ]] && user="$USER"
  echo -n "🔑 Identity file (default: ~/.ssh/id_ed25519): "; read -r key
  [[ -z "$key" ]] && key="~/.ssh/id_ed25519"

  echo "
Host $alias
  HostName $host
  User $user
  IdentityFile $key
" >> ~/.ssh/config

  _ok "SSH config for '$alias' added"
}

# ===============================================================
# sshclean — fuzzy remove broken known_hosts entries
# ===============================================================
sshclean() {
  local kh=~/.ssh/known_hosts
  [[ ! -f "$kh" ]] && _err "no known_hosts found" && return 1

  local line=$(cat "$kh" | nl | fzf --prompt="🧽 Clean known_hosts ⇢ " --height=40% --reverse)
  [[ -z "$line" ]] && _err "nothing chosen" && return 1

  local lineno=$(echo "$line" | awk '{print $1}')
  sed -i "${lineno}d" "$kh" && _ok "line $lineno removed from known_hosts"
}

# Show SSH public keys quick
mykeys() {
  cat ~/.ssh/*.pub
}

# ===============================================================
# autocompletion: sshsave <keyname>
# ===============================================================
_ssh_keys(){
  local -a keys
  keys=(${(f)"$(ls ~/.ssh/*.pub 2>/dev/null | sed 's|.pub$||')"})
  _describe 'ssh keys' keys
}
compdef _ssh_keys sshsave
