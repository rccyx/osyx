#!/usr/bin/env bash
set -euo pipefail

# the final destroy must never run against the developer's workstation
test -f /.dockerenv
test "$(id -u)" -eq 0

cd /workspace

export DEBIAN_FRONTEND=noninteractive

readonly home=/home/smoke

provision()
{
    ./provisioning/main "$@" --user smoke
}

original_bashrc="$(sha256sum "$home/.bashrc")"

PYTHONPATH=provisioning/src /usr/bin/python3 -B -m unittest discover \
    -s provisioning/tests -v

provision plan workstation

./provisioning/bootstrap \
    --user smoke \
    --locale en_US.UTF-8 \
    --timezone Etc/UTC \
    --replace-home \
    --yes

provision doctor workstation
cmp home/.bashrc "$home/.bashrc"
test -f "$home/flavors/generate.py"

# repeat the entire graph to catch non-idempotent resources
provision apply workstation --yes
provision doctor workstation

runuser -u smoke -- env \
    HOME="$home" \
    PATH="$home/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    bash -ec '
        cd /workspace/provisioning
        mypy --cache-dir=/dev/null src tests
        ruff check --no-cache src tests
    '

# example with btop
provision destroy btop --yes
if command -v btop >/dev/null; then
    echo 'btop still installed after destroy' >&2
    exit 1
fi

provision apply btop --yes
provision doctor btop

provision destroy fonts --yes
test ! -e "$home/.local/share/fonts/osyx"

provision apply fonts --yes
provision doctor fonts

provision destroy battery --yes
test ! -e "$home/.local/bin/battery-notify"
test ! -e "$home/.config/systemd/user/battery-notify.service"
test ! -e "$home/.config/systemd/user/battery-notify.timer"
test ! -L "$home/.config/systemd/user/timers.target.wants/battery-notify.timer"

provision apply battery --yes
provision doctor battery

provision doctor workstation
provision plan workstation --destroy
provision destroy workstation --yes

test ! -e "$home/flavors/generate.py"
test ! -e "$home/.local/share/osyx/packages/go"
test ! -e "$home/.local/share/osyx/packages/rust"
test ! -e "$home/.local/share/fonts/osyx"
test ! -e "$home/.local/bin/battery-notify"

printf '%s\n' "$original_bashrc" | sha256sum --check --status
test "$(getent passwd smoke | cut -d: -f7)" = /bin/bash

command -v git >/dev/null
command -v python3 >/dev/null
command -v sudo >/dev/null
