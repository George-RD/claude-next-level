#!/usr/bin/env bash
# Session Cleanup — SessionEnd hook
# Fires when session terminates. Saves final state and cleans up temp files.
# Cannot block (exit 2 only shows stderr).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

INPUT=$(read_hook_input)
SESSION_ID=$(json_field "$INPUT" "session_id")
SESSION_ID="${SESSION_ID:-unknown}"

SESSIONS_DIR="${NEXT_LEVEL_STATE}/sessions"

# Clean up session-specific temp files
SESSION_DIR="${SESSIONS_DIR}/${SESSION_ID}"
if [[ -d "$SESSION_DIR" ]]; then
  # Remove transient tracking files (edit counts, transcript offsets)
  rm -f "$SESSION_DIR/edits_since_test" "$SESSION_DIR/transcript_offset" 2>/dev/null || true
  # Remove empty session dirs
  rmdir "$SESSION_DIR" 2>/dev/null || true
fi

# Clean up stale session dirs older than 7 days
# Guard: only proceed if SESSIONS_DIR is within NEXT_LEVEL_STATE
if [[ -d "$SESSIONS_DIR" && "$SESSIONS_DIR" == "${NEXT_LEVEL_STATE}/sessions" ]]; then
  find "$SESSIONS_DIR" -maxdepth 1 -mindepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
fi

# Clean up escape hatch file
rm -f "${NEXT_LEVEL_STATE}/last_stop_attempt" 2>/dev/null || true

exit 0
