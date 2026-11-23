hibernate() {
  emulate -L zsh
  setopt localoptions errreturn pipefail

  systemctl hibernate
}

