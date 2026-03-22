#!/bin/bash
# Ralph Wiggum - Setup in-session loop state
# Creates .claude/ralph-wiggum.local.md state file for the stop hook

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Parse arguments
MODE=""
PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"
WORK_SCOPE=""
PROMPT_FILE_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --mode)
      if [[ -z "${2:-}" ]] || [[ "${2:-}" == -* ]]; then
        echo "Error: --mode requires a value (plan, build, or plan-work)" >&2
        exit 1
      fi
      MODE="$2"
      shift 2
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations requires a positive integer" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --completion-promise requires text" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    --work-scope)
      if [[ -z "${2:-}" ]] || [[ "$2" == -* ]]; then
        echo "Error: --work-scope requires a text argument" >&2
        exit 1
      fi
      WORK_SCOPE="$2"
      shift 2
      ;;
    --prompt-file)
      if [[ -z "${2:-}" ]] || [[ "${2:-}" == -* ]]; then
        echo "Error: --prompt-file requires a path" >&2
        exit 1
      fi
      PROMPT_FILE_OVERRIDE="$2"
      shift 2
      ;;
    -h|--help)
      cat << 'HELP_EOF'
Ralph Wiggum Loop Setup

USAGE:
  setup-loop.sh --mode <plan|build|plan-work> [OPTIONS] [PROMPT...]

OPTIONS:
  --mode <mode>                 Required: plan, build, or plan-work
  --max-iterations <n>          Max iterations (default: unlimited)
  --completion-promise <text>   Promise phrase to signal completion
  --work-scope <text>           Work description (plan-work mode only)
  --prompt-file <path>          Override the default prompt file for this mode
  -h, --help                    Show this help
HELP_EOF
      exit 0
      ;;
    *)
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

# Validate mode
if [[ -z "$MODE" ]]; then
  echo "Error: --mode is required (plan, build, or plan-work)" >&2
  exit 1
fi

# Determine prompt file and label for mode
case "$MODE" in
  plan)      PROMPT_FILE="PROMPT_plan.md";  MODE_LABEL="PLANNING" ;;
  build)     PROMPT_FILE="PROMPT_build.md"; MODE_LABEL="BUILDING" ;;
  plan-work) PROMPT_FILE="PROMPT_plan.md";  MODE_LABEL="SCOPED PLANNING" ;;
  *)
    echo "Error: Unknown mode '$MODE'. Use plan, build, or plan-work." >&2
    exit 1
    ;;
esac

# Override prompt file if --prompt-file was provided
if [[ -n "${PROMPT_FILE_OVERRIDE:-}" ]]; then
  PROMPT_FILE="$PROMPT_FILE_OVERRIDE"
fi

# Build the prompt
V2_BUILD=false

