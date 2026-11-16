# ISO → USB flasher with picker, progress, and strong verification (zsh)
flash() {
  emulate -L zsh
  setopt err_return pipefail
  setopt extendedglob

  local N=$'\033[0m' R=$'\033[31m' G=$'\033[32m' Y=$'\033[33m' C=$'\033[36m'
  _ts(){ date +%H:%M:%S; }
  _log(){ print -r -- "${C}[$(_ts)] $*${N}"; }
  _ok(){  print -r -- "${G}[$(_ts)] $*${N}"; }
  _warn(){print -r -- "${Y}[$(_ts)] $*${N}"; }
  _err(){ print -ru2 -- "${R}[$(_ts)] $*${N}"; }
  _have(){ command -v "$1" >/dev/null 2>&1; }

  _pick_iso() {
    local iso list
    if [[ -n "$1" && -f "$1" ]]; then print -r -- "$1"; return 0; fi
    if _have fd; then
      list=$(fd -HI -t f -e iso -e img . "$HOME/Downloads" 2>/dev/null)
    else
      list=$(find . "$HOME/Downloads" -maxdepth 3 -type f \( -iname '*.iso' -o -iname '*.img' \) 2>/dev/null)
    fi
    [[ -z "$list" ]] && { _err "no ISO files under . or ~/Downloads"; return 1; }
    if _have fzf; then
      print -r -- "$list" \
      | awk '{cmd="stat -c%s \""$0"\" 2>/dev/null || stat -f%z \""$0"\"" ; cmd|getline s; close(cmd); printf "%s\t%9.2f MB  %s\n",$0,s/1048576,$0 }' \
      | fzf --with-nth=2.. --prompt="pick ISO ⇢ " --height 60% --border --reverse \
      | cut -f1
    else
      print -r -- "${${(f)list}[1]}"
    fi
  }

  _pick_usb_disk() {
    local US=$'\x1f' line sel
    local -a rows; rows=()
    while IFS= read -r line; do
      eval "$line"  # NAME= MODEL= TRAN= SIZE= RM= TYPE=
      [[ "$TYPE" == "disk" ]] || continue
      [[ "$TRAN" == "usb" || "$RM" == "1" ]] || continue
      rows+=("/dev/${NAME}${US}${NAME}  ${MODEL:-?}  ${SIZE}  ${TRAN:-?}  RM=${RM}")
    done < <(lsblk -dn -o NAME,MODEL,TRAN,SIZE,RM,TYPE -P)

    [[ ${#rows[@]} -gt 0 ]] || { _err "no USB or removable disks detected"; return 1; }

    if _have fzf; then
      sel=$(printf "%s\n" "${rows[@]}" | sed "s/${US}/\t/" \
            | fzf --with-nth=2.. --prompt="pick target disk ⇢ " --height 60% --border --reverse) || return 1
      print -r -- "${sel%%	*}"
    else
      print -r -- "${rows[1]%%$US*}"
    fi
  }

  local iso dev isosz devsz dtype rootdisk parent
  iso=$(_pick_iso "$1") || return 1
  [[ -r "$iso" ]] || { _err "cannot read ISO: $iso"; return 1; }
  isosz=$(stat -c%s "$iso" 2>/dev/null || stat -f%z "$iso")

  if [[ -n "$2" ]]; then
    dev="$2"
  else
    dev=$(_pick_usb_disk) || return 1
  fi

  # sanitize
  dev=$(printf '%s' "$dev" | tr -d '\r' | awk '{$1=$1;print}')

  # get type for this node only
  dtype=$(lsblk -dn -o TYPE "$dev" 2>/dev/null | head -n1)
  if [[ "$dtype" != "disk" ]]; then
    parent=$(lsblk -no PKNAME "$dev" 2>/dev/null | head -n1 | tr -d '[:space:]')
    [[ -n "$parent" ]] || { _err "target must be a disk node, not a partition"; return 1; }
    _warn "you picked a partition ($dev); using its parent /dev/$parent"
    dev="/dev/$parent"
    dtype=$(lsblk -dn -o TYPE "$dev" 2>/dev/null | head -n1)
  fi
  [[ "$dtype" == "disk" ]] || { _err "target must be a disk node, not a partition"; return 1; }

  rootdisk=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null | head -n1 | tr -d '[:space:]')
  [[ -n "$rootdisk" && "/dev/$rootdisk" == "$dev" ]] && { _err "refusing to write to your root disk $dev"; return 1; }

  devsz=$(lsblk -bn -o SIZE "$dev" | head -n1)
  (( devsz >= isosz )) || { _err "device smaller than ISO"; return 1; }

  _log "ISO: $iso ($(numfmt --to=iec --suffix=B "$isosz" 2>/dev/null || echo "$isosz bytes"))"
  _log "USB: $dev  MODEL=$(lsblk -no MODEL "$dev")  SIZE=$(lsblk -no SIZE "$dev")  TRAN=$(lsblk -no TRAN "$dev")"
  printf "%sType %sFLASH%s to erase %s and write the image ⇢ %s" "$Y" "$Y" "$N" "$dev" "$N"
  local ans; read -r ans; [[ "$ans" == "FLASH" ]] || { _err "aborted"; return 1; }

  _log "unmounting any mounted partitions"
  lsblk -nrpo NAME,MOUNTPOINT "$dev" | awk '$2!=""{print $1}' | while read -r p; do sudo umount "$p" >/dev/null 2>&1 || :; done
  _have udevadm && sudo udevadm settle || :

  _log "clearing first MiB"
  sudo dd if=/dev/zero of="$dev" bs=1M count=1 conv=fsync status=none

  _log "writing image with progress"
  if _have pv; then
    pv "$iso" | sudo dd iflag=fullblock oflag=direct conv=fsync bs=4M of="$dev" status=progress
  else
    sudo dd if="$iso" of="$dev" iflag=fullblock oflag=direct conv=fsync bs=4M status=progress
  fi
  sync
  sudo blockdev --flushbufs "$dev" 2>/dev/null || :

  _warn "you may see: driver descriptor 2048 vs Linux 512. This is normal for hybrid ISOs."

  _log "refreshing partition table"
  sudo partprobe "$dev" >/dev/null 2>&1 || sudo blockdev --rereadpt "$dev" >/dev/null 2>&1 || :
  _log "layout:"
  lsblk -o NAME,FSTYPE,SIZE,TYPE,MOUNTPOINT,MODEL "$dev"

  _log "verify 1/2: hashing first 64 MiB (or full size if smaller)"
  local quick=$((64*1024*1024))
  local read_n=$(( isosz < quick ? isosz : quick ))
  local iso_q dev_q
  if _have pv; then
    iso_q=$(head -c "$read_n" "$iso" | pv -s "$read_n" | sha256sum | awk '{print $1}')
    dev_q=$(sudo dd if="$dev" bs=1M count=$(( (read_n+1048575)/1048576 )) status=none | head -c "$read_n" | pv -s "$read_n" | sha256sum | awk '{print $1}')
  else
    iso_q=$(head -c "$read_n" "$iso" | sha256sum | awk '{print $1}')
    dev_q=$(sudo dd if="$dev" bs=1M count=$(( (read_n+1048575)/1048576 )) status=none | head -c "$read_n" | sha256sum | awk '{print $1}')
  fi
  if [[ "$iso_q" != "$dev_q" ]]; then
    _err "verify failed on first $read_n bytes"
    return 2
  fi
  _ok "partial hash OK"

  _log "verify 2/2: full ISO length hash"
  local iso_h dev_h
  if _have pv; then
    iso_h=$(pv -s "$isosz" "$iso" | sha256sum | awk '{print $1}')
    dev_h=$(sudo dd if="$dev" bs=4M count=$(( (isosz+4194303)/4194304 )) status=none | head -c "$isosz" | pv -s "$isosz" | sha256sum | awk '{print $1}')
  else
    iso_h=$(sha256sum "$iso" | awk '{print $1}')
    dev_h=$(sudo dd if="$dev" bs=4M count=$(( (isosz+4194303)/4194304 )) status=none | head -c "$isosz" | sha256sum | awk '{print $1}')
  fi
  if [[ "$iso_h" == "$dev_h" ]]; then
    _ok "verify OK  sha256=$iso_h"
  else
    _err "verify failed  iso=$iso_h  dev=$dev_h"
    return 2
  fi

  if _have udisksctl; then
    _log "powering device off"
    sudo udisksctl power-off -b "$dev" >/dev/null 2>&1 || :
  fi

  _ok "done. boot from the USB."
}
