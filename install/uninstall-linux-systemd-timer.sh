#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 ]]; then
    echo "Usage: uninstall-linux-systemd-timer.sh <unit-name>" >&2
    exit 1
fi
NAME="$1"
systemctl --user disable --now "${NAME}.timer" 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/${NAME}.service" "$HOME/.config/systemd/user/${NAME}.timer"
systemctl --user daemon-reload 2>/dev/null || true
echo "Removed ${NAME}.service/.timer"
