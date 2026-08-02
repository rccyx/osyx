# ─────────────────────────────────────────────
# Personal environment — @rccyx
# My locale, PATH, Oh My Zsh, toolchains, GPG, editors.
# Replace with your own paths and toolchain setup.
# ─────────────────────────────────────────────

# ─── Locale ───
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8

# ─── Oh My Zsh ───
export ZSH="$HOME/.oh-my-zsh"
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# ─── PATH ───
typeset -U PATH path

path=(
  $HOME/.local/bin
  $HOME/bin
)

path+=(
  $HOME/.nix-profile/bin
  $HOME/miniconda3/bin
  $HOME/.tfenv/bin
  $HOME/.cargo/bin
  $HOME/go/bin
  $HOME/.bun/bin
  $HOME/mathlab/MATLAB/R2024b/bin
  $HOME/.console-ninja/.bin
  /usr/local/go/bin
)

path+=(
  /usr/local/bin
  /usr/bin
  /usr/sbin
  /bin
  /sbin
)

export PATH

# Make system themes/fonts visible to Nix apps
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:$HOME/.nix-profile/share"
export NIXPKGS_ALLOW_UNFREE=1

# Modern Nix init (no nix-env)
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# ─── Editor ───
export EDITOR="nvim"

# SSH ergonomics
if [[ -n "$SSH_CONNECTION" ]]; then
  export PINENTRY_USER_DATA='USE_CURSES=1'
fi

# GPG pinentry on current tty
export GPG_TTY="$(tty 2>/dev/null || echo /dev/pts/0)"

# ─── Toolchains (loaded once) ───
if [[ -z "$_ZSH_ENV_LOADED" ]]; then
  # Nix
  if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 2>/dev/null || :

  # Conda
  if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    . "$HOME/miniconda3/etc/profile.d/conda.sh"
  fi

  # NVM & Node
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

  # bun
  export BUN_INSTALL="$HOME/.bun"

  # go
  export GOPATH="$HOME/go"

  # Rust
  export PATH="$HOME/.cargo/bin:$PATH"

  export _ZSH_ENV_LOADED=1
fi

# command-not-found (Debian/Ubuntu)
[ -f /etc/zsh_command_not_found ] && . /etc/zsh_command_not_found

# GPG explicit tty override
export GPG_TTY=/dev/pts/2
