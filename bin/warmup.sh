#!/usr/bin/env zsh
# Generic warm-up engine.
#
# Sends a short prompt to whatever AI agent CLI you configure, so a
# usage/session window (e.g. a 5-hour rolling window) starts earlier in the
# day, or just to keep a local model/agent warm.
#
# This script knows nothing about any specific agent. All agent-specific
# logic (which binary to call, with which flags) lives in a config file that
# defines a `run_agent()` shell function. See config/*.example.sh.
#
# Usage:
#   warmup.sh /path/to/config.sh
#
# Security notes:
# - Fixed PATH for this process; a tampered $PATH can't substitute a
#   malicious binary for anything this script calls directly.
# - The chosen message and the config path are passed to the agent-calling
#   subshell as positional arguments ("$1"/"$2"), never interpolated into a
#   command string, so message content can never be used to inject commands.
# - A hard timeout wraps the call to run_agent so a hung CLI/network call
#   can't leave a runaway background process.
# - Keep this script and your config file(s) at 700/600 permissions,
#   owner-only, especially if a config embeds credentials.

set -eu
umask 077

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

CONFIG="${1:-}"
if [[ -z "$CONFIG" || ! -f "$CONFIG" ]]; then
    echo "Usage: $0 <config-file>" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG"

: "${LOG_FILE:?config must set LOG_FILE}"
: "${MESSAGES:?config must set a MESSAGES array}"
: "${JITTER_MAX_SECONDS:=600}"
: "${TIMEOUT_SECONDS:=120}"

if [[ -z "${TIMEOUT_BIN:-}" ]]; then
    TIMEOUT_BIN="$(command -v timeout || command -v gtimeout || true)"
fi
if [[ -z "$TIMEOUT_BIN" ]]; then
    echo "No 'timeout' binary found (Linux: coreutils; macOS: brew install coreutils -> gtimeout)." >&2
    exit 1
fi

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; }

if ! typeset -f run_agent >/dev/null; then
    log "ERROR: config '$CONFIG' does not define a run_agent() function"
    exit 1
fi

log "starting, jittering up to ${JITTER_MAX_SECONDS}s..."
sleep $((RANDOM % JITTER_MAX_SECONDS))

MSG="${MESSAGES[$((RANDOM % ${#MESSAGES[@]} + 1))]}"
log "message: $MSG"

# Re-source the config in a fresh subshell so run_agent() is available to
# the external `timeout` binary, with CONFIG/MSG passed positionally
# (never string-interpolated) to avoid any injection risk.
if RESPONSE="$("$TIMEOUT_BIN" "$TIMEOUT_SECONDS" zsh -c 'source "$1"; run_agent "$2"' _ "$CONFIG" "$MSG" 2>>"$LOG_FILE")"; then
    log "response: $RESPONSE"
    log "done"
else
    log "run_agent failed or timed out"
    exit 1
fi
