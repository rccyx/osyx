suspend() {
  emulate -L zsh
  setopt localoptions errreturn pipefail

  systemctl suspend
}
