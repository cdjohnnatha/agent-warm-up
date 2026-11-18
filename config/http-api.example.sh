#!/usr/bin/env bash
# Example config: warms up any HTTP chat-completion style API directly with
# curl, for agents/providers that don't ship a CLI. Reads the API key from
# an environment variable (never hardcode secrets in this file).
#
# Usage: export MY_AGENT_API_KEY=... before this config is sourced, or set
# it in your shell profile / launchd plist EnvironmentVariables.

LOG_FILE="$HOME/.local/state/agent-warmup/http.log"
JITTER_MAX_SECONDS=600
TIMEOUT_SECONDS=120
# TIMEOUT_BIN is auto-detected (see claude.example.sh).

API_URL="https://api.example.com/v1/chat/completions"
MODEL="example-model"

MESSAGES=(
    "Give me one short, interesting tech fact, 1-2 sentences max."
)

run_agent() {
    local msg="$1"
    : "${MY_AGENT_API_KEY:?set MY_AGENT_API_KEY in your environment}"
    curl -sS "$API_URL" \
        -H "Authorization: Bearer $MY_AGENT_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$(printf '{"model":"%s","messages":[{"role":"user","content":%s}]}' \
            "$MODEL" "$(printf '%s' "$msg" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')")"
}
