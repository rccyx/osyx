#!/usr/bin/env bash

[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"

set -Eeuo pipefail

# --- CONSTS ---
FONTS_REPO="rccyx/osyx"
FONTS_VERSION="fonts-v1.0.0"

FONT_DST="${HOME}/.local/share/fonts/osyx"
STATE_FILE="${FONT_DST}/.state/fonts.version"

if [ -t 1 ]; then
  green='\033[0;32m'
  cyan='\033[0;36m'
  yellow='\033[0;33m'
  bold='\033[1m'
  nc='\033[0m'
else
  green=''; cyan=''; yellow=''; bold=''; nc=''
fi

info() { printf '%b\n' "${cyan}${bold}i${nc} $*"; }
ok()   { printf '%b\n' "${green}${bold}✔${nc} $*"; }
warn() { printf '%b\n' "${yellow}${bold}⚠${nc} $*" >&2; }
step() { printf '\n%b\n' "${cyan}${bold}==>${nc} $*"; }

STAGING_DIR=""
cleanup() {
  [ -n "${STAGING_DIR:-}" ] && [ -d "${STAGING_DIR}" ] && rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT

verify_dependencies() {
  local deps=(curl tar fc-cache)
  local missing=0
  for cmd in "${deps[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      warn "Missing dependency: $cmd"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || { warn "Install missing dependencies and retry."; exit 1; }
}

main() {
  verify_dependencies

  step "Fonts (${FONTS_VERSION})"

  if [ -f "${STATE_FILE}" ] && [ "$(cat "${STATE_FILE}")" = "${FONTS_VERSION}" ]; then
    ok "Already at ${FONTS_VERSION}. Nothing to do."
    exit 0
  fi

  mkdir -p "${FONT_DST}" "${FONT_DST}/.state"
  STAGING_DIR="$(mktemp -d)"

  local url="https://github.com/${FONTS_REPO}/releases/download/${FONTS_VERSION}/${FONTS_VERSION}.tar.gz"
  local tar_path="${STAGING_DIR}/fonts.tar.gz"

  info "Downloading -> ${url}"
  if ! curl -sSLf --retry 3 --connect-timeout 10 -o "${tar_path}" "${url}"; then
    warn "Download failed."
    exit 1
  fi

  info "Extracting..."
  rm -rf "${FONT_DST:?}/Inter" "${FONT_DST:?}/iosevka-ss18" "${FONT_DST:?}/meslo"
  tar -xzf "${tar_path}" -C "${FONT_DST}"

  info "Updating font cache..."
  fc-cache -f "${FONT_DST}" >/dev/null 2>&1 || true

  echo "${FONTS_VERSION}" > "${STATE_FILE}"
  ok "Font sync complete."
}

main "$@"