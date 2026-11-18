#!/usr/bin/env bash
# shellcheck disable=SC2034  # these vars are read by bin/warmup.sh after sourcing this file
# Example config: warms up the Claude Code CLI (`claude -p`).
#
# Copy this file somewhere outside the repo (or keep it here but gitignored,
# see .gitignore) and adjust the absolute paths for your machine.

LOG_FILE="$HOME/.local/state/agent-warmup/claude.log"
JITTER_MAX_SECONDS=600
TIMEOUT_SECONDS=120
# TIMEOUT_BIN is auto-detected by bin/warmup.sh (timeout on Linux, gtimeout
# on macOS via `brew install coreutils`). Set it here only to override.

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

# Optional: called by bin/warmup.sh (best-effort, non-fatal) when run_agent
# fails. If the session has simply expired, kick off `claude auth login`,
# which opens the default browser on its own for the OAuth flow. This is
# fire-and-forget: it doesn't block waiting for you to finish logging in
# (nothing here can click "Authorize" for you), it just means the browser
# tab is sitting there ready the next time you're at the machine, instead
# of you having to notice the warm-up stopped working and run `claude`
# yourself to rediscover why.
on_failure() {
    local logged_in
    logged_in="$("$HOME/.local/bin/claude" auth status --json 2>/dev/null \
        | grep -o '"loggedIn"[[:space:]]*:[[:space:]]*[a-z]*' \
        | grep -o '[a-z]*$')"

    if [[ "$logged_in" == "false" ]]; then
        echo "Not logged in to Claude; opening the browser to re-authenticate."
        nohup "$HOME/.local/bin/claude" auth login >/dev/null 2>&1 &
        disown
    else
        echo "run_agent failed for a reason other than being logged out (loggedIn=${logged_in:-unknown})."
    fi
}
