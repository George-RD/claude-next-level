# Hooks & Session Management Spec

Chief-of-staff plugin hooks for session initialization, context preservation,
and orchestrator state management across context refreshes.

## Table of Contents

1. [hooks.json](#1-hooksjson)
2. [init.sh (SessionStart)](#2-initsh-sessionstart-hook)
3. [checkpoint.sh (PreCompact + Stop)](#3-checkpointsh-precompact--stop-hook)
4. [Session State Management](#4-session-state-management)
5. [Error Handling Contract](#5-error-handling-contract)

---

## 1. hooks.json

### Purpose

Define lifecycle hooks that keep the chief-of-staff orchestrator operational
across the full session lifecycle: startup, context compaction, and shutdown.

### Content

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/init.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/checkpoint.sh precompact",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/checkpoint.sh stop",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### Design Notes

- **Three hooks, two scripts.** `init.sh` handles startup. `checkpoint.sh` handles
  both PreCompact and Stop, distinguished by a positional argument (`precompact`
  or `stop`). This avoids duplicating checkpoint logic.
- **No PostToolUse hook.** Context monitoring is delegated to the next-level
  plugin's `context-monitor.sh` if installed. Chief-of-staff reads context state
  from next-level's state directory rather than duplicating the tracking.
- **No matcher on SessionStart/PreCompact/Stop.** These hooks fire unconditionally
  (no tool matcher needed for lifecycle events).
- **Timeout of 10s** across all hooks. Checkpoint writes are local JSON files and
  should complete in under 1s; the 10s ceiling covers pathological filesystem
  latency.

---

## 2. init.sh (SessionStart Hook)

### Purpose

Bootstrap the orchestrator operating mode at session start. Inject commands,
defaults, and behavioral directives. Detect resumable sessions. Survey the
environment for VCS type and installed plugins.

### Trigger

SessionStart lifecycle event. Fires on every fresh session and after every
context compaction (since SessionStart re-fires post-compact).

### Input

Hook receives JSON on stdin from Claude Code:

```json
{
  "session_id": "abc-123",
  "transcript_path": "/path/to/transcript",
  "cwd": "/Users/dev/project"
}
```

### Logic (pseudocode)

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

INPUT=$(read_hook_input)
SESSION_ID=$(json_field "$INPUT" "session_id")
SESSION_ID="${SESSION_ID:-unknown}"
CWD=$(json_field "$INPUT" "cwd")
CWD="${CWD:-$(pwd)}"

COS_HOME="${CHIEF_OF_STAFF_HOME:-${HOME}/.chief-of-staff}"
SESSION_DIR="${COS_HOME}/sessions/${SESSION_ID}"
CONFIG_FILE="${COS_HOME}/config.json"
STATE_FILE="${SESSION_DIR}/state.json"
CHECKPOINT_FILE="${SESSION_DIR}/checkpoint.json"

mkdir -p "$SESSION_DIR/agents"

# ─── Phase 1: Check for session resumption ───
resumption_context=""

if [[ -f "$CHECKPOINT_FILE" ]]; then
  # Previous checkpoint exists — this is a resumption
  resumption_context=$(build_resumption_context "$CHECKPOINT_FILE")
fi

# ─── Phase 2: Detect VCS type ───
vcs_type="git"  # default
if command -v jj &>/dev/null && [[ -d "${CWD}/.jj" ]]; then
  vcs_type="jj"
fi

# ─── Phase 3: Detect installed plugins ───
installed_plugins=()
# Check for cycle plugin
if [[ -d "${CLAUDE_PLUGIN_ROOT}/../cycle" ]] || \
   claude_has_plugin "cycle" 2>/dev/null; then
  installed_plugins+=("cycle")
fi
# Check for ralph-wiggum
if [[ -d "${CLAUDE_PLUGIN_ROOT}/../ralph-wiggum" ]] || \
   claude_has_plugin "ralph-wiggum" 2>/dev/null; then
  installed_plugins+=("ralph-wiggum")
fi
# Check for next-level
if [[ -d "${CLAUDE_PLUGIN_ROOT}/../next-level" ]] || \
   claude_has_plugin "next-level" 2>/dev/null; then
  installed_plugins+=("next-level")
fi

plugins_json=$(printf '%s\n' "${installed_plugins[@]}" | jq -R . | jq -s .)

# ─── Phase 4: Load global config (or defaults) ───
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

# ─── Phase 5: Initialize session state ───
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

# ─── Phase 6: Build output message ───
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
```

### Helper: build_resumption_context()

```bash
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
    [.work_items // [] | .[] | select(.status == "pending")] | length
  ' "$checkpoint_file")

  agent_summary=$(jq -r '
    .agents // {} | to_entries |
    if length == 0 then "No agents recorded"
    else
      [.[] | "\(.value.name) (\(.value.type)): \(.value.status)"] | join(", ")
    end
  ' "$checkpoint_file")

  echo "Status: ${status}"
  echo "Waves: ${wave_progress}"
  echo "Pending work items: ${pending_count}"
  echo "Agents: ${agent_summary}"
}
```

### Output

On success, emits a JSON result message to stdout and exits with code 2
(which tells Claude Code to inject the result text into the conversation):

```json
{"result":"[chief-of-staff] Orchestrator active.\n\nCommands: /cos, /cos:research, ...\n..."}
```

### Error Handling

| Condition | Behavior |
|-----------|----------|
| `jq` not installed | Print error message, exit 2 (warn user) |
| Session dir not writable | Print error message, exit 2 |
| Checkpoint file corrupted | Log warning, skip resumption, continue init |
| Plugin detection fails | Silently default to empty plugin list |
| VCS detection fails | Default to `git` |

---

## 3. checkpoint.sh (PreCompact + Stop Hook)

### Purpose

Persist the current orchestrator state so a future session (or post-compaction
context) can resume without losing track of agents, waves, and work items.

### Trigger

- **PreCompact**: Context compaction is about to happen. Save state before
  the conversation history is summarized.
- **Stop**: Session is ending (user pressed Ctrl-C, said "stop", or the model
  decided to stop). Write a final checkpoint.

### Input

Positional argument distinguishes the trigger:

```
checkpoint.sh precompact    # called by PreCompact hook
checkpoint.sh stop          # called by Stop hook
```

Hook receives JSON on stdin:

```json
{
  "session_id": "abc-123",
  "transcript_path": "/path/to/transcript"
}
```

### Logic (pseudocode)

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

TRIGGER="${1:-stop}"  # "precompact" or "stop"

INPUT=$(read_hook_input)
SESSION_ID=$(json_field "$INPUT" "session_id")
SESSION_ID="${SESSION_ID:-unknown}"

COS_HOME="${CHIEF_OF_STAFF_HOME:-${HOME}/.chief-of-staff}"
SESSION_DIR="${COS_HOME}/sessions/${SESSION_ID}"
STATE_FILE="${SESSION_DIR}/state.json"
CHECKPOINT_FILE="${SESSION_DIR}/checkpoint.json"

mkdir -p "$SESSION_DIR"

# ─── Read current state ───
if [[ ! -f "$STATE_FILE" ]]; then
  # No state to checkpoint — chief-of-staff was not active this session
  exit 0
fi

state=$(cat "$STATE_FILE")

# ─── Read context percentage from next-level if available ───
NL_STATE="${NEXT_LEVEL_STATE:-${HOME}/.next-level}/sessions/${SESSION_ID}"
context_pct=0
if [[ -f "${NL_STATE}/context_state" ]]; then
  context_pct=$(cat "${NL_STATE}/context_state" 2>/dev/null || echo "0")
fi

# ─── Build checkpoint ───
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Extract summaries from current state
active_agents=$(echo "$state" | jq '[.agents // {} | to_entries[] | select(.value.status == "running") | .value]')
completed_agents=$(echo "$state" | jq '[.agents // {} | to_entries[] | select(.value.status == "complete") | {name: .value.name, type: .value.type, work_item_id: .value.work_item_id}]')
failed_agents=$(echo "$state" | jq '[.agents // {} | to_entries[] | select(.value.status == "failed") | {name: .value.name, type: .value.type, work_item_id: .value.work_item_id}]')
pending_items=$(echo "$state" | jq '[.work_items // [] | .[] | select(.status == "pending")]')
waves=$(echo "$state" | jq '.waves // []')
quality_gates=$(echo "$state" | jq '.quality_gates // {}')

# Write checkpoint
jq -n \
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
  }' > "$CHECKPOINT_FILE"

# ─── Update state with checkpoint timestamp ───
echo "$state" | jq \
  --arg ts "$timestamp" \
  --argjson ctx "$context_pct" \
  '.updated_at = $ts | .context.last_checked = $ts | .context.percentage = $ctx | .context.checkpoints += [$ts]' \
  > "$STATE_FILE"

# ─── Print output based on trigger ───
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
```

### Output

Writes `checkpoint.json` to the session directory. Emits a result message:

**PreCompact:**

```json
{"result":"[chief-of-staff] Pre-compaction checkpoint saved.\nState will be restored after compaction."}
```

**Stop (example):**

```json
{"result":"[chief-of-staff] Session checkpoint saved.\n\nSession: abc-123\nStatus: DISPATCHING\nContext: 45%\nAgents: 2 active, 3 completed\nPending items: 1\nWaves: 2 total, current: 2\n\nWARNING: 2 agent(s) still running.\nTheir work may be incomplete. Review on resume.\n\nTo resume: start a new session in the same project.\nChief-of-staff will detect the checkpoint and offer to continue."}
```

### Error Handling

| Condition | Behavior |
|-----------|----------|
| No state.json exists | Silent exit 0 (nothing to checkpoint) |
| state.json is malformed | Attempt best-effort parse; write partial checkpoint |
| Filesystem write fails | Print error to stderr, exit 1 (non-blocking) |
| next-level state unavailable | Default context_pct to 0 |

---

## 4. Session State Management

### 4.1 Directory Structure

```
~/.chief-of-staff/
  config.json                           # Global configuration (optional)
  sessions/
    {session-id}/                       # session-id = Claude Code native ID
      state.json                        # Live session state (canonical schema)
      checkpoint.json                   # Snapshot (written at PreCompact/Stop)
      agents/
        {agent-id}.json                 # Per-agent detailed state
  workspaces/                           # Isolated agent workspaces
    item-1/
    wave-2-item-3/
```

### 4.2 state.json Schema

> **Canonical schema**: See [specs/state-schema.md](state-schema.md) for the full schema definition, field reference, status enums, state transitions, and examples.

Live session state, updated by the orchestrator skills as agents are dispatched
and complete. The schema is defined in the canonical reference above. Key points
relevant to hooks:

- **Session ID**: Claude Code's native `session_id` from hook stdin. Used as directory name.
- **Session status**: `PLANNING | DISPATCHING | MONITORING | CHECKPOINTING | COMPLETE` (SCREAMING_CASE).
- **Work item status**: `pending | dispatched | complete | failed` (lowercase).
- **Waves**: Array of objects with `number` field and `pending | active | complete | failed` status.
- **Agents**: Object keyed by agent-id with `name`, `type`, `status`, `work_item_id`, `workspace_path`, `started_at`, `completed_at`.
- **Work items**: Array with full detail including `issue`, `pr_number`, `workspace`, `workspace_type`, `branch`, `error`.
- **Context**: Object with `percentage`, `last_checked`, `checkpoints[]`.
- **Retry budget**: 2 retries (3 total attempts). Tracked by counting agents referencing the same `work_item_id`.
- **Wave cap**: 4 agents max (configurable via `config.json` `max_parallel_agents`).

### 4.3 checkpoint.json Schema

Written by `checkpoint.sh`. Designed for fast resumption — contains everything
needed to brief the orchestrator on what was happening.

```json
{
  "session_id": "string",
  "checkpointed_at": "ISO 8601",
  "trigger": "precompact | stop",
  "status": "PLANNING | DISPATCHING | MONITORING | COMPLETE",
  "context_percentage": 45,
  "agents": {
    "active": [
      {
        "name": "string",
        "type": "research | implement | review",
        "status": "running",
        "work_item_id": "string",
        "workspace_path": "string | null",
        "started_at": "ISO 8601"
      }
    ],
    "completed": [
      {
        "name": "string",
        "type": "string",
        "work_item_id": "string"
      }
    ],
    "failed": [
      {
        "name": "string",
        "type": "string",
        "work_item_id": "string"
      }
    ]
  },
  "work_items": {
    "pending": [
      {
        "id": "string",
        "description": "string",
        "type": "string",
        "wave": "number",
        "depends_on": ["string"]
      }
    ],
    "pending_count": 3
  },
  "waves": [
    {
      "number": 1,
      "status": "complete | active | pending",
      "items": ["wi-001"],
      "started_at": "ISO 8601 | null",
      "completed_at": "ISO 8601 | null"
    }
  ],
  "quality_gates": {}
}
```

### 4.4 Per-Agent State: agents/{agent-id}.json

Optional detailed per-agent state. Written by the orchestrator skills when an
agent is dispatched, updated when it completes. This file stores verbose output
that is too large for the main state.json.

```json
{
  "agent_id": "string",
  "name": "string",
  "type": "research | implement | review",
  "work_item_id": "string",
  "prompt": "string — the prompt sent to the subagent",
  "workspace_path": "string | null",
  "isolation_type": "worktree | jj | none",
  "started_at": "ISO 8601",
  "completed_at": "ISO 8601 | null",
  "status": "running | complete | failed",
  "exit_code": "number | null",
  "result_summary": "string | null — brief summary of output",
  "result_files": ["string — files created or modified"],
  "error": "string | null — error message if failed"
}
```

### 4.5 config.json Schema (Global Configuration)

User-level configuration at `~/.chief-of-staff/config.json`. Created by
`/cos:setup` or manually. All fields have sensible defaults if the file is
missing.

```json
{
  "default_isolation": "worktree | jj | none",
  "max_parallel_agents": 4,
  "quality_gate_mode": "strict | lenient | disabled",
  "merge_strategy": "merge-as-you-go | batch",
  "auto_pr": true,
  "checkpoint_threshold": 80
}
```

| Field | Default | Description |
|-------|---------|-------------|
| `default_isolation` | `"worktree"` | How to isolate agent workspaces. `jj` uses jj workspaces, `worktree` uses git worktrees, `none` runs in the main tree. |
| `max_parallel_agents` | `4` | Maximum concurrent background agents. |
| `quality_gate_mode` | `"strict"` | `strict` = agents must pass lint/test. `lenient` = warn only. `disabled` = skip. |
| `merge_strategy` | `"merge-as-you-go"` | `merge-as-you-go` = merge each agent's work when it completes. `batch` = merge all at end of wave. |
| `auto_pr` | `true` | Automatically create a PR when all waves complete. |
| `checkpoint_threshold` | `80` | Context percentage at which to auto-checkpoint. |

---

## 5. Error Handling Contract

All hook scripts follow the same contract established by the next-level plugin:

### Exit Codes

| Code | Meaning | Claude Code Behavior |
|------|---------|---------------------|
| `0` | Success, no message to inject | Silent, session continues |
| `1` | Script error | Hook failure logged, session continues |
| `2` | Success, inject stdout as context | Message from stdout appears in conversation |

### Stdout Protocol

When exit code is 2, stdout must contain exactly one JSON object:

```json
{"result": "message text to inject into conversation"}
```

The `result` value may contain `\n` for line breaks.

### Stderr

Used for debug logging only. Not injected into the conversation.

### Idempotency

Both hooks must be idempotent:

- **init.sh**: Running twice for the same session must not corrupt state.
  The state.json creation is guarded by an existence check. Checkpoint
  resumption reads but does not delete the checkpoint (deletion happens only
  when the orchestrator explicitly marks work as re-dispatched).
- **checkpoint.sh**: Running twice overwrites the checkpoint file atomically
  (jq writes to the same path). No append-only structures.

### Dependency: jq

Both scripts require `jq`. If `jq` is not available:

```bash
if ! command -v jq &>/dev/null; then
  echo '{"result":"[chief-of-staff] ERROR: jq is required but not installed. Install with: brew install jq (macOS) or apt install jq (Linux)."}'
  exit 2
fi
```

This check should be the first operation in both scripts.

### utils.sh

The chief-of-staff utils.sh should provide the same core functions as
next-level's utils.sh, adapted for chief-of-staff's state directory:

```bash
#!/usr/bin/env bash
# Shared utilities for chief-of-staff hooks

COS_HOME="${CHIEF_OF_STAFF_HOME:-${HOME}/.chief-of-staff}"

ensure_session_dir() {
  local session_id="$1"
  local dir="${COS_HOME}/sessions/${session_id}"
  mkdir -p "$dir/agents"
  echo "$dir"
}

read_hook_input() {
  cat
}

json_field() {
  local json="$1" field="$2"
  echo "$json" | jq -r ".$field // empty"
}

# Check if a Claude Code plugin is installed by looking for its directory
# in common plugin locations.
claude_has_plugin() {
  local plugin_name="$1"
  local plugin_root="${CLAUDE_PLUGIN_ROOT:-}"

  # If we know our own plugin root, check siblings
  if [[ -n "$plugin_root" ]]; then
    local parent
    parent=$(dirname "$plugin_root")
    [[ -d "${parent}/${plugin_name}" ]] && return 0
  fi

  # Check .claude/plugins in project root
  local project_root
  project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  [[ -d "${project_root}/.claude/plugins/${plugin_name}" ]] && return 0

  return 1
}

# Atomically write JSON to a file (write to temp, then mv)
write_json() {
  local filepath="$1"
  local content="$2"
  local tmpfile="${filepath}.tmp.$$"
  echo "$content" > "$tmpfile"
  mv "$tmpfile" "$filepath"
}

# Read state.json for current session, or echo "{}" if missing
read_state() {
  local session_dir="$1"
  local state_file="${session_dir}/state.json"
  if [[ -f "$state_file" ]]; then
    cat "$state_file"
  else
    echo "{}"
  fi
}

# Update a field in state.json
update_state() {
  local session_dir="$1"
  local jq_filter="$2"
  local state_file="${session_dir}/state.json"
  local current
  current=$(read_state "$session_dir")
  local updated
  updated=$(echo "$current" | jq "$jq_filter")
  write_json "$state_file" "$updated"
}
```

---

## Lifecycle Walkthrough

A complete session lifecycle illustrating when each hook fires and what state
transitions occur:

### Fresh Session

```
1. User starts Claude Code in project directory
2. SessionStart fires → init.sh runs
   - No checkpoint found → fresh init
   - Detects git, installed plugins
   - Creates state.json with status=PLANNING
   - Injects orchestrator operating mode into context
3. User gives task → orchestrator plans, dispatches agents
   - state.json updated: status=DISPATCHING, then MONITORING
4. Context hits 80% → next-level's context-monitor warns
5. PreCompact fires → checkpoint.sh precompact
   - Writes checkpoint.json with current agent/wave state
6. Context compacted → SessionStart fires again → init.sh runs
   - Finds checkpoint.json → injects resumption context
   - Orchestrator continues from where it left off
7. All waves complete → status=COMPLETE
8. User stops → Stop fires → checkpoint.sh stop
   - Writes final checkpoint with completion status
   - Prints summary
```

### Resumed Session

```
1. User starts new Claude Code session in same project
2. SessionStart fires → init.sh runs
   - Finds checkpoint.json from previous session
   - Injects resumption context: pending items, agent results
   - Orchestrator picks up remaining work
```

### Session With No Chief-of-Staff Activity

```
1. SessionStart fires → init.sh runs → injects operating mode
2. User does simple work, never invokes /cos commands
3. Stop fires → checkpoint.sh runs
   - No state.json exists → silent exit 0
   - No checkpoint written
```
