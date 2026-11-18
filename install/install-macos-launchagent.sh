#!/usr/bin/env bash
# Installs a macOS LaunchAgent that runs bin/warmup.sh on a schedule with a
# given config file. Safe to re-run: it overwrites the previous plist with
# the same label and reloads it.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  install-macos-launchagent.sh --label <reverse-dns-label> --config </abs/path/to/config.sh> \
      [--days 1,2,3,4,5] [--hour 7] [--minute 25]

  --label    LaunchAgent label, e.g. com.me.claude-warmup
  --config   Absolute path to a config file (see config/*.example.sh)
  --days     Comma-separated weekdays, 0=Sunday..6=Saturday (default: 1,2,3,4,5)
  --hour     Hour to run at, 24h (default: 7)
  --minute   Minute to run at (default: 25)

Example:
  ./install-macos-launchagent.sh --label com.me.claude-warmup \
      --config "$HOME/.config/agent-warmup/claude.sh"
EOF
}

DAYS="1,2,3,4,5"
HOUR=7
MINUTE=25
LABEL=""
CONFIG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --label) LABEL="$2"; shift 2 ;;
        --config) CONFIG="$2"; shift 2 ;;
        --days) DAYS="$2"; shift 2 ;;
        --hour) HOUR="$2"; shift 2 ;;
        --minute) MINUTE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$LABEL" || -z "$CONFIG" ]]; then
    echo "Both --label and --config are required." >&2
    usage
    exit 1
fi
if [[ ! -f "$CONFIG" ]]; then
    echo "Config file not found: $CONFIG" >&2
    exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WARMUP_SCRIPT="$REPO_DIR/bin/warmup.sh"
chmod 700 "$WARMUP_SCRIPT"
chmod 600 "$CONFIG" || true

PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="$HOME/Library/Logs"
mkdir -p "$LOG_DIR"

# Build the StartCalendarInterval array, one entry per weekday.
INTERVALS=""
IFS=',' read -ra DAY_ARR <<< "$DAYS"
for d in "${DAY_ARR[@]}"; do
    INTERVALS+="        <dict><key>Weekday</key><integer>${d}</integer><key>Hour</key><integer>${HOUR}</integer><key>Minute</key><integer>${MINUTE}</integer></dict>\n"
done

{
    printf '<?xml version="1.0" encoding="UTF-8"?>\n'
    printf '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
    printf '<plist version="1.0">\n<dict>\n'
    printf '    <key>Label</key>\n    <string>%s</string>\n\n' "$LABEL"
    printf '    <key>ProgramArguments</key>\n    <array>\n'
    printf '        <string>/usr/bin/env</string>\n'
    printf '        <string>zsh</string>\n'
    printf '        <string>%s</string>\n' "$WARMUP_SCRIPT"
    printf '        <string>%s</string>\n' "$CONFIG"
    printf '    </array>\n\n'
    printf '    <key>StartCalendarInterval</key>\n    <array>\n'
    printf '%b' "$INTERVALS"
    printf '    </array>\n\n'
    printf '    <key>StandardOutPath</key>\n    <string>%s/%s.stdout.log</string>\n' "$LOG_DIR" "$LABEL"
    printf '    <key>StandardErrorPath</key>\n    <string>%s/%s.stderr.log</string>\n\n' "$LOG_DIR" "$LABEL"
    printf '    <key>RunAtLoad</key>\n    <false/>\n'
    printf '</dict>\n</plist>\n'
} > "$PLIST_PATH"
chmod 644 "$PLIST_PATH"

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "Installed and loaded: $PLIST_PATH"
echo "Runs: weekdays [$DAYS] at ${HOUR}:$(printf '%02d' "$MINUTE"), config: $CONFIG"
