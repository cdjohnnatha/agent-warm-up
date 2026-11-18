# agent-warm-up

Keep an AI agent CLI "warm" by firing a short, harmless prompt at it on a
schedule — e.g. so a usage/session window (like Claude's rolling 5-hour
window) starts earlier in the day, or just to pre-warm a local model.

Agent-agnostic by design: the engine (`bin/warmup.sh`) only knows how to
jitter, pick a message, log, and enforce a timeout. How to actually call your
agent lives in a small config file you write, which defines one shell
function: `run_agent()`.

## How it works

```
bin/warmup.sh <config-file>
```

1. Sleeps a random amount (`JITTER_MAX_SECONDS`) so the exact fire time isn't
   perfectly predictable.
2. Picks a random message from `MESSAGES` (defined in your config).
3. Calls your config's `run_agent "$MSG"` under a hard timeout
   (`TIMEOUT_SECONDS`).
4. Logs everything to `LOG_FILE`.

## Quick start

1. Copy an example config and adjust the paths for your machine:

   ```bash
   cp config/claude.example.sh config/claude.sh
   $EDITOR config/claude.sh
   ```

   (`config/*.sh`, other than the `*.example.sh` files, is gitignored — keep
   your real configs out of version control, especially any that embed API
   keys.)

2. Try it once by hand:

   ```bash
   zsh bin/warmup.sh config/claude.sh
   tail -f ~/Library/Logs/agent-warmup-claude.log
   ```

3. Schedule it (macOS, via a LaunchAgent):

   ```bash
   ./install/install-macos-launchagent.sh \
       --label com.me.claude-warmup \
       --config "$(pwd)/config/claude.sh" \
       --days 1,2,3,4,5 --hour 7 --minute 25
   ```

   Weekdays only, 07:25, by default. `RunAtLoad` is intentionally left off:
   it only fires at the scheduled time, not on every login/boot. Uninstall
   with `./install/uninstall-macos-launchagent.sh com.me.claude-warmup`.

   On Linux, use cron or a systemd timer instead — just point either at
   `bin/warmup.sh <config-file>`.

## Writing a config for a different agent

A config is just a shell file sourced by `bin/warmup.sh`. It must set:

- `LOG_FILE` — where to log
- `MESSAGES` — an array of candidate prompts
- `run_agent()` — a function taking the message as `$1`, printing the
  agent's response to stdout, and returning non-zero on failure

Optional: `JITTER_MAX_SECONDS` (default 600), `TIMEOUT_SECONDS` (default
120), `TIMEOUT_BIN` (default: auto-detected `timeout`/`gtimeout`).

See `config/claude.example.sh` (Claude Code CLI), `config/codex.example.sh`
(OpenAI Codex CLI), and `config/http-api.example.sh` (raw HTTP API via
`curl`, for agents with no CLI) for the pattern.

## Security notes

- Use absolute paths to binaries inside `run_agent()` rather than relying on
  `$PATH`.
- Never hardcode API keys/secrets in a config file; read them from an
  environment variable instead (see `config/http-api.example.sh`).
- `bin/warmup.sh` passes the config path and the chosen message to the
  agent-calling subshell as positional arguments, never by interpolating
  them into a command string, so prompt content can't be used to inject
  shell commands.
- Keep `bin/warmup.sh` at `700` and any real config file at `600`
  (the install script does this for you).
