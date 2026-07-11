POWYX_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
POWYX_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
POWYX_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

POWYX_SHARE_DIR="$POWYX_DATA_HOME/powyx"
POWYX_STAGE_DIR="$POWYX_DATA_HOME/.powyx.stage"
POWYX_PREVIOUS_DIR="$POWYX_DATA_HOME/.powyx.previous"
POWYX_CONFIG_DIR="$POWYX_CONFIG_HOME/powyx"
POWYX_CONFIG_FILE="$POWYX_CONFIG_DIR/powyx.toml"
POWYX_BIN_DIR="$HOME/.local/bin"
POWYX_BIN_PATH="$POWYX_BIN_DIR/powyx"
POWYX_LOG_DIR="$POWYX_CACHE_HOME/powyx"

_powyx_log() {
    printf '[powyx] %s\n' "$*"
}

_powyx_error() {
    printf 'powyx: %s\n' "$*" >&2
    exit 1
}

_powyx_setup_log() {
    local name="$1"
    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$POWYX_LOG_DIR"
    POWYX_LOG_FILE="$POWYX_LOG_DIR/$name-$timestamp.log"
    exec > >(tee -a "$POWYX_LOG_FILE") 2>&1
}

_powyx_find_installed_share_dir() {
    [[ -f "$POWYX_SHARE_DIR/src/Main.qml" ]] || _powyx_error "share files not found at $POWYX_SHARE_DIR"
}

_powyx_find_qml_runner() {
    if command -v qml6 >/dev/null 2>&1; then
        POWYX_QML_RUNNER="$(command -v qml6)"
        return
    fi

    if command -v qml >/dev/null 2>&1 && qml --version 2>/dev/null | grep -q '6\.'; then
        POWYX_QML_RUNNER="$(command -v qml)"
        return
    fi

    _powyx_error "qml runner not found"
}

_powyx_verify_qml_runner() {
    _powyx_find_qml_runner >/dev/null
}

_powyx_launch_qml() {
    "$POWYX_QML_RUNNER" --apptype gui "$POWYX_SHARE_DIR/src/Main.qml" -- --confirm="$POWYX_CONFIRM"
}