if [[ "$MODE" == "build" ]] && [[ -f "$RALPH_STATE_FILE" ]]; then
  # v2 build mode: use coordinator prompt and assemble initial task
  V2_BUILD=true

  # Resume from persisted currentTaskId (set by state machine after fix tasks, etc.)
  # Only fall back to scanning if currentTaskId is null/empty (fresh start)
  CURRENT_TASK_ID=$(jq -r '.currentTaskId // empty' "$RALPH_STATE_FILE")

  if [[ -z "$CURRENT_TASK_ID" ]]; then
    # No currentTaskId persisted — find first actionable task
    CURRENT_TASK_ID=$(jq -r '
      [.tasks[] | select(.status == "pending" or .status == "in-progress")] | .[0].id // empty
    ' "$RALPH_STATE_FILE")
  fi

  if [[ -z "$CURRENT_TASK_ID" ]]; then
    echo "Error: No pending or in-progress tasks in $RALPH_STATE_FILE" >&2
    exit 1
  fi

  # Mark the task as in-progress if it's pending
  jq --arg id "$CURRENT_TASK_ID" '
    .tasks |= map(if .id == $id and .status == "pending" then .status = "in-progress" else . end)
  ' "$RALPH_STATE_FILE" > "$RALPH_STATE_FILE.tmp" && mv "$RALPH_STATE_FILE.tmp" "$RALPH_STATE_FILE"

  # Assemble the first current-task.md
  assemble_current_task "$CURRENT_TASK_ID"

  PROMPT='# Ralph v2 In-Session Build

You are the coordinator. For each task:

1. Read ralph/state.json for the current task
2. Read ralph/current-task.md for the full task context
3. Delegate implementation to a subagent via the Task tool
   - Pass: ralph/current-task.md, AGENTS.md, ralph/last-gate-result.json
   - The subagent writes code only
4. When the subagent exits, the stop hook runs quality gates automatically
5. You will receive the next task context or failure context
6. Delegate the next task to a new subagent

Do NOT implement code directly. Delegate everything via Task tool.
Each subagent gets fresh context. This is intentional.'

  echo "Ralph v2: Assembled $RALPH_CURRENT_TASK for task $CURRENT_TASK_ID"
else
  # v1 behavior: use prompt file as-is
  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "Error: $PROMPT_FILE not found. Run /ralph init first." >&2
    exit 1
  fi
  PROMPT=$(cat "$PROMPT_FILE")
fi

if [[ "$MODE" == "plan-work" ]]; then
  if [[ -z "$WORK_SCOPE" ]]; then
    echo "Error: --work-scope required for plan-work mode" >&2
    exit 1
  fi
  # Escape sed special characters in WORK_SCOPE to prevent injection
  ESCAPED_SCOPE=$(printf '%s\n' "$WORK_SCOPE" | sed 's/[&/\]/\\&/g')
  PROMPT=$(echo "$PROMPT" | sed "s/\[project-specific goal\]/${ESCAPED_SCOPE}/g")
  PROMPT="SCOPED PLANNING for: ${WORK_SCOPE}

${PROMPT}

IMPORTANT: This is SCOPED PLANNING for \"${WORK_SCOPE}\" only. Create a plan containing ONLY tasks directly related to this work scope."
fi

# Allow additional prompt text to be appended
if [[ ${#PROMPT_PARTS[@]} -gt 0 ]]; then
  EXTRA="${PROMPT_PARTS[*]}"
  PROMPT="${PROMPT}

Additional instructions: ${EXTRA}"
fi

# Create state file
mkdir -p .claude

if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  # Escape backslashes first, then double quotes for valid YAML
  ESCAPED_PROMISE="${COMPLETION_PROMISE//\\/\\\\}"
  ESCAPED_PROMISE="${ESCAPED_PROMISE//\"/\\\"}"
  COMPLETION_PROMISE_YAML="\"$ESCAPED_PROMISE\""
else
  COMPLETION_PROMISE_YAML="null"
fi

cat > .claude/ralph-wiggum.local.md <<EOF
---
active: true
mode: $MODE
iteration: 1
session_id: ${CLAUDE_CODE_SESSION_ID:-}
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

# Output setup summary
MAX_ITER_DISPLAY=$( [[ $MAX_ITERATIONS -gt 0 ]] && echo "$MAX_ITERATIONS" || echo "unlimited" )
PROMISE_DISPLAY=$( [[ "$COMPLETION_PROMISE" != "null" ]] && echo "$COMPLETION_PROMISE" || echo "none" )

echo "Ralph Wiggum: $MODE_LABEL loop activated"
echo ""
echo "Mode: $MODE_LABEL"
echo "Iteration: 1"
echo "Max iterations: $MAX_ITER_DISPLAY"
echo "Completion promise: $PROMISE_DISPLAY"
[[ -n "$WORK_SCOPE" ]] && echo "Work scope: $WORK_SCOPE"
echo ""
echo "The stop hook will feed the same prompt back after each iteration."
echo "Your previous work persists in files and git history."
echo ""
echo "To monitor: head -10 .claude/ralph-wiggum.local.md"
echo "To cancel:  /ralph cancel"

if [[ $MAX_ITERATIONS -eq 0 ]] && [[ "$COMPLETION_PROMISE" == "null" ]]; then
  echo ""
  echo "WARNING: No stopping condition set. Loop runs indefinitely."
  echo "  Set --max-iterations or --completion-promise to auto-stop."
fi

if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  echo ""
  echo "To complete this loop, output: <promise>$COMPLETION_PROMISE</promise>"
  echo "The statement MUST be completely and unequivocally TRUE."
fi

echo ""
echo "$PROMPT"
