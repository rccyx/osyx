reboot() {
  emulate -L zsh
  setopt localoptions errreturn pipefail

  systemctl reboot
}
