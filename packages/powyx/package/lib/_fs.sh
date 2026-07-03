_powyx_reject_unsafe_remove_path() {
    local path="$1"

    [[ -n "$path" ]] || _powyx_error "refusing to remove empty path"
    [[ "$path" = /* ]] || _powyx_error "refusing to remove relative path: $path"
    [[ "$path" != "/" ]] || _powyx_error "refusing to remove /"
    [[ "$path" != "$HOME" ]] || _powyx_error "refusing to remove home directory"
}

_powyx_remove_tree() {
    local path="$1"

    _powyx_reject_unsafe_remove_path "$path"
    [[ -e "$path" ]] || return 0
    rm -rf -- "$path"
}

_powyx_install_files_atomically() {
    _powyx_remove_tree "$POWYX_STAGE_DIR"
    _powyx_remove_tree "$POWYX_PREVIOUS_DIR"

    mkdir -p "$POWYX_STAGE_DIR"
    cp -a "$POWYX_REPO_ROOT/src" "$POWYX_STAGE_DIR/src"
    cp -a "$POWYX_REPO_ROOT/icons" "$POWYX_STAGE_DIR/icons"
    cp -a "$POWYX_REPO_ROOT/config" "$POWYX_STAGE_DIR/config"

    if [[ -e "$POWYX_SHARE_DIR" ]]; then
        mv "$POWYX_SHARE_DIR" "$POWYX_PREVIOUS_DIR"
    fi

    if ! mv "$POWYX_STAGE_DIR" "$POWYX_SHARE_DIR"; then
        if [[ -e "$POWYX_PREVIOUS_DIR" ]]; then
            mv "$POWYX_PREVIOUS_DIR" "$POWYX_SHARE_DIR"
        fi
        _powyx_error "failed to activate share files"
    fi

    if ! [[ -f "$POWYX_SHARE_DIR/src/Main.qml" ]]; then
        _powyx_remove_tree "$POWYX_SHARE_DIR"
        if [[ -e "$POWYX_PREVIOUS_DIR" ]]; then
            mv "$POWYX_PREVIOUS_DIR" "$POWYX_SHARE_DIR"
        fi
        _powyx_error "installed share files failed verification"
    fi

    _powyx_remove_tree "$POWYX_PREVIOUS_DIR"
    mkdir -p "$POWYX_BIN_DIR"
    install -m 0755 "$POWYX_REPO_ROOT/package/powyx" "$POWYX_BIN_PATH"
}

_powyx_install_default_config() {
    mkdir -p "$POWYX_CONFIG_DIR"
    if [[ -f "$POWYX_CONFIG_FILE" ]]; then
        _powyx_log "preserved $POWYX_CONFIG_FILE"
        return
    fi

    install -m 0644 "$POWYX_REPO_ROOT/config/powyx.toml" "$POWYX_CONFIG_FILE"
}

_powyx_uninstall_binary() {
    [[ -e "$POWYX_BIN_PATH" ]] || return 0
    rm -f -- "$POWYX_BIN_PATH"
}

_powyx_uninstall_share() {
    _powyx_remove_tree "$POWYX_SHARE_DIR"
}

_powyx_preserve_config() {
    _powyx_log "preserved $POWYX_CONFIG_FILE"
}
