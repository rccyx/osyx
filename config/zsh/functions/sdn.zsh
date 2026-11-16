sdn() {
  emulate -L zsh
  setopt localoptions errreturn pipefail

  systemctl poweroff
}
