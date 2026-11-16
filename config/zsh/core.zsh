# ───────────────────────────────
# Shell core — common osyx shell foundation
# Completion engine, shell options, history, and timing format.
# ───────────────────────────────

# ─── Completion ───
zmodload zsh/complist
if (( ! $+functions[compdef] )); then
  autoload -Uz compinit
  mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' rehash true
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# include dotfiles in completion
_comp_options+=(globdots)

# ─── Shell options ───
setopt autocd
setopt interactivecomments
setopt magicequalsubst
setopt nonomatch
setopt notify
setopt numericglobsort
setopt promptsubst

WORDCHARS=${WORDCHARS//\\/}   # treat slash as a word boundary
PROMPT_EOL_MARK=""           # hide %

# ─── History ───
HISTFILE="$HOME/.zsh_history"
HISTSIZE=1000
SAVEHIST=2000
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_verify
alias history="history 0"

# `time` format
TIMEFMT=$'\nreal\t%E\nuser\t%U\nsys\t%S\ncpu\t%P'
