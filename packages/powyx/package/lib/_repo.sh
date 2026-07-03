_powyx_find_repo_root() {
    local script_dir="$1"

    POWYX_REPO_ROOT="$(cd "$script_dir/.." && pwd)"
    [[ -f "$POWYX_REPO_ROOT/config/powyx.toml" ]] || _powyx_error "cannot find powyx repo root"
}

_powyx_print_install_plan() {
    printf '\n'
    printf '  powyx install\n'
    printf '  share  %s\n' "$POWYX_SHARE_DIR"
    printf '  binary %s\n' "$POWYX_BIN_PATH"
    printf '  config %s\n' "$POWYX_CONFIG_FILE"
    printf '  log    %s\n' "$POWYX_LOG_FILE"
    printf '\n'
}

_powyx_print_uninstall_plan() {
    printf '\n'
    printf '  powyx uninstall\n'
    printf '  remove binary %s\n' "$POWYX_BIN_PATH"
    printf '  remove share  %s\n' "$POWYX_SHARE_DIR"
    printf '  keep config   %s\n' "$POWYX_CONFIG_FILE"
    printf '  log           %s\n' "$POWYX_LOG_FILE"
    printf '\n'
}

_powyx_verify_install() {
    [[ -x "$POWYX_BIN_PATH" ]] || _powyx_error "binary install failed"
    [[ -f "$POWYX_SHARE_DIR/src/Main.qml" ]] || _powyx_error "share install failed"
    [[ -f "$POWYX_CONFIG_FILE" ]] || _powyx_error "config install failed"
    _powyx_log "install complete"
}

_powyx_verify_uninstall() {
    [[ ! -e "$POWYX_BIN_PATH" ]] || _powyx_error "binary uninstall failed"
    [[ ! -e "$POWYX_SHARE_DIR" ]] || _powyx_error "share uninstall failed"
    _powyx_log "uninstall complete"
}
