#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 ]]; then
    echo "Usage: uninstall-macos-launchagent.sh <label>" >&2
    exit 1
fi
LABEL="$1"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
launchctl unload "$PLIST_PATH" 2>/dev/null || true
rm -f "$PLIST_PATH"
echo "Removed $PLIST_PATH"
