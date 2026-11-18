# agent-warm-up

Keep an AI agent CLI "warm" by firing a short, harmless prompt at it on a
schedule, so a usage/session window (like Claude's rolling 5-hour window)
starts earlier in the day instead of whenever your first real prompt happens.

## Why this exists

Some AI agent plans (Claude Code included) meter usage in rolling windows
rather than a fixed daily reset — e.g. a 5-hour window that starts the moment
you send your first message. If your actual workday starts around 9 AM but
the first prompt of the day happens a bit later, that window starts late too,
and its reset then lands in the middle of the afternoon (for me, sometimes
not until ~14:30) — right when I need the agent most, forcing a long,
avoidable wait for a fresh window.

The fix is simple in principle: send one throwaway message early, before the
real workday starts, so the window's clock starts on your schedule instead
of whenever you happen to get to your first real prompt. Doing that by hand
every morning doesn't scale, and installing a chat app on a phone just to
fire off a message at a fixed time felt like the wrong tool for the job. So
this exists instead: a small, scheduled, unattended script that sends one
short, harmless prompt at a jittered time each weekday morning — no phone,
no manual step, no babysitting.

It started as a one-off `claude -p` cron-ish job for exactly that use case,
then got generalized here so it isn't tied to one CLI or to warming up usage
windows specifically. The engine (`bin/warmup.sh`) only knows how to jitter,
pick a message, log, and enforce a timeout — any agent that can be invoked
from the command line (or a plain HTTP API) can be plugged in via a small
config file that defines one shell function, `run_agent()` (see "Writing a
config for a different agent" below).

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
   bin/warmup.sh config/claude.sh
   tail -f ~/.local/state/agent-warmup/claude.log
   ```

3. Schedule it.

   **macOS** (LaunchAgent):

   ```bash
   ./install/install-macos-launchagent.sh \
       --label com.me.claude-warmup \
       --config "$(pwd)/config/claude.sh" \
       --days 1,2,3,4,5 --hour 7 --minute 25
   ```

   Weekdays only, 07:25, by default. `RunAtLoad` is intentionally left off:
   it only fires at the scheduled time, not on every login/boot. Uninstall
   with `./install/uninstall-macos-launchagent.sh com.me.claude-warmup`.

   **Linux** (systemd `--user` timer):

   ```bash
   ./install/install-linux-systemd-timer.sh \
       --name claude-warmup \
       --config "$(pwd)/config/claude.sh" \
       --on-calendar "Mon..Fri 07:25"
   loginctl enable-linger "$USER"   # so it still fires while you're logged out
   ```

   Uninstall with `./install/uninstall-linux-systemd-timer.sh claude-warmup`.
   Both installers take `--dry-run` to print the generated unit/plist
   without touching your filesystem or calling `launchctl`/`systemctl`.

   Plain `cron` works too, if you don't want systemd: just point a crontab
   entry at `bin/warmup.sh <config-file>` — the jitter inside the script
   already randomizes the effective fire time, so cron's own fixed minute is
   fine.

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
  (the install scripts do this for you).

## Linux vs macOS

The engine (`bin/warmup.sh`) and the example configs are plain POSIX-ish
`bash` — no zsh, no bash-4-only features — and auto-detect `timeout` (Linux,
preinstalled) vs `gtimeout` (macOS, via `brew install coreutils`). Nothing
needs to change to run it on Linux.

The only OS-specific pieces are the schedulers: `install-macos-launchagent.sh`
(LaunchAgent) vs `install-linux-systemd-timer.sh` (systemd `--user` timer).
Use whichever matches your OS, or skip both and use plain `cron`.

## Tests

Requires [bats-core](https://github.com/bats-core/bats-core)
(`brew install bats-core` on macOS, `apt install bats` on Debian/Ubuntu) and,
for the timeout-related tests, a `timeout`/`gtimeout` binary (see above).

```bash
bats tests/
```

`shellcheck` is also run in CI (`.github/workflows/ci.yml`), which tests
against both `ubuntu-latest` and `macos-latest`.
