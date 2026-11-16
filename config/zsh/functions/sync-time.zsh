sync-time() {
  emulate -L zsh
  setopt localoptions errreturn pipefail

  echo "Syncing time..."
  sudo systemctl restart systemd-timesyncd
}
