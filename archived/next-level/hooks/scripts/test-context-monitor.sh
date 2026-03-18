#!/usr/bin/env bash
# Tests for Context Monitor
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

run_test() {
  local name="$1" expected_exit="$2" expected_pattern="$3"
  local mock_pct="$4"
  local actual_exit=0
  local output

  # Each test gets its own isolated state dir
  local test_state
  test_state=$(mktemp -d)

  output=$(echo '{"session_id":"test-session-001"}' \
    | MOCK_CONTEXT_PCT="$mock_pct" NEXT_LEVEL_STATE="$test_state" \
      bash "$SCRIPT_DIR/context-monitor.sh" 2>&1) || actual_exit=$?

  if [[ "$actual_exit" -ne "$expected_exit" ]]; then
    echo "FAIL: $name — expected exit $expected_exit, got $actual_exit"
    echo "  output: $output"
    FAIL=$((FAIL + 1))
    rm -rf "$test_state"
    return
  fi

  if [[ -n "$expected_pattern" ]] && ! echo "$output" | grep -q "$expected_pattern"; then
    echo "FAIL: $name — output missing pattern '$expected_pattern'"
    echo "  output: $output"
    FAIL=$((FAIL + 1))
    rm -rf "$test_state"
    return
  fi

  # For the state file test, check it was created
  if [[ "$name" == *"state file"* ]]; then
    local state_file="$test_state/sessions/test-session-001/context_state"
    if [[ ! -f "$state_file" ]]; then
      echo "FAIL: $name — state file not created at $state_file"
      FAIL=$((FAIL + 1))
      rm -rf "$test_state"
      return
    fi
  fi

  echo "PASS: $name"
  PASS=$((PASS + 1))
  rm -rf "$test_state"
}

# Test 1: 50% context → exit 0 silently
run_test "50% context silent" 0 "" "50"

# Test 2: 82% context → warning message mentioning 80%
run_test "82% context warning" 2 "80%" "82"

# Test 3: 92% context → handoff instruction mentioning continuation
run_test "92% context handoff" 2 "continuation" "92"

# Test 4: State file created after monitoring
run_test "state file created after monitoring" 0 "" "50"

# Verify the state file test more thoroughly with a fresh state dir
STATE_DIR=$(mktemp -d)
trap 'rm -rf "$STATE_DIR"' EXIT

echo '{"session_id":"state-test-session"}' \
  | MOCK_CONTEXT_PCT=60 NEXT_LEVEL_STATE="$STATE_DIR" \
    bash "$SCRIPT_DIR/context-monitor.sh" > /dev/null 2>&1 || true

STATE_FILE="$STATE_DIR/sessions/state-test-session/context_state"
if [[ -f "$STATE_FILE" ]]; then
  echo "PASS: state file persisted after monitoring"
  PASS=$((PASS + 1))
else
  echo "FAIL: state file not persisted at $STATE_FILE"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
