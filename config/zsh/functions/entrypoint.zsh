# guard: never run twice in the same shell
if [[ -n ${__ZSF_ENTRYPOINT_SOURCED-} ]]; then
  return
fi
typeset -g __ZSF_ENTRYPOINT_SOURCED=1

# resolve path to this file and its dir (works when sourced)
__zf_script="${(%):-%N}"
__zf_dir="${__zf_script:A:h}"
__self_base="${__zf_script:A:t}"

# export env early from ~/.exported before anything else
# override with ZSF_EXPORTED_DIR if you want a different folder
__zsf_load_env() {
  emulate -L zsh
  setopt null_glob
  set -a  # auto-export everything sourced
  local envdir="${ZSF_EXPORTED_DIR:-$HOME/.exported}"
  local f
  for f in "$envdir"/.env "$envdir"/*.env "$envdir"/.env.*; do
    [[ -r "$f" ]] || continue
    source "$f"
  done
  set +a
}
__zsf_load_env
unset -f __zsf_load_env

# utils first
if [[ -r "$__zf_dir/utils.zsh" ]]; then
  source "$__zf_dir/utils.zsh"
fi

# then every other .zsh in the folder, excluding self and utils
for f in "$__zf_dir"/*.zsh; do
  [[ ! -r "$f" ]] && continue
  [[ "${f:t}" == "utils.zsh" ]] && continue
  [[ "${f:t}" == "$__self_base" ]] && continue
  source "$f"
done

# completion is initialized once, not per file
if ! whence -w compdef >/dev/null 2>&1; then
  autoload -Uz compinit
  compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
fi

# folders
if [[ -r "$__zf_dir/aws/entrypoint.zsh" ]]; then
  source "$__zf_dir/aws/entrypoint.zsh"
fi

unset __zf_script __zf_dir __self_base

