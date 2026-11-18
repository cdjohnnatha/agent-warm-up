#!/usr/bin/env zsh
# Example config: warms up the Claude Code CLI (`claude -p`).
#
# Copy this file somewhere outside the repo (or keep it here but gitignored,
# see .gitignore) and adjust the absolute paths for your machine.

LOG_FILE="$HOME/Library/Logs/agent-warmup-claude.log"
JITTER_MAX_SECONDS=600
TIMEOUT_SECONDS=120
TIMEOUT_BIN="/opt/homebrew/bin/timeout"   # macOS: brew install coreutils

MESSAGES=(
    "Give me 2-3 short bullet points of today's top tech news. Keep it very brief."
    "Share one interesting IT/computer science curiosity or fun fact, in 2 sentences max."
    "Any notable JavaScript/web dev news today? One or two short lines only."
    "Any notable AI news today? One or two short lines only."
    "Give me one short, interesting software engineering tip or best practice, 2 sentences max."
    "What's one cool thing happening in tech right now? Answer in 1-2 sentences."
)

# Called by bin/warmup.sh with the chosen message as $1. Must print the
# agent's response to stdout and exit non-zero on failure.
run_agent() {
    local msg="$1"
    "$HOME/.local/bin/claude" -p "$msg"
}
