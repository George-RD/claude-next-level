#!/usr/bin/env bash
# Tests for Verification Guard
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

run_test() {
  local name="$1" expected_exit="$2" expected_pattern="$3"
  local transcript_file="$4"
  local actual_exit=0
  local output

  output=$(echo "{\"transcript_path\":\"$transcript_file\"}" \
    | bash "$SCRIPT_DIR/verification-guard.sh" 2>&1) || actual_exit=$?

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

# --- Create mock transcripts ---

# Transcript 1: Impl edits without test evidence
cat > "$TMPDIR/transcript-no-tests.txt" <<'TRANSCRIPT'
User: Fix the authentication bug
Assistant: I'll edit the handler file.
Tool call: Edit
"file_path": "/app/src/auth/handler.ts"
old_string: "return false"
new_string: "return validateToken(token)"
Tool result: File edited successfully.
Assistant: Done, the handler now validates tokens properly.
TRANSCRIPT

# Transcript 2: Impl edits WITH test evidence
cat > "$TMPDIR/transcript-with-tests.txt" <<'TRANSCRIPT'
User: Fix the authentication bug and test it
Assistant: I'll edit the handler file.
Tool call: Edit
"file_path": "/app/src/auth/handler.ts"
old_string: "return false"
new_string: "return validateToken(token)"
Tool result: File edited successfully.
Assistant: Now let me run the tests.
Tool call: Bash
command: npm test
Tool result:
  PASS src/auth/handler.test.ts
  Tests: 3 passed, 3 total
Assistant: All tests pass.
TRANSCRIPT

# Transcript 3: Docs-only session (no impl files)
cat > "$TMPDIR/transcript-docs-only.txt" <<'TRANSCRIPT'
User: Update the README
Assistant: I'll update the documentation.
Tool call: Edit
"file_path": "/app/docs/README.md"
old_string: "# Old Title"
new_string: "# New Title"
Tool result: File edited successfully.
Assistant: README updated.
TRANSCRIPT

# --- Run tests ---

# Test 1: Impl edits without tests → exit 2
run_test "impl edits without tests" 2 "run tests" "$TMPDIR/transcript-no-tests.txt"

# Test 2: Impl edits with test evidence → exit 0
run_test "impl edits with test evidence" 0 "" "$TMPDIR/transcript-with-tests.txt"

# Test 3: Docs-only session → exit 0
run_test "docs-only session" 0 "" "$TMPDIR/transcript-docs-only.txt"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
