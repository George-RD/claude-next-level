#!/usr/bin/env bash
# Context Monitor — PostToolUse hook (async)
# Tracks context window usage %. Warns at 80%, forces handoff at 90%, emergency at 95%.
# Uses MOCK_CONTEXT_PCT for testing, otherwise estimates from transcript size.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

INPUT=$(read_hook_input)
SESSION_ID=$(json_field "$INPUT" "session_id")

# Use a fallback session ID if none provided
SESSION_ID="${SESSION_ID:-unknown}"

STATE_DIR=$(ensure_state_dir "$SESSION_ID")
LAST_CHECK_FILE="$STATE_DIR/context_last_check"
CONTEXT_STATE_FILE="$STATE_DIR/context_state"

# --- Throttle: skip if < 30s since last check AND below 80% ---
now=$(date +%s)
if [[ -f "$LAST_CHECK_FILE" ]]; then
  last_check=$(cat "$LAST_CHECK_FILE")
  elapsed=$((now - last_check))
  if [[ "$elapsed" -lt 30 ]]; then
    # If we have a previous state and it was below 80, skip
    if [[ -f "$CONTEXT_STATE_FILE" ]]; then
      prev_pct=$(cat "$CONTEXT_STATE_FILE")
      if [[ "$prev_pct" -lt 80 ]]; then
        exit 0
      fi
    fi
  fi
fi

# --- Determine context percentage ---
if [[ -n "${MOCK_CONTEXT_PCT:-}" ]]; then
  pct="$MOCK_CONTEXT_PCT"
else
  # Estimate from transcript file size
  # Claude Code's context is ~200k tokens. Average ~4 chars/token = ~800KB max.
  # We look for the transcript/conversation file to estimate usage.
  TRANSCRIPT="${CLAUDE_TRANSCRIPT:-}"
  if [[ -z "$TRANSCRIPT" || ! -f "$TRANSCRIPT" ]]; then
    # No transcript available, skip silently
    exit 0
  fi
  file_size=$(wc -c < "$TRANSCRIPT" | tr -d ' ')
  max_size=800000  # ~200k tokens * 4 chars
  pct=$((file_size * 100 / max_size))
  # Cap at 100
  [[ "$pct" -gt 100 ]] && pct=100
fi

# --- Save state ---
echo "$now" > "$LAST_CHECK_FILE"
echo "$pct" > "$CONTEXT_STATE_FILE"

# --- Act on thresholds ---
if [[ "$pct" -ge 95 ]]; then
  cat <<EOF
{"result":"EMERGENCY: Context at ${pct}% (>=95%). Stop immediately. Save all work state to continuation.md NOW and end the session."}
EOF
  # Write continuation file
  CONT_FILE="$STATE_DIR/continuation.md"
  cat > "$CONT_FILE" <<CONT
# Continuation — Emergency Context Limit

Session: $SESSION_ID
Context usage: ${pct}%
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Status
Emergency stop triggered at ${pct}% context usage.
Resume from this point in a new session.
CONT
  exit 2

elif [[ "$pct" -ge 90 ]]; then
  # Force handoff — write continuation.md
  CONT_FILE="$STATE_DIR/continuation.md"
  cat > "$CONT_FILE" <<CONT
# Continuation — Context Limit Approaching

Session: $SESSION_ID
Context usage: ${pct}%
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Instructions
Context window at ${pct}%. Wrap up current task, document remaining work here,
and prepare to hand off to a new session.
CONT
  cat <<EOF
{"result":"Context at ${pct}% (>=90%). Handoff required. Continuation file written to $CONT_FILE. Finish current task, document remaining work in continuation.md, and end session."}
EOF
  exit 2

elif [[ "$pct" -ge 80 ]]; then
  cat <<EOF
{"result":"Context at ${pct}% (>=80%). Warning: approaching context limit. Prioritize completing current task. Consider writing a continuation plan."}
EOF
  exit 2
fi

# Below 80% — silent
exit 0
