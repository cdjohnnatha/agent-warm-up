#!/usr/bin/env bats
# Exercises install/install-linux-systemd-timer.sh via --dry-run, which
# never touches ~/.config/systemd/user or calls systemctl, so this runs on
# any OS, including macOS CI, even though the installed timer is Linux-only.

setup() {
    TEST_DIR="$(mktemp -d)"
    CONFIG="$TEST_DIR/config.sh"
    echo 'MESSAGES=("hi")' > "$CONFIG"
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    INSTALLER="$REPO_ROOT/install/install-linux-systemd-timer.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "requires --name and --config" {
    run "$INSTALLER" --dry-run
    [ "$status" -ne 0 ]
}

@test "fails when config file does not exist" {
    run "$INSTALLER" --name claude-warmup --config "$TEST_DIR/missing.sh" --dry-run
    [ "$status" -ne 0 ]
}

@test "dry-run prints service and timer units without touching the filesystem" {
    run "$INSTALLER" --name claude-warmup --config "$CONFIG" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[Service]"* ]]
    [[ "$output" == *"[Timer]"* ]]
    [[ "$output" == *"$CONFIG"* ]]
    [[ "$output" == *"OnCalendar=Mon..Fri 07:25"* ]]
    [ ! -f "$HOME/.config/systemd/user/claude-warmup.timer" ]
}

@test "dry-run reflects a custom OnCalendar expression" {
    run "$INSTALLER" --name claude-warmup --config "$CONFIG" --dry-run --on-calendar "Tue 10:00"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OnCalendar=Tue 10:00"* ]]
}
