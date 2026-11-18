#!/usr/bin/env bats

setup() {
    TEST_DIR="$(mktemp -d)"
    CONFIG="$TEST_DIR/config.sh"
    LOG_FILE="$TEST_DIR/warmup.log"
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    WARMUP="$REPO_ROOT/bin/warmup.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Writes a config with LOG_FILE/JITTER/TIMEOUT pre-filled, MESSAGES=("hello"),
# plus whatever extra lines are passed in.
write_config() {
    {
        echo "LOG_FILE=\"$LOG_FILE\""
        echo "JITTER_MAX_SECONDS=0"
        echo "TIMEOUT_SECONDS=5"
        echo 'MESSAGES=("hello")'
        echo "$1"
    } > "$CONFIG"
}

@test "fails with usage when no config given" {
    run "$WARMUP"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "fails when config file does not exist" {
    run "$WARMUP" "$TEST_DIR/does-not-exist.sh"
    [ "$status" -eq 1 ]
}

@test "fails and logs when config does not define run_agent" {
    write_config ""
    run "$WARMUP" "$CONFIG"
    [ "$status" -eq 1 ]
    grep -q "does not define a run_agent" "$LOG_FILE"
}

@test "fails when config does not set LOG_FILE" {
    cat > "$CONFIG" <<'EOF'
MESSAGES=("hello")
run_agent() { echo "ok"; }
EOF
    run "$WARMUP" "$CONFIG"
    [ "$status" -ne 0 ]
}

@test "fails when config does not set MESSAGES" {
    cat > "$CONFIG" <<EOF
LOG_FILE="$LOG_FILE"
run_agent() { echo "ok"; }
EOF
    run "$WARMUP" "$CONFIG"
    [ "$status" -ne 0 ]
}

@test "runs run_agent and logs the message and response" {
    write_config 'run_agent() { echo "echoed: $1"; }'
    run "$WARMUP" "$CONFIG"
    [ "$status" -eq 0 ]
    grep -q "message: hello" "$LOG_FILE"
    grep -q "response: echoed: hello" "$LOG_FILE"
    grep -q "done$" "$LOG_FILE"
}

@test "logs failure when run_agent exits non-zero" {
    write_config 'run_agent() { echo "boom" >&2; return 1; }'
    run "$WARMUP" "$CONFIG"
    [ "$status" -eq 1 ]
    grep -q "run_agent failed or timed out" "$LOG_FILE"
}

@test "invokes the optional on_failure hook when run_agent fails" {
    write_config $'run_agent() { return 1; }\non_failure() { echo "hook ran"; }'
    run "$WARMUP" "$CONFIG"
    [ "$status" -eq 1 ]
    grep -q "invoking on_failure hook" "$LOG_FILE"
    grep -q "hook ran" "$LOG_FILE"
}

@test "does not crash if the on_failure hook itself fails" {
    write_config $'run_agent() { return 1; }\non_failure() { echo "boom" >&2; return 1; }'
    run "$WARMUP" "$CONFIG"
    [ "$status" -eq 1 ]
    grep -q "on_failure hook itself failed" "$LOG_FILE"
}

@test "does not invoke on_failure when run_agent succeeds" {
    write_config $'run_agent() { echo ok; }\non_failure() { echo "should not run"; }'
    run "$WARMUP" "$CONFIG"
    [ "$status" -eq 0 ]
    ! grep -q "should not run" "$LOG_FILE"
}

@test "times out a hanging run_agent" {
    write_config $'TIMEOUT_SECONDS=1\nrun_agent() { sleep 5; echo "too late"; }'
    run timeout 10 "$WARMUP" "$CONFIG"
    [ "$status" -eq 1 ]
    grep -q "run_agent failed or timed out" "$LOG_FILE"
}

@test "picks one of several messages" {
    cat > "$CONFIG" <<EOF
LOG_FILE="$LOG_FILE"
JITTER_MAX_SECONDS=0
TIMEOUT_SECONDS=5
MESSAGES=("one" "two" "three")
run_agent() { echo "got: \$1"; }
EOF
    run "$WARMUP" "$CONFIG"
    [ "$status" -eq 0 ]
    grep -Eq "message: (one|two|three)" "$LOG_FILE"
}

@test "does not divide by zero when JITTER_MAX_SECONDS=0" {
    write_config 'run_agent() { echo "ok"; }'
    run timeout 10 "$WARMUP" "$CONFIG"
    [ "$status" -eq 0 ]
}

@test "creates the LOG_FILE directory if missing" {
    LOG_FILE="$TEST_DIR/nested/dir/warmup.log"
    write_config 'run_agent() { echo "ok"; }'
    run "$WARMUP" "$CONFIG"
    [ "$status" -eq 0 ]
    [ -f "$LOG_FILE" ]
}

@test "trims LOG_FILE to MAX_LOG_LINES before appending" {
    for i in $(seq 1 20); do echo "old line $i"; done > "$LOG_FILE"
    cat > "$CONFIG" <<EOF
LOG_FILE="$LOG_FILE"
JITTER_MAX_SECONDS=0
TIMEOUT_SECONDS=5
MAX_LOG_LINES=5
MESSAGES=("hello")
run_agent() { echo "ok"; }
EOF
    run "$WARMUP" "$CONFIG"
    [ "$status" -eq 0 ]
    # 5 kept old lines + 4 new log lines from this run = 9
    [ "$(wc -l < "$LOG_FILE" | tr -d ' ')" -eq 9 ]
    grep -q "old line 20" "$LOG_FILE"
    ! grep -q "old line 15$" "$LOG_FILE"
}
