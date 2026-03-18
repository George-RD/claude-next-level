#!/usr/bin/env bash
# PreCompact hook — captures active state before context compaction
# Saves spec state, task progress, and current working file to a JSON snapshot.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

INPUT=$(read_hook_input)
SESSION_ID=$(json_field "$INPUT" "session_id")
SESSION_ID="${SESSION_ID:-unknown}"

STATE_DIR=$(ensure_state_dir "$SESSION_ID")
SPECS_DIR=$(ensure_specs_dir)
SNAPSHOT_FILE="$STATE_DIR/pre-compact-state.json"

# Collect active specs
active_specs="[]"
if compgen -G "$SPECS_DIR/*.json" > /dev/null 2>&1; then
  active_specs=$(jq -s '[.[] | select(.status != "VERIFIED" and .status != null)]' "$SPECS_DIR"/*.json 2>/dev/null || echo "[]")
fi

# Get current working directory
current_dir="$(pwd)"

# Get recent file being worked on (from transcript if available)
TRANSCRIPT=$(json_field "$INPUT" "transcript_path" 2>/dev/null || echo "")
recent_file=""
if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
  recent_file=$(grep -oE '"file_path"\s*:\s*"[^"]+"' "$TRANSCRIPT" 2>/dev/null \
    | tail -1 \
    | sed 's/"file_path"\s*:\s*"//;s/"$//' \
    || true)
fi

# Get context percentage if tracked
context_pct=""
if [[ -f "$STATE_DIR/context_state" ]]; then
  context_pct=$(cat "$STATE_DIR/context_state")
fi

# Write snapshot using jq for safe JSON construction
jq -n \
  --arg sid "$SESSION_ID" \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg ctx "${context_pct:-unknown}" \
  --arg wd "$current_dir" \
  --arg rf "$recent_file" \
  --argjson specs "$active_specs" \
  '{session_id: $sid, timestamp: $ts, context_pct: $ctx, working_directory: $wd, recent_file: $rf, active_specs: $specs}' \
  > "$SNAPSHOT_FILE"

exit 0
