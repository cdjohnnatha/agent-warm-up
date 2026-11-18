#!/usr/bin/env bash
# Example config: warms up the OpenAI Codex CLI (`codex exec`).
# Adjust the binary path/flags to whatever your installed version expects.

LOG_FILE="$HOME/.local/state/agent-warmup/codex.log"
JITTER_MAX_SECONDS=600
TIMEOUT_SECONDS=120
# TIMEOUT_BIN is auto-detected (see claude.example.sh).

MESSAGES=(
    "Give me one short, interesting software engineering tip, 2 sentences max."
    "Any notable dev tooling news today? One short line only."
)

run_agent() {
    local msg="$1"
    "$HOME/.local/bin/codex" exec "$msg"
}
