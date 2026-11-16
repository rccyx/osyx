logout() {
  emulate -L zsh
  setopt localoptions errreturn pipefail

  hyprshutdown -t 'Logging out...'
}
