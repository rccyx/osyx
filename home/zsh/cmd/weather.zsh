weather() {
  emulate -L zsh
  setopt localoptions errreturn pipefail

  curl -s "wttr.in/?0"
}
