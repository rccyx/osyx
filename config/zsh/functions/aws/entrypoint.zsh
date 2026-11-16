if [[ -n ${__ZSF_AWS_ENTRYPOINT_SOURCED-} ]]; then
  return
fi
typeset -g __ZSF_AWS_ENTRYPOINT_SOURCED=1

__zf_script="${(%):-%N}"
__zf_dir="${__zf_script:A:h}"
__self_base="${__zf_script:A:t}"

for f in "$__zf_dir"/*.zsh; do
  [[ ! -r "$f" ]] && continue
  [[ "${f:t}" == "utils.zsh" ]] && continue
  [[ "${f:t}" == "$__self_base" ]] && continue
  source "$f"
done

if ! whence -w compdef >/dev/null 2>&1; then
  autoload -Uz compinit
  compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
fi

unset __zf_script __zf_dir __self_base

