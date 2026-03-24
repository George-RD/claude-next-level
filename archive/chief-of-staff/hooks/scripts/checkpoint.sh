#!/usr/bin/env bash
# chief-of-staff: PreCompact + Stop hook
#
# Persist the current orchestrator state so a future session (or
# post-compaction context) can resume without losing track of agents,
# waves, and work items.
#
# Usage:
#   checkpoint.sh precompact   — called by PreCompact hook
#   checkpoint.sh stop         — called by Stop hook
#
# Reads state.json, writes checkpoint.json, and (on Stop) prints a
# resumption summary. Idempotent: running twice overwrites the
# checkpoint atomically.
set -euo pipefail

# ── Dependency check ──────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo '{"result":"[chief-of-staff] ERROR: jq is required but not installed. Install with: brew install jq (macOS) or apt install jq (Linux)."}'
  exit 2
fi

# ── Source shared utilities ───────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# ── Parse trigger argument ────────────────────────────────────────────
TRIGGER="${1:-stop}"  # "precompact" or "stop"

# ── Read hook input ───────────────────────────────────────────────────
INPUT=$(read_hook_input)
SESSION_ID=$(json_field "$INPUT" "session_id")
SESSION_ID="${SESSION_ID:-unknown}"

# ── Paths ─────────────────────────────────────────────────────────────
SESSION_DIR="${COS_HOME}/sessions/${SESSION_ID}"
STATE_FILE="${SESSION_DIR}/state.json"
CHECKPOINT_FILE="${SESSION_DIR}/checkpoint.json"

mkdir -p "$SESSION_DIR"

# ── Read current state ────────────────────────────────────────────────
if [[ ! -f "$STATE_FILE" ]]; then
  # No state to checkpoint — chief-of-staff was not active this session
  exit 0
fi

state=$(cat "$STATE_FILE")

# ── Read context percentage from next-level if available ──────────────
NL_STATE="${NEXT_LEVEL_STATE:-${HOME}/.next-level}/sessions/${SESSION_ID}"
context_pct=0
if [[ -f "${NL_STATE}/context_state" ]]; then
  context_pct=$(cat "${NL_STATE}/context_state" 2>/dev/null || echo "0")
  # Ensure it's a valid number
  if ! [[ "$context_pct" =~ ^[0-9]+$ ]]; then
    context_pct=0
  fi
fi

# ── Build checkpoint ──────────────────────────────────────────────────
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Extract agent summaries from current state
active_agents=$(echo "$state" | jq '[.agents // {} | to_entries[] | select(.value.status == "running") | .value]')
completed_agents=$(echo "$state" | jq '[.agents // {} | to_entries[] | select(.value.status == "complete") | {name: .value.name, type: .value.type, work_item_id: .value.work_item_id}]')
failed_agents=$(echo "$state" | jq '[.agents // {} | to_entries[] | select(.value.status == "failed") | {name: .value.name, type: .value.type, work_item_id: .value.work_item_id}]')
pending_items=$(echo "$state" | jq '[.work_items // [] | .[] | select(.status == "pending")]')
waves=$(echo "$state" | jq '.waves // []')
quality_gates=$(echo "$state" | jq '.quality_gates // {}')

# Write checkpoint atomically
checkpoint_json=$(jq -n \
  --arg sid "$SESSION_ID" \
  --arg ts "$timestamp" \
  --arg trigger "$TRIGGER" \
  --arg status "$(echo "$state" | jq -r '.status // "unknown"')" \
  --argjson ctx_pct "$context_pct" \
  --argjson active "$active_agents" \
  --argjson completed "$completed_agents" \
  --argjson failed "$failed_agents" \
  --argjson pending "$pending_items" \
  --argjson waves "$waves" \
  --argjson qg "$quality_gates" \
  '{
    session_id: $sid,
    checkpointed_at: $ts,
    trigger: $trigger,
    status: $status,
    context_percentage: $ctx_pct,
    agents: {
      active: $active,
      completed: $completed,
      failed: $failed
    },
    work_items: {
      pending: $pending,
      pending_count: ($pending | length)
    },
    waves: $waves,
    quality_gates: $qg
  }')

write_json "$CHECKPOINT_FILE" "$checkpoint_json"

# ── Update state with checkpoint timestamp ────────────────────────────
updated_state=$(echo "$state" | jq \
  --arg ts "$timestamp" \
  --argjson ctx "$context_pct" \
  '.updated_at = $ts | .context.last_checked = $ts | .context.percentage = $ctx | .context.checkpoints += [$ts]')

write_json "$STATE_FILE" "$updated_state"

# ── Print output based on trigger ─────────────────────────────────────
if [[ "$TRIGGER" == "stop" ]]; then
  # On stop, print resumption instructions
  active_count=$(echo "$active_agents" | jq 'length')
  completed_count=$(echo "$completed_agents" | jq 'length')
  pending_count=$(echo "$pending_items" | jq 'length')
  wave_count=$(echo "$waves" | jq 'length')
  current_wave=$(echo "$waves" | jq -r '[.[] | select(.status == "active")] | .[0].number // "none"')

  output="[chief-of-staff] Session checkpoint saved."
  output="${output}\n"
  output="${output}\nSession: ${SESSION_ID}"
  output="${output}\nStatus: $(echo "$state" | jq -r '.status // "unknown"')"
  output="${output}\nContext: ${context_pct}%"
  output="${output}\nAgents: ${active_count} active, ${completed_count} completed"
  output="${output}\nPending items: ${pending_count}"
  output="${output}\nWaves: ${wave_count} total, current: ${current_wave}"

  if [[ "$active_count" -gt 0 ]]; then
    output="${output}\n"
    output="${output}\nWARNING: ${active_count} agent(s) still running."
    output="${output}\nTheir work may be incomplete. Review on resume."
  fi

  if [[ "$pending_count" -gt 0 ]]; then
    output="${output}\n"
    output="${output}\nTo resume: start a new session in the same project."
    output="${output}\nChief-of-staff will detect the checkpoint and offer to continue."
  fi

  jq -n --arg msg "$output" '{"result":$msg}'
  exit 2

elif [[ "$TRIGGER" == "precompact" ]]; then
  # On precompact, print brief state summary for post-compact context
  output="[chief-of-staff] Pre-compaction checkpoint saved."
  output="${output}\nState will be restored after compaction."
  jq -n --arg msg "$output" '{"result":$msg}'
  exit 2
fi

exit 0
