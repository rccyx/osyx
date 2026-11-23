typeset _zsh_config_root="${${(%):-%N}:A:h}"
typeset _zsh_file _zsh_directory

_zsh_load_exported_env() {
  emulate -L zsh
  setopt allexport
  local env_directory="${ZSF_EXPORTED_DIR:-$HOME/.exported}"
  local env_file
  local -U env_files=(
    "$env_directory"/.env(N.)
    "$env_directory"/*.env(N.)
    "$env_directory"/.env.*(N.)
  )

  for env_file in "${env_files[@]}"; do
    [[ -r "$env_file" ]] || continue
    source "$env_file" || return
  done
}
_zsh_load_exported_env
unfunction _zsh_load_exported_env

# Environment and completion must precede integrations and function definitions.
source "$_zsh_config_root/zsh/_env.zsh"
source "$ZSH/oh-my-zsh.sh"
source "$_zsh_config_root/zsh/core.zsh"

for _zsh_file in "$_zsh_config_root"/zsh/*.zsh(N.); do
  case "${_zsh_file:t}" in
    _env.zsh|core.zsh) continue ;;
  esac
  source "$_zsh_file"
done

# a directory entrypoint owns its children, otherwise load its direct Zsh files.
for _zsh_directory in "$_zsh_config_root"/zsh/*(N/); do
  if [[ -r "$_zsh_directory/entrypoint.zsh" ]]; then
    source "$_zsh_directory/entrypoint.zsh"
    continue
  fi

  for _zsh_file in "$_zsh_directory"/*.zsh(N.); do
    source "$_zsh_file"
  done
done

for _zsh_file in "$_zsh_config_root"/*/entrypoint.zsh(N.); do
  [[ "${_zsh_file:h:t}" == zsh ]] && continue
  source "$_zsh_file"
done

for _zsh_file in "$_zsh_config_root"/*/themes.zsh(N.); do
  source "$_zsh_file"
done

ulimit -c 0
unset _zsh_config_root _zsh_file _zsh_directory
