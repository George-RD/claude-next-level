#!/usr/bin/env bash
# Tests for TDD Enforcer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

run_test() {
  local name="$1" expected_exit="$2" expected_pattern="$3"
  local input="$4"
  local actual_exit=0
  local output

  output=$(echo "$input" | bash "$SCRIPT_DIR/tdd-enforcer.sh" 2>&1) || actual_exit=$?

  if [[ "$actual_exit" -ne "$expected_exit" ]]; then
    echo "FAIL: $name — expected exit $expected_exit, got $actual_exit"
    echo "  output: $output"
    FAIL=$((FAIL + 1))
    return
  fi

  if [[ -n "$expected_pattern" ]] && ! echo "$output" | grep -q "$expected_pattern"; then
    echo "FAIL: $name — output missing pattern '$expected_pattern'"
    echo "  output: $output"
    FAIL=$((FAIL + 1))
    return
  fi

  echo "PASS: $name"
  PASS=$((PASS + 1))
}

# Setup: create a temp directory with an impl file but no test
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/src"
touch "$TMPDIR/src/handler.ts"

# Also create an impl file WITH a matching test
mkdir -p "$TMPDIR/tested"
touch "$TMPDIR/tested/utils.ts"
touch "$TMPDIR/tested/utils.test.ts"

# Test 1: Impl file without test → exit 2
run_test "impl file without test" 2 "No test file found" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$TMPDIR/src/handler.ts\"}}"

# Test 2: Test file edit → exit 0 (test files are not impl files)
run_test "test file edit" 0 "" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$TMPDIR/src/handler.test.ts\"}}"

# Test 3: Markdown file → exit 0 (not an impl file)
run_test "markdown file" 0 "" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TMPDIR/README.md\"}}"

# Test 4: Non-Edit tool → exit 0
run_test "non-Edit tool" 0 "" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"file_path\":\"$TMPDIR/src/handler.ts\"}}"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
