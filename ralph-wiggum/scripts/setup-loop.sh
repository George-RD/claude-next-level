#!/bin/bash
# Ralph Wiggum - Setup in-session loop state
# Creates .claude/ralph-wiggum.local.md state file for the stop hook

set -euo pipefail

# Parse arguments
MODE=""
PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"
WORK_SCOPE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --mode)
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
      WORK_SCOPE="$2"
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

# Build the prompt based on mode
case "$MODE" in
  plan)
    if [[ ! -f "PROMPT_plan.md" ]]; then
      echo "Error: PROMPT_plan.md not found. Run /ralph-wiggum:init first." >&2
      exit 1
    fi
    PROMPT=$(cat PROMPT_plan.md)
    MODE_LABEL="PLANNING"
    ;;
  build)
    if [[ ! -f "PROMPT_build.md" ]]; then
      echo "Error: PROMPT_build.md not found. Run /ralph-wiggum:init first." >&2
      exit 1
    fi
    PROMPT=$(cat PROMPT_build.md)
    MODE_LABEL="BUILDING"
    ;;
  plan-work)
    if [[ -z "$WORK_SCOPE" ]]; then
      echo "Error: --work-scope required for plan-work mode" >&2
      exit 1
    fi
    if [[ ! -f "PROMPT_plan.md" ]]; then
      echo "Error: PROMPT_plan.md not found. Run /ralph-wiggum:init first." >&2
      exit 1
    fi
    # Create scoped planning prompt
    PROMPT=$(cat PROMPT_plan.md | sed "s/\[project-specific goal\]/${WORK_SCOPE}/g")
    PROMPT="SCOPED PLANNING for: ${WORK_SCOPE}

${PROMPT}

IMPORTANT: This is SCOPED PLANNING for \"${WORK_SCOPE}\" only. Create a plan containing ONLY tasks directly related to this work scope."
    MODE_LABEL="SCOPED PLANNING"
    ;;
  *)
    echo "Error: Unknown mode '$MODE'. Use plan, build, or plan-work." >&2
    exit 1
    ;;
esac

# Allow additional prompt text to be appended
if [[ ${#PROMPT_PARTS[@]} -gt 0 ]]; then
  EXTRA="${PROMPT_PARTS[*]}"
  PROMPT="${PROMPT}

Additional instructions: ${EXTRA}"
fi

# Create state file
mkdir -p .claude

if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  COMPLETION_PROMISE_YAML="\"$COMPLETION_PROMISE\""
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

# Output setup message
cat <<EOF
Ralph Wiggum: $MODE_LABEL loop activated

Mode: $MODE_LABEL
Iteration: 1
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "${COMPLETION_PROMISE} (ONLY output when TRUE)"; else echo "none"; fi)
$(if [[ -n "$WORK_SCOPE" ]]; then echo "Work scope: $WORK_SCOPE"; fi)

The stop hook will feed the same prompt back after each iteration.
Your previous work persists in files and git history.

To monitor: head -10 .claude/ralph-wiggum.local.md
To cancel:  /ralph-wiggum:cancel
EOF

if [[ $MAX_ITERATIONS -eq 0 ]] && [[ "$COMPLETION_PROMISE" == "null" ]]; then
  echo ""
  echo "WARNING: No stopping condition set. Loop runs indefinitely."
  echo "  Set --max-iterations or --completion-promise to auto-stop."
fi

# Display completion promise requirements
if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  echo ""
  echo "To complete this loop, output: <promise>$COMPLETION_PROMISE</promise>"
  echo "The statement MUST be completely and unequivocally TRUE."
fi

echo ""
echo "$PROMPT"
