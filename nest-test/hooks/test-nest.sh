#!/usr/bin/env bash
# Test: Can we run `claude -p` from inside an active Claude Code session?
#
# This script is meant to be run MANUALLY first (not as a hook) to validate
# assumptions before wiring it into the hook system.
#
# Tests:
#   1. Can claude -p run at all from within this environment?
#   2. Is stdout clean / parseable?
#   3. How long does it take?
#   4. Can it access gh CLI?
#   5. Can it read files in the current directory?

set -euo pipefail

RESULTS_FILE="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/test-results.json"
TESTS_PASSED=0
TESTS_FAILED=0

log_result() {
  local name="$1" passed="$2" output="$3" duration="$4"
  echo "  $([ "$passed" = "true" ] && echo "PASS" || echo "FAIL") | ${name} (${duration}s)"
  if [ "$passed" = "true" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

echo "=== Claude Code Nesting Test ==="
echo "  Time: $(date -Iseconds)"
echo "  CWD:  $(pwd)"
echo ""

# Test 1: Basic claude -p invocation
echo "--- Test 1: Basic claude -p ---"
START=$(date +%s)
if OUTPUT=$(claude -p "Respond with exactly: NEST_TEST_OK" --output-format text 2>/dev/null); then
  END=$(date +%s)
  DURATION=$((END - START))
  if echo "$OUTPUT" | grep -q "NEST_TEST_OK"; then
    log_result "basic-invoke" "true" "$OUTPUT" "$DURATION"
  else
    log_result "basic-invoke" "false" "Got unexpected output: $OUTPUT" "$DURATION"
  fi
else
  END=$(date +%s)
  DURATION=$((END - START))
  log_result "basic-invoke" "false" "claude -p failed to run" "$DURATION"
fi

# Test 2: JSON output format
echo "--- Test 2: JSON output ---"
START=$(date +%s)
if OUTPUT=$(claude -p "Respond with exactly: JSON_TEST_OK" --output-format json 2>/dev/null); then
  END=$(date +%s)
  DURATION=$((END - START))
  # Check if it's valid JSON
  if echo "$OUTPUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    log_result "json-output" "true" "Valid JSON" "$DURATION"
  else
    log_result "json-output" "false" "Invalid JSON: $OUTPUT" "$DURATION"
  fi
else
  END=$(date +%s)
  DURATION=$((END - START))
  log_result "json-output" "false" "claude -p --output-format json failed" "$DURATION"
fi

# Test 3: Can it access gh CLI?
echo "--- Test 3: gh CLI access ---"
START=$(date +%s)
if gh auth status >/dev/null 2>&1; then
  log_result "gh-auth" "true" "gh is authenticated" "0"
else
  log_result "gh-auth" "false" "gh not authenticated" "0"
fi

# Test 4: Can claude -p use tools (read a file)?
echo "--- Test 4: Tool use in headless mode ---"
# Create a temp test file
TESTFILE=$(mktemp)
echo "CANARY_VALUE_12345" > "$TESTFILE"
START=$(date +%s)
if OUTPUT=$(claude -p "Read the file at $TESTFILE and tell me what value is in it. Respond with just the value." --output-format text 2>/dev/null); then
  END=$(date +%s)
  DURATION=$((END - START))
  if echo "$OUTPUT" | grep -q "CANARY_VALUE_12345"; then
    log_result "tool-use" "true" "Successfully read file" "$DURATION"
  else
    log_result "tool-use" "false" "Could not find canary value in: $OUTPUT" "$DURATION"
  fi
else
  END=$(date +%s)
  DURATION=$((END - START))
  log_result "tool-use" "false" "claude -p with file read failed" "$DURATION"
fi
rm -f "$TESTFILE"

# Summary
echo ""
echo "=== Results: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed ==="
echo ""

# Write results as JSON for programmatic consumption
cat > "$RESULTS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "tests_passed": $TESTS_PASSED,
  "tests_failed": $TESTS_FAILED,
  "total": $((TESTS_PASSED + TESTS_FAILED)),
  "all_passed": $([ "$TESTS_FAILED" -eq 0 ] && echo "true" || echo "false")
}
EOF

echo "Results written to: $RESULTS_FILE"
