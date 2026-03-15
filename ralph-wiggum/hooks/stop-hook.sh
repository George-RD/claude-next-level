#!/bin/bash
# Ralph Wiggum Stop Hook
# Prevents session exit when a loop is active, feeding the prompt back to continue

set -euo pipefail

RALPH_STATE_FILE=".claude/ralph-wiggum.local.md"

if [[ ! -f "$RALPH_STATE_FILE" ]]; then
  exit 0
fi

HOOK_INPUT=$(cat)

# Helper: clean up state file and exit (loop is done or broken)
end_loop() {
  [[ -n "${1:-}" ]] && echo "Ralph Wiggum: $1" >&2
  rm -f "$RALPH_STATE_FILE"
  exit 0
}

# Parse markdown frontmatter (YAML between ---) and extract values
get_field() { echo "$FRONTMATTER" | grep "^$1:" | sed "s/$1: *//" ; }

FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPH_STATE_FILE")
ITERATION=$(get_field iteration)
MAX_ITERATIONS=$(get_field max_iterations)
MODE=$(get_field mode)
COMPLETION_PROMISE=$(get_field completion_promise | sed 's/^"\(.*\)"$/\1/')

# Session isolation: only this session's loop should block
STATE_SESSION=$(get_field session_id || true)
HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
if [[ -n "$STATE_SESSION" ]] && [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  exit 0
fi

# Validate numeric fields
[[ "$ITERATION" =~ ^[0-9]+$ ]]      || end_loop "State file corrupted (invalid iteration: '$ITERATION')"
[[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] || end_loop "State file corrupted (invalid max_iterations: '$MAX_ITERATIONS')"

# Check max iterations
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  end_loop "Max iterations ($MAX_ITERATIONS) reached. Mode: $MODE"
fi

# Extract last assistant output from transcript
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')
[[ -f "$TRANSCRIPT_PATH" ]] || end_loop "Transcript file not found"

LAST_LINES=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -n 100)
[[ -n "$LAST_LINES" ]] || end_loop "No assistant messages in transcript"

set +e
LAST_OUTPUT=$(echo "$LAST_LINES" | jq -rs '
  map(.message.content[]? | select(.type == "text") | .text) | last // ""
' 2>&1)
JQ_EXIT=$?
set -e

[[ $JQ_EXIT -eq 0 ]] || end_loop "Failed to parse transcript JSON"

# Check for completion promise
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  # Extract last <promise> tag and normalize whitespace (trim + collapse internal runs)
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
  # Normalize the expected promise too (trim + collapse whitespace)
  COMPLETION_PROMISE_NORMALIZED=$(printf '%s' "$COMPLETION_PROMISE" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g')
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE_NORMALIZED" ]]; then
    end_loop "Completion promise detected. Mode: $MODE"
  fi
fi

# Continue loop - update iteration counter
NEXT_ITERATION=$((ITERATION + 1))

PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$RALPH_STATE_FILE")
[[ -n "$PROMPT_TEXT" ]] || end_loop "No prompt found in state file"

# Update iteration in frontmatter
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$RALPH_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$RALPH_STATE_FILE"

# Build system message
MODE_UPPER=$(echo "$MODE" | tr '[:lower:]' '[:upper:]')
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="Ralph Wiggum iteration $NEXT_ITERATION [$MODE_UPPER] | To stop: output <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE)"
else
  SYSTEM_MSG="Ralph Wiggum iteration $NEXT_ITERATION [$MODE_UPPER] | No completion promise set"
fi

jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'
