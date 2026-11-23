# ================================
#  FINGERPRINT CONTROL
#  deps: fprintd, libpam-fprintd (already set through the dotfiles)
# ================================

# Canonical finger labels used by fprintd
typeset -a FP_FINGERS=(
  left-thumb left-index-finger left-middle-finger left-ring-finger left-little-finger
  right-thumb right-index-finger right-middle-finger right-ring-finger right-little-finger
)

# ------- helpers -------
_fp_restart(){ sudo systemctl restart fprintd >/dev/null 2>&1 || true; }
_fp_have_line_in_sudo(){
  sudo grep -qE '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_fprintd\.so' /etc/pam.d/sudo
}
_fp_add_line_to_sudo(){
  _fp_have_line_in_sudo || {
    sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.bak
    echo | sudo tee /etc/pam.d/.sudo.tmp >/dev/null
    { echo 'auth sufficient pam_fprintd.so'; cat /etc/pam.d/sudo; } | sudo tee /etc/pam.d/.sudo.tmp >/dev/null
    sudo mv /etc/pam.d/.sudo.tmp /etc/pam.d/sudo
  }
}
_fp_rm_line_from_sudo(){
  sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.bak
  sudo sed -i '/pam_fprintd\.so/d' /etc/pam.d/sudo
}

# ------- status & quick tests -------
fp_status(){
  _note "device list"
  lsusb | grep -i goodix || true
  _note "enrolled prints for $USER"
  fprintd-list "$USER" || true
  _note "pam presence"
  grep -n 'pam_fprintd.so' /etc/pam.d/common-auth /etc/pam.d/sudo 2>/dev/null || echo "no pam_fprintd lines found"
}
fp_test(){ fprintd-verify; }

# ------- enroll flow -------
fp_enroll(){
  local finger="$1"
  if [[ -z "$finger" ]]; then
    finger=$(printf "%s\n" "${FP_FINGERS[@]}" | fzf --prompt="👉 pick finger to enroll ⇢ ")
    [[ -z "$finger" ]] && { _err "no finger chosen"; return 1; }
  fi
  _fp_restart
  _note "enrolling $finger"
  fprintd-enroll -f "$finger"
}
fp_enroll_multi(){
  local -a picks
  picks=("${(@f)$(printf "%s\n" "${FP_FINGERS[@]}" | fzf --multi --height 60% --prompt="👉 pick finger(s) ⇢ ")}")
  [[ ${#picks[@]} -eq 0 ]] && { _err "no fingers chosen"; return 1; }
  _fp_restart
  for f in "${picks[@]}"; do
    _note "enrolling $f"
    fprintd-enroll -f "$f"
  done
  _ok "enrolled ${#picks[@]} finger(s)"
}

# ------- delete prints -------
fp_list(){ fprintd-list "$USER"; }
fp_delete(){
  # fp_delete [finger]  or  fp_delete all
  local which="$1"
  if [[ -z "$which" || "$which" == "all" ]]; then
    _note "deleting all prints for $USER"
    fprintd-delete "$USER"
  else
    _note "deleting $which for $USER"
    # try both long and short forms because distros differ
    fprintd-delete --finger "$which" "$USER" 2>/dev/null || fprintd-delete -f "$which" "$USER"
  fi
}
fp_nuke(){ fp_delete all; }

# ------- switch default finger (practical meaning: wipe then enroll one) -------
fp_switch(){
  local finger="$1"
  [[ -z "$finger" ]] && finger=$(printf "%s\n" "${FP_FINGERS[@]}" | fzf --prompt="👉 pick new primary finger ⇢ ")
  [[ -z "$finger" ]] && { _err "no finger chosen"; return 1; }
  fp_nuke || true
  fp_enroll "$finger"
}

# ------- PAM modes -------
# login+sudo: enable via common-auth and keep sudo clean
fp_mode_login_sudo(){
  _note "enabling fingerprint in common-auth"
  sudo pam-auth-update --enable fprintd --force
  _note "removing direct sudo override line if present"
  _fp_rm_line_from_sudo
  _ok "mode set: login + sudo"
}
# sudo-only: disable from common-auth, add direct line to sudo
fp_mode_sudo_only(){
  _note "disabling fingerprint in common-auth"
  sudo pam-auth-update --remove fprintd --force
  _note "adding sudo-only line"
  _fp_add_line_to_sudo
  _ok "mode set: sudo only"
}
# off: remove from both
fp_mode_off(){
  _note "disabling fingerprint in common-auth"
  sudo pam-auth-update --remove fprintd --force
  _note "removing sudo override line"
  _fp_rm_line_from_sudo
  _ok "mode set: off"
}

# ------- full reset then enroll workflow -------
fp_setup_from_scratch(){
  _note "restart fprintd"
  _fp_restart
  _note "wipe existing prints"
  fp_nuke || true
  _note "choose one or more fingers to enroll"
  fp_enroll_multi
  _ok "done. now choose a PAM mode: fp_mode_login_sudo or fp_mode_sudo_only"
}
