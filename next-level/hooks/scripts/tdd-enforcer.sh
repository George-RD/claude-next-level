#!/usr/bin/env bash
# TDD Enforcer — PostToolUse hook for Edit|Write
# Reminds about missing test files AND checks if tests have been run in session.
# Exit 2 = non-blocking reminder.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

INPUT=$(read_hook_input)
TOOL_NAME=$(json_field "$INPUT" "tool_name")
FILE_PATH=$(json_field "$INPUT" "tool_input.file_path")
SESSION_ID=$(json_field "$INPUT" "session_id")
SESSION_ID="${SESSION_ID:-unknown}"

# Only check Edit and Write tools
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

[[ -z "$FILE_PATH" ]] && exit 0

if ! is_impl_file "$FILE_PATH"; then
  exit 0
fi

# Check 1: Does a test file exist? (only for languages with known test patterns)
EXT="${FILE_PATH##*.}"
case "$EXT" in
  py|ts|tsx|js|jsx|go)
    if ! find_test_file "$FILE_PATH" > /dev/null 2>&1; then
      BASENAME=$(basename "$FILE_PATH")
      cat <<EOF
{"result":"No test file found for ${BASENAME}. TDD: write a failing test before implementing."}
EOF
      exit 2
    fi
    ;;
esac

# Check 2: Have tests been run recently in this session?
# Look for test runner output patterns in the transcript
STATE_DIR="${NEXT_LEVEL_STATE}/sessions/${SESSION_ID}"
mkdir -p "$STATE_DIR"

# Track how many impl file edits since last test run
EDIT_COUNT_FILE="$STATE_DIR/edits_since_test"
edit_count=0
if [[ -f "$EDIT_COUNT_FILE" ]]; then
  raw=$(cat "$EDIT_COUNT_FILE")
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    edit_count=$raw
  fi
fi
edit_count=$((edit_count + 1))

# Check transcript for NEW test evidence (track last-read offset)
TRANSCRIPT=$(json_field "$INPUT" "transcript_path" 2>/dev/null || echo "")
OFFSET_FILE="$STATE_DIR/transcript_offset"
if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
  offset=0
  if [[ -f "$OFFSET_FILE" ]]; then
    raw_offset=$(cat "$OFFSET_FILE")
    if [[ "$raw_offset" =~ ^[0-9]+$ ]]; then
      offset=$raw_offset
    fi
  fi
  new_size=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo "$offset")
  if has_test_evidence "$TRANSCRIPT" "$offset"; then
    echo "0" > "$EDIT_COUNT_FILE"
    echo "$new_size" > "$OFFSET_FILE"
    exit 0
  fi
  echo "$new_size" > "$OFFSET_FILE"
fi

# Save updated edit count
echo "$edit_count" > "$EDIT_COUNT_FILE"

# Only nag after 5+ impl edits without running tests
if [[ "$edit_count" -ge 5 ]]; then
  cat <<EOF
{"result":"${edit_count} implementation edits without running tests. TDD: run your tests to verify changes."}
EOF
  exit 2
fi

exit 0
