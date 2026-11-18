#!/usr/bin/env bash
# Installs a systemd --user timer + service that runs bin/warmup.sh on a
# schedule with a given config file. Linux equivalent of
# install-macos-launchagent.sh. Safe to re-run.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  install-linux-systemd-timer.sh --name <unit-name> --config </abs/path/to/config.sh> \
      [--on-calendar "Mon..Fri 07:25"] [--dry-run]

  --name         Unit name, e.g. claude-warmup (creates claude-warmup.service/.timer)
  --config       Absolute path to a config file (see config/*.example.sh)
  --on-calendar  systemd OnCalendar expression (default: "Mon..Fri 07:25")
  --dry-run      Print the generated unit files to stdout; don't touch the
                 filesystem or call systemctl

Example:
  ./install-linux-systemd-timer.sh --name claude-warmup \
      --config "$HOME/.config/agent-warmup/claude.sh"

Requires a user systemd instance. For the timer to fire while you're logged
out, also run: loginctl enable-linger "$USER"
EOF
}

NAME=""
CONFIG=""
ON_CALENDAR="Mon..Fri 07:25"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) NAME="$2"; shift 2 ;;
        --config) CONFIG="$2"; shift 2 ;;
        --on-calendar) ON_CALENDAR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$NAME" || -z "$CONFIG" ]]; then
    echo "Both --name and --config are required." >&2
    usage
    exit 1
fi
if [[ ! -f "$CONFIG" ]]; then
    echo "Config file not found: $CONFIG" >&2
    exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WARMUP_SCRIPT="$REPO_DIR/bin/warmup.sh"
UNIT_DIR="$HOME/.config/systemd/user"

if [[ "$DRY_RUN" != true ]]; then
    chmod 700 "$WARMUP_SCRIPT"
    chmod 600 "$CONFIG" || true
    mkdir -p "$UNIT_DIR"
fi

render_service() {
    cat <<EOF
[Unit]
Description=Agent warm-up (${NAME})

[Service]
Type=oneshot
ExecStart=${WARMUP_SCRIPT} ${CONFIG}
EOF
}

render_timer() {
    cat <<EOF
[Unit]
Description=Schedule for agent warm-up (${NAME})

[Timer]
OnCalendar=${ON_CALENDAR}
Persistent=false

[Install]
WantedBy=timers.target
EOF
}

if [[ "$DRY_RUN" == true ]]; then
    echo "# ${NAME}.service"
    render_service
    echo
    echo "# ${NAME}.timer"
    render_timer
    exit 0
fi

render_service > "$UNIT_DIR/${NAME}.service"
render_timer > "$UNIT_DIR/${NAME}.timer"

systemctl --user daemon-reload
systemctl --user enable --now "${NAME}.timer"

echo "Installed and enabled: ${NAME}.timer (OnCalendar=${ON_CALENDAR}), config: $CONFIG"
echo "Run 'loginctl enable-linger $USER' so this fires even while logged out."
