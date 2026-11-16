# ─────────────────────────────────────────────
# This file sources everything. The actual config lives in:
#   zsh/_aliases.zsh   → aliases (personal — @rccyx)
#   zsh/_env.zsh       → locale, PATH, toolchains, GPG (personal - @rccyx)
#   zsh/core.zsh       → completion, shell options, history (common)
#   zsh/tools.zsh      → starship, zoxide, thefuck, fzf (common)
#
# ─────────────────────────────────────────────

# Personal env (locale, PATH, OMZ plugins, toolchains)
# Must come first — sets up PATH and OMZ before anything else.
source "$HOME/zsh/_env.zsh"

# Oh My Zsh load (needs ZSH and plugins from _env.zsh)
source "$ZSH/oh-my-zsh.sh"

# Shell core (completion, setopts, history)
source "$HOME/zsh/core.zsh"

# Tool integrations (starship, zoxide, thefuck, fzf)
source "$HOME/zsh/tools.zsh"

# Personal aliases
source "$HOME/zsh/_aliases.zsh"

# Jarvis command center
[ -f "$HOME/jarvis/entrypoint.zsh" ] && source "$HOME/jarvis/entrypoint.zsh"

# This auto sources/execs everything in osyx root slash bin (add that folder to home if not added, bootstrap does it)
# Whenever a new file is added, no need to chmod again
export PATH="$HOME/bin:$PATH"

for file in "$HOME/bin"/*(N.); do
  case "${file:t}" in
    README.md|_install_) continue ;;
  esac

  [[ -x "$file" ]] || chmod u+x -- "$file"
done


# Theme orchestrator (dircolors, live reload, themes function)
source "$HOME/flavors/themes.zsh"

# cashout potential
ulimit -c 0


# >>> osyx:pnpm >>>
export PNPM_HOME="$HOME/.local/share/pnpm"

typeset -U PATH path

path=(
  "$PNPM_HOME/bin"
  "$PNPM_HOME"
  $path
)

export PATH
# <<< osyx:pnpm <<<

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
