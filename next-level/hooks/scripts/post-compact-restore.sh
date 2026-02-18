#!/usr/bin/env bash
# PostCompact restore — SessionStart hook that detects post-compaction state
# Reads saved state and injects structured context to resume work.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

INPUT=$(read_hook_input)
SESSION_ID=$(json_field "$INPUT" "session_id")
SESSION_ID="${SESSION_ID:-unknown}"

STATE_DIR="${NEXT_LEVEL_STATE}/sessions/${SESSION_ID}"
SNAPSHOT_FILE="$STATE_DIR/pre-compact-state.json"

# Only run if we have a pre-compact snapshot for this session
if [[ ! -f "$SNAPSHOT_FILE" ]]; then
  exit 0
fi

# Read the snapshot
snapshot=$(cat "$SNAPSHOT_FILE")
context_pct=$(echo "$snapshot" | jq -r '.context_pct // "unknown"')
recent_file=$(echo "$snapshot" | jq -r '.recent_file // ""')
working_dir=$(echo "$snapshot" | jq -r '.working_directory // ""')

# Build active specs summary
specs_summary=$(echo "$snapshot" | jq -r '
  .active_specs // [] |
  if length == 0 then "No active specs"
  else [.[] | "\(.name // "unnamed") — \(.status // "unknown")"] | join(", ")
  end
')

# Build restore message
message="Context was compacted. Restoring session state."
message="${message}\nActive specs: ${specs_summary}"
if [[ -n "$recent_file" ]]; then
  message="${message}\nLast file: ${recent_file}"
fi
if [[ -n "$working_dir" ]]; then
  message="${message}\nWorking dir: ${working_dir}"
fi
message="${message}\nContext was at: ${context_pct}%"

# Clean up the snapshot (one-time use)
rm -f "$SNAPSHOT_FILE"

jq -n --arg msg "$message" '{"result":$msg}'
exit 2
