#!/usr/bin/env zsh
# Example config: warms up the OpenAI Codex CLI (`codex exec`).
# Adjust the binary path/flags to whatever your installed version expects.

LOG_FILE="$HOME/Library/Logs/agent-warmup-codex.log"
JITTER_MAX_SECONDS=600
TIMEOUT_SECONDS=120
TIMEOUT_BIN="/opt/homebrew/bin/timeout"

MESSAGES=(
    "Give me one short, interesting software engineering tip, 2 sentences max."
    "Any notable dev tooling news today? One short line only."
)

run_agent() {
    local msg="$1"
    "$HOME/.local/bin/codex" exec "$msg"
}
