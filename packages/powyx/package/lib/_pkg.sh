POWYX_DEBIAN_PACKAGES=(
    bash
    coreutils
    grep
    qml6
    qml6-module-qtquick
    qml6-module-qtquick-window
    qml6-module-qtquick-layouts
    qml6-module-qtsvg
)

_powyx_require_debian() {
    if ! [[ -f /etc/os-release ]]; then
        printf 'powyx supports Debian only\n' >&2
        exit 1
    fi

    if ! grep -Eq '^ID=debian$|^ID="debian"$' /etc/os-release; then
        printf 'powyx supports Debian only\n' >&2
        exit 1
    fi
}

_powyx_apt_get() {
    if [[ "$(id -u)" -eq 0 ]]; then
        apt-get "$@"
        return
    fi

    command -v sudo >/dev/null 2>&1 || _powyx_error "sudo not found"
    sudo apt-get "$@"
}

_powyx_install_debian_runtime_deps() {
    _powyx_require_debian
    command -v apt-get >/dev/null 2>&1 || _powyx_error "apt-get not found"

    local missing=()
    local package

    for package in "${POWYX_DEBIAN_PACKAGES[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q '^install ok installed$'; then
            missing+=("$package")
        fi
    done

    if [[ "${#missing[@]}" -eq 0 ]]; then
        return
    fi

    _powyx_apt_get update -qq
    _powyx_apt_get install -y --no-install-recommends "${missing[@]}"
    command -v qml6 >/dev/null 2>&1 || _powyx_error "qml6 not found after dependency install"
}

_powyx_read_action_config() {
    [[ -f "$POWYX_CONFIG_FILE" ]] || _powyx_error "missing config: $POWYX_CONFIG_FILE"

    POWYX_LOCK_CMD="$(_powyx_read_action_command lock)"
    POWYX_SUSPEND_CMD="$(_powyx_read_action_command suspend)"
    POWYX_REBOOT_CMD="$(_powyx_read_action_command reboot)"
    POWYX_SHUTDOWN_CMD="$(_powyx_read_action_command shutdown)"
}

_powyx_read_action_command() {
    local key="$1"
    local value

    value="$(sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"\\(.*\\)\"[[:space:]]*$/\\1/p" "$POWYX_CONFIG_FILE")"
    printf '%s\n' "$value"
}

_powyx_validate_action_config() {
    _powyx_validate_exact_action_keys
    [[ -n "$POWYX_LOCK_CMD" ]] || _powyx_error "lock action is empty"
    [[ -n "$POWYX_SUSPEND_CMD" ]] || _powyx_error "suspend action is empty"
    [[ -n "$POWYX_REBOOT_CMD" ]] || _powyx_error "reboot action is empty"
    [[ -n "$POWYX_SHUTDOWN_CMD" ]] || _powyx_error "shutdown action is empty"
}

_powyx_validate_exact_action_keys() {
    local keys

    keys="$(sed -n '/^[[:space:]]*\[actions\][[:space:]]*$/,$ s/^[[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\)[[:space:]]*=.*/\1/p' "$POWYX_CONFIG_FILE" | sort | tr '\n' ' ')"
    [[ "$keys" == "lock reboot shutdown suspend " ]] || _powyx_error "config actions must be exactly: lock, suspend, reboot, shutdown"
}

_powyx_dispatch_qml_exit_code() {
    local exit_code="$1"

    case "$exit_code" in
        0)
            return 0
            ;;
        10)
            _powyx_run_action_command "$POWYX_LOCK_CMD"
            ;;
        11)
            _powyx_run_action_command "$POWYX_SUSPEND_CMD"
            ;;
        12)
            _powyx_run_action_command "$POWYX_REBOOT_CMD"
            ;;
        13)
            _powyx_run_action_command "$POWYX_SHUTDOWN_CMD"
            ;;
        *)
            printf 'powyx: qml exited with unexpected code %s\n' "$exit_code" >&2
            return "$exit_code"
            ;;
    esac
}

_powyx_run_action_command() {
    local command="$1"

    [[ -n "$command" ]] || _powyx_error "action command is empty"
    bash -lc -- "$command"
}
