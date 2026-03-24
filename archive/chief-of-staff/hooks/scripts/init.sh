#!/usr/bin/env bash
# chief-of-staff: SessionStart hook
#
# Bootstrap the orchestrator at session start:
#   1. Check jq dependency
#   2. Read hook input (session_id, cwd)
#   3. Check for session resumption (existing checkpoint)
#   4. Detect VCS type (jj vs git)
#   5. Detect installed sibling plugins
#   6. Load global config (or defaults)
#   7. Initialize state.json (if new session)
#   8. Print orchestrator context (exit 2 for injection)
#
# Idempotent: running twice for the same session does not corrupt state.
set -euo pipefail

# ── Dependency check ──────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo '{"result":"[chief-of-staff] ERROR: jq is required but not installed. Install with: brew install jq (macOS) or apt install jq (Linux)."}'
  exit 2
fi

# ── Source shared utilities ───────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# ── Helper: build_resumption_context ──────────────────────────────────
# Parses checkpoint.json and returns a multi-line summary string for
# session resumption. Must be defined before Phase 1 calls it.
build_resumption_context() {
  local checkpoint_file="$1"

  local status wave_progress pending_count agent_summary

  status=$(jq -r '.status // "unknown"' "$checkpoint_file")
  wave_progress=$(jq -r '
    .waves // [] |
    if length == 0 then "No waves recorded"
    else
      [.[] | "Wave \(.number): \(.status)"] | join(", ")
    end
  ' "$checkpoint_file")

  pending_count=$(jq -r '
    [.work_items.pending // [] | .[]] | length
  ' "$checkpoint_file")

  agent_summary=$(jq -r '
    .agents // {} |
    [(.active // [])[], (.completed // [])[], (.failed // [])[]] |
    if length == 0 then "No agents recorded"
    else
      [.[] | "\(.name) (\(.type)): \(.status // "unknown")"] | join(", ")
    end
  ' "$checkpoint_file")

  echo "Status: ${status}"
  echo "Waves: ${wave_progress}"
  echo "Pending work items: ${pending_count}"
  echo "Agents: ${agent_summary}"
}

# ── Read hook input ───────────────────────────────────────────────────
INPUT=$(read_hook_input)
SESSION_ID=$(json_field "$INPUT" "session_id")
SESSION_ID="${SESSION_ID:-unknown}"
CWD=$(json_field "$INPUT" "cwd")
CWD="${CWD:-$(pwd)}"

# ── Paths ─────────────────────────────────────────────────────────────
SESSION_DIR=$(ensure_session_dir "$SESSION_ID")
CONFIG_FILE="${COS_HOME}/config.json"
STATE_FILE="${SESSION_DIR}/state.json"
CHECKPOINT_FILE="${SESSION_DIR}/checkpoint.json"

# ── Phase 1: Check for session resumption ─────────────────────────────
resumption_context=""

if [[ -f "$CHECKPOINT_FILE" ]]; then
  # Previous checkpoint exists — this is a resumption.
  # build_resumption_context reads checkpoint.json and produces a
  # human-readable summary of what was happening.
  resumption_context=$(build_resumption_context "$CHECKPOINT_FILE" 2>/dev/null || true)
fi

# ── Phase 2: Detect VCS type ─────────────────────────────────────────
vcs_type="git"  # default
if jj root >/dev/null 2>&1; then
  vcs_type="jj"
fi

# ── Phase 3: Detect installed plugins ─────────────────────────────────
installed_plugins=()

if claude_has_plugin "cycle" 2>/dev/null; then
  installed_plugins+=("cycle")
fi
if claude_has_plugin "ralph-wiggum" 2>/dev/null; then
  installed_plugins+=("ralph-wiggum")
fi
if claude_has_plugin "next-level" 2>/dev/null; then
  installed_plugins+=("next-level")
fi

# Build JSON array from bash array
if [[ ${#installed_plugins[@]} -gt 0 ]]; then
  plugins_json=$(printf '%s\n' "${installed_plugins[@]}" | jq -R . | jq -s .)
else
  plugins_json="[]"
fi

# ── Phase 4: Load global config (or defaults) ─────────────────────────
if [[ -f "$CONFIG_FILE" ]]; then
  max_parallel=$(jq -r '.max_parallel_agents // 4' "$CONFIG_FILE")
  isolation=$(jq -r '.default_isolation // "worktree"' "$CONFIG_FILE")
  quality_mode=$(jq -r '.quality_gate_mode // "strict"' "$CONFIG_FILE")
  merge_strategy=$(jq -r '.merge_strategy // "merge-as-you-go"' "$CONFIG_FILE")
  checkpoint_threshold=$(jq -r '.checkpoint_threshold // 80' "$CONFIG_FILE")
else
  max_parallel=4
  isolation="worktree"
  quality_mode="strict"
  merge_strategy="merge-as-you-go"
  checkpoint_threshold=80
fi

# ── Phase 5: Initialize session state ─────────────────────────────────
# Only create state.json if it does not already exist (idempotent).
if [[ ! -f "$STATE_FILE" ]]; then
  jq -n \
    --arg sid "$SESSION_ID" \
    --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg vcs "$vcs_type" \
    --argjson plugins "$plugins_json" \
    '{
      session_id: $sid,
      created_at: $ts,
      updated_at: $ts,
      vcs_type: $vcs,
      status: "PLANNING",
      installed_plugins: $plugins,
      work_items: [],
      waves: [],
      agents: {},
      quality_gates: {},
      context: {
        percentage: 0,
        last_checked: $ts,
        checkpoints: []
      }
    }' > "$STATE_FILE"
fi

# ── Phase 6: Build output message ─────────────────────────────────────
output="[chief-of-staff] Orchestrator active."
output="${output}\n"
output="${output}\nCommands: /cos, /cos:research, /cos:implement, /cos:review, /cos:wave, /cos:status"
output="${output}\nVCS: ${vcs_type} | Isolation: ${isolation} | Max parallel: ${max_parallel}"
output="${output}\nQuality: ${quality_mode} | Merge: ${merge_strategy}"
output="${output}\nPlugins: $(IFS=', '; echo "${installed_plugins[*]:-none}")"
output="${output}\n"
output="${output}\nOperating mode:"
output="${output}\n  - Delegate everything to background agents"
output="${output}\n  - Parallelize independent work (up to ${max_parallel} agents)"
output="${output}\n  - Never block the main thread"
output="${output}\n  - Review agent results, synthesize, coordinate"
output="${output}\n  - Checkpoint at ${checkpoint_threshold}% context"

if [[ -n "$resumption_context" ]]; then
  output="${output}\n"
  output="${output}\n--- RESUMING FROM CHECKPOINT ---"
  output="${output}\n${resumption_context}"
fi

jq -n --arg msg "$output" '{"result":$msg}'
exit 2
