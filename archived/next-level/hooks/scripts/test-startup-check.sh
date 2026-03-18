#!/usr/bin/env bash
# Tests for startup-check.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

run_test() {
  local name="$1" expected_exit="$2" expected_pattern="$3"
  local setup_fn="$4"
  local actual_exit=0
  local output

  # Create temp config dir
  local tmpdir
  tmpdir=$(mktemp -d)

  # Run setup function to prepare config
  eval "$setup_fn" "$tmpdir"

  # Run the script with overridden config path
  output=$(NEXT_LEVEL_CONFIG="$tmpdir/config.json" bash "$SCRIPT_DIR/startup-check.sh" 2>&1) || actual_exit=$?

  if [[ "$actual_exit" -ne "$expected_exit" ]]; then
    echo "FAIL: $name — expected exit $expected_exit, got $actual_exit"
    echo "  output: $output"
    FAIL=$((FAIL + 1))
    rm -rf "$tmpdir"
    return
  fi

  if [[ -n "$expected_pattern" ]] && ! echo "$output" | grep -q "$expected_pattern"; then
    echo "FAIL: $name — output missing pattern '$expected_pattern'"
    echo "  output: $output"
    FAIL=$((FAIL + 1))
    rm -rf "$tmpdir"
    return
  fi

  echo "PASS: $name"
  PASS=$((PASS + 1))
  rm -rf "$tmpdir"
}

# Setup functions
setup_no_config() {
  local dir="$1"
  # No config file — nothing to create
  :
}

setup_incomplete() {
  local dir="$1"
  cat > "$dir/config.json" <<JSON
{"setup_complete": false, "languages_detected": [], "project_root": "$(pwd)"}
JSON
}

setup_complete() {
  local dir="$1"
  cat > "$dir/config.json" <<JSON
{"setup_complete": true, "languages_detected": [], "project_root": "$(pwd)"}
JSON
}

setup_wrong_project() {
  local dir="$1"
  cat > "$dir/config.json" <<JSON
{"setup_complete": true, "languages_detected": [], "project_root": "/some/other/project"}
JSON
}

# Test 1: No config → exit 2 with setup message
run_test "no config file" 2 "not configured" setup_no_config

# Test 2: Incomplete setup → exit 2
run_test "incomplete setup" 2 "incomplete" setup_incomplete

# Test 3: Complete setup, correct project → exit 0
run_test "complete setup" 0 "" setup_complete

# Test 4: Wrong project root → exit 2
run_test "wrong project root" 2 "different project" setup_wrong_project

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
