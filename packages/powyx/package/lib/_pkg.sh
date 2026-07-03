POWYX_DEBIAN_PACKAGES=(
    qml-qt6
    qml6-module-qtquick
    qml6-module-qtquick-window
    qml6-module-qtquick-layouts
    libqt6svg6
)

POWYX_NO_INSTALL_DEPS=false

_powyx_parse_install_args() {
    while (($# > 0)); do
        case "$1" in
            --no-install-deps)
                POWYX_NO_INSTALL_DEPS=true
                ;;
            *)
                _powyx_error "unsupported argument: $1"
                ;;
        esac
        shift
    done
}

_powyx_is_debian() {
    [[ -f /etc/os-release ]] && grep -Eq '^ID=debian$|^ID="debian"$' /etc/os-release
}

_powyx_apt_get() {
    if [[ "$(id -u)" -eq 0 ]]; then
        apt-get "$@"
        return
    fi

    command -v sudo >/dev/null 2>&1 || _powyx_error "sudo not found"
    sudo apt-get "$@"
}

_powyx_install_runtime_deps() {
    if [[ "$POWYX_NO_INSTALL_DEPS" == true ]]; then
        _powyx_verify_qml_runner
        return
    fi

    if ! _powyx_is_debian; then
        printf 'powyx automatic dependency installation supports Debian only.\n' >&2
        printf 'Install the Qt/QML runtime from README.md, then rerun:\n' >&2
        printf '  ./package/install --no-install-deps\n' >&2
        exit 1
    fi

    command -v apt-get >/dev/null 2>&1 || _powyx_error "apt-get not found"

    local missing=()
    local package

    for package in "${POWYX_DEBIAN_PACKAGES[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q '^install ok installed$'; then
            missing+=("$package")
        fi
    done

    if [[ "${#missing[@]}" -gt 0 ]]; then
        _powyx_apt_get update -qq
        _powyx_apt_get install -y --no-install-recommends "${missing[@]}"
    fi

    _powyx_verify_qml_runner
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
