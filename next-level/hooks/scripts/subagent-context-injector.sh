#!/usr/bin/env bash
# Subagent Context Injector — SubagentStart hook
# Fires when a subagent is spawned. Injects project context.
# Cannot block (exit 2 only shows stderr to user).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/config.sh"

INPUT=$(read_hook_input)
AGENT_TYPE=$(json_field "$INPUT" "agent_type")
AGENT_ID=$(json_field "$INPUT" "agent_id")

# Log subagent spawning for observability
SESSIONS_DIR="${NEXT_LEVEL_STATE}/sessions"
mkdir -p "$SESSIONS_DIR"
AGENT_LOG="${SESSIONS_DIR}/subagent-log.jsonl"

# Append to log (keep last 100 entries) — use flock to prevent races
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
(
  flock -w 5 200 || exit 0
  jq -n --arg ts "$TIMESTAMP" --arg id "$AGENT_ID" --arg type "$AGENT_TYPE" \
    '{timestamp: $ts, agent_id: $id, agent_type: $type}' >> "$AGENT_LOG"
  # Trim log to last 100 lines
  if [[ -f "$AGENT_LOG" ]] && [[ $(wc -l < "$AGENT_LOG") -gt 100 ]]; then
    tail -100 "$AGENT_LOG" > "${AGENT_LOG}.tmp" && mv "${AGENT_LOG}.tmp" "$AGENT_LOG"
  fi
) 200>"${AGENT_LOG}.lock"

exit 0
