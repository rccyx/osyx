# ───────────────────────────────
# Tools — shell integrations
# Starship prompt, zoxide, thefuck, FZF defaults.
# ───────────────────────────────

# thefuck
eval "$(thefuck --alias)"

# zoxide (smart cd)
eval "$(zoxide init zsh)"

# Starship prompt
eval "$(starship init zsh)"
export STARSHIP_CONFIG="$HOME/.config/starship.toml"

# ─── FZF defaults ───
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_DEFAULT_OPTS='
  --layout=reverse
  --border=rounded
  --margin=2
  --padding=1
  --prompt=" "
  --pointer="▶"
  --marker="✓"
  --preview-window=hidden
  --color="bg+:-1,bg:-1,fg:-1,fg+:#ffffff,hl:#707070,hl+:#ffffff,header:bold:#909090,prompt:#ffffff,pointer:#ffffff,border:#404040"
'
