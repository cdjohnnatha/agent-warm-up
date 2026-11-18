#!/usr/bin/env bash
# Generic warm-up engine. Runs on Linux and macOS with plain bash (no
# bash-4-only features), no zsh dependency.
#
# Sends a short prompt to whatever AI agent CLI you configure, so a
# usage/session window (e.g. a 5-hour rolling window) starts earlier in the
# day, or just to keep a local model/agent warm.
#
# This script knows nothing about any specific agent. All agent-specific
# logic (which binary to call, with which flags) lives in a config file that
# defines a `run_agent()` shell function. See config/*.example.sh.
#
# Authentication is entirely the agent CLI's own business: this script never
# stores, reads, or passes any credential itself. run_agent() is expected to
# reuse whatever session/token the CLI already has on disk (e.g. the Claude
# Code CLI's own OS keychain entry) the same way it would if you ran it by
# hand. If a config also defines an `on_failure()` function, it's called
# (best-effort, non-fatal) after a failed run_agent — e.g. to detect an
# expired session and kick off re-authentication. See
# config/claude.example.sh and the README's "Authentication" section.
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

set -euo pipefail
umask 077

export PATH="/usr/local/bin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

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
: "${MAX_LOG_LINES:=1000}"

if [[ -z "${TIMEOUT_BIN:-}" ]]; then
    TIMEOUT_BIN="$(command -v timeout || command -v gtimeout || true)"
fi
if [[ -z "$TIMEOUT_BIN" ]]; then
    echo "No 'timeout' binary found (Linux: coreutils, preinstalled; macOS: brew install coreutils -> gtimeout)." >&2
    exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; }

# Keep the log bounded: trim it to the last MAX_LOG_LINES before each run so
# it doesn't grow forever across months of scheduled runs.
if [[ -f "$LOG_FILE" ]]; then
    LINE_COUNT="$(wc -l < "$LOG_FILE" | tr -d ' ')"
    if [[ "$LINE_COUNT" -gt "$MAX_LOG_LINES" ]]; then
        tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
fi

if ! declare -f run_agent > /dev/null; then
    log "ERROR: config '$CONFIG' does not define a run_agent() function"
    exit 1
fi

log "starting, jittering up to ${JITTER_MAX_SECONDS}s..."
if [[ "$JITTER_MAX_SECONDS" -gt 0 ]]; then
    sleep $((RANDOM % JITTER_MAX_SECONDS))
fi

MSG="${MESSAGES[$((RANDOM % ${#MESSAGES[@]}))]}"
log "message: $MSG"

# Re-source the config in a fresh subshell so run_agent() is available to
# the external `timeout` binary, with CONFIG/MSG passed positionally
# (never string-interpolated) to avoid any injection risk. The inner
# single-quoted script is intentional: $1/$2 must expand in the *inner*
# bash -c, not in this outer shell.
# shellcheck disable=SC2016
if RESPONSE="$("$TIMEOUT_BIN" "$TIMEOUT_SECONDS" bash -c 'source "$1"; run_agent "$2"' _ "$CONFIG" "$MSG" 2>>"$LOG_FILE")"; then
    log "response: $RESPONSE"
    log "done"
else
    log "run_agent failed or timed out"
    if declare -f on_failure > /dev/null; then
        log "invoking on_failure hook"
        # shellcheck disable=SC2016
        if ! "$TIMEOUT_BIN" 10 bash -c 'source "$1"; on_failure' _ "$CONFIG" >>"$LOG_FILE" 2>&1; then
            log "on_failure hook itself failed or timed out (non-fatal)"
        fi
    fi
    exit 1
fi
