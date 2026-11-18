#!/usr/bin/env bats
# Exercises install/install-macos-launchagent.sh via --dry-run, which never
# touches ~/Library/LaunchAgents or calls launchctl, so this runs safely on
# any OS (including Linux CI) even though the installed agent is macOS-only.

setup() {
    TEST_DIR="$(mktemp -d)"
    CONFIG="$TEST_DIR/config.sh"
    echo 'MESSAGES=("hi")' > "$CONFIG"
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    INSTALLER="$REPO_ROOT/install/install-macos-launchagent.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "requires --label and --config" {
    run "$INSTALLER" --dry-run
    [ "$status" -ne 0 ]
}

@test "fails when config file does not exist" {
    run "$INSTALLER" --label com.test.warmup --config "$TEST_DIR/missing.sh" --dry-run
    [ "$status" -ne 0 ]
}

@test "dry-run prints a plist without touching the filesystem or launchctl" {
    run "$INSTALLER" --label com.test.warmup --config "$CONFIG" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"<key>Label</key>"* ]]
    [[ "$output" == *"com.test.warmup"* ]]
    [[ "$output" == *"$CONFIG"* ]]
    [ ! -f "$HOME/Library/LaunchAgents/com.test.warmup.plist" ]
}

@test "dry-run reflects a custom schedule" {
    run "$INSTALLER" --label com.test.warmup2 --config "$CONFIG" --dry-run \
        --days 1,3 --hour 9 --minute 5
    [ "$status" -eq 0 ]
    [[ "$output" == *"<integer>1</integer>"* ]]
    [[ "$output" == *"<integer>3</integer>"* ]]
    [[ "$output" == *"<integer>9</integer>"* ]]
    [[ "$output" == *"<integer>5</integer>"* ]]
}
