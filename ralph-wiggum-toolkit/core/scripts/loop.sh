#!/bin/bash
# Ralph Wiggum Toolkit v2 — External autonomous loop runner
#
# Runs claude -p in a while loop with a full state machine, quality gates,
# cycle detection, and VCS integration. The loop owns enforcement — the agent
# just writes code.
#
# Usage: ./loop.sh [plan|plan-work "scope"|build] [max_iterations]
# Examples:
#   ./loop.sh              # Build mode, reads max from state.json
#   ./loop.sh 20           # Build mode, override max iterations
#   ./loop.sh plan         # Plan mode, push after each iteration
#   ./loop.sh plan 5       # Plan mode, max 5 iterations
#   ./loop.sh plan-work "user auth with OAuth"   # Scoped planning
#
# Exit codes:
#   0 — Success: all tasks complete, Tier 3 passed
#   1 — Safety: max iterations reached
#   2 — Escalation: cycle detected or fix task limit exceeded
#   3 — Infrastructure: gate command not found or broken toolchain

set -euo pipefail

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ============================================================
# EARLY INITIALIZATION (needed by plan mode which dispatches before full init)
# ============================================================

# Detect current branch (git or jj)
CURRENT_BRANCH=""
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
fi

# ============================================================
# PLAN MODE — Simple loop, no gates
# ============================================================
run_plan_mode() {
  local plan_prompt="$1"
  local max=$2

  local iter=0
  while true; do
    if [[ $max -gt 0 ]] && [[ $iter -ge $max ]]; then
      echo "Plan mode: reached max iterations ($max)"
      break
    fi

    iter=$((iter + 1))
    echo -e "\n======================== RALPH PLAN ITERATION $iter ========================\n"

    if [[ "$MODE" == "plan-work" ]]; then
      export WORK_SCOPE
      envsubst < "$plan_prompt" | claude -p \
        --dangerously-skip-permissions \
        --output-format=stream-json \
        --model "$CLAUDE_MODEL" \
        --verbose
    else
      claude -p \
        --dangerously-skip-permissions \
        --output-format=stream-json \
        --model "$CLAUDE_MODEL" \
        --verbose \
        < "$plan_prompt"
    fi

    # Push after each plan iteration
    vcs_push "$CURRENT_BRANCH"
  done

  # After planning, run plan-to-state if tasks.json was produced
  if [[ -f "ralph/tasks.json" ]] && [[ -f "$RALPH_STATE_FILE" ]]; then
    echo ""
    echo "Running plan-to-state validation..."
    PLAN_TO_STATE="$SCRIPT_DIR/plan-to-state.sh"
    if [[ -x "$PLAN_TO_STATE" ]]; then
      "$PLAN_TO_STATE"
    else
      echo "Warning: plan-to-state.sh not found or not executable" >&2
    fi
  fi

  exit 0
}

# ============================================================
# ARGUMENT PARSING
# ============================================================
MODE="build"
PROMPT_FILE="PROMPT_build.md"
MAX_ITERATIONS=0
WORK_SCOPE=""

if [[ "${1:-}" == "plan" ]]; then
  MODE="plan"
  PROMPT_FILE="PROMPT_plan.md"
  MAX_ITERATIONS=${2:-0}
  if [[ -n "$MAX_ITERATIONS" ]] && ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
    echo "Error: max_iterations must be a positive integer, got: '$MAX_ITERATIONS'" >&2
    exit 1
  fi
elif [[ "${1:-}" == "plan-work" ]]; then
  MODE="plan-work"
  PROMPT_FILE="PROMPT_plan.md"
  if [[ -z "${2:-}" ]]; then
    echo "Error: plan-work requires a work description" >&2
    echo "Usage: ./loop.sh plan-work \"description of the work\"" >&2
    exit 1
  fi
  WORK_SCOPE="$2"
  MAX_ITERATIONS=${3:-5}
  if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
    echo "Error: max_iterations must be a positive integer, got: '$MAX_ITERATIONS'" >&2
    exit 1
  fi
elif [[ "${1:-}" == "build" ]]; then
  MAX_ITERATIONS=${2:-0}
  if [[ -n "$MAX_ITERATIONS" ]] && ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
    echo "Error: max_iterations must be a positive integer, got: '$MAX_ITERATIONS'" >&2
    exit 1
  fi
elif [[ "${1:-}" =~ ^[0-9]+$ ]]; then
  MAX_ITERATIONS=$1
elif [[ -n "${1:-}" ]]; then
  echo "Error: Unknown mode '${1:-}'." >&2
  echo "Usage: ./loop.sh [plan|plan-work \"scope\"|build] [max_iterations]" >&2
  exit 1
fi

# ============================================================
# INITIALIZATION (CURRENT_BRANCH already set above)
# ============================================================

# Read model + maxIterations + taskCount in one jq call
CLAUDE_MODEL="opus"
if [[ -f "$RALPH_STATE_FILE" ]]; then
  read -r CLAUDE_MODEL STATE_MAX TASK_COUNT < <(
    jq -r '[(.model // "opus"), (.maxIterations // 0), (.tasks | length)] | @tsv' "$RALPH_STATE_FILE"
  )
  [[ -z "$CLAUDE_MODEL" || "$CLAUDE_MODEL" == "null" ]] && CLAUDE_MODEL="opus"
  if [[ "$MODE" == "build" ]] && [[ $MAX_ITERATIONS -eq 0 ]] && [[ "$STATE_MAX" =~ ^[0-9]+$ ]] && [[ $STATE_MAX -gt 0 ]]; then
    MAX_ITERATIONS=$STATE_MAX
  fi
fi

# Print banner
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Ralph Wiggum Toolkit v2: Autonomous Loop"
echo "Mode:   $MODE"
echo "Model:  $CLAUDE_MODEL"
[[ -n "$CURRENT_BRANCH" ]] && echo "Branch: $CURRENT_BRANCH"
[[ -n "$WORK_SCOPE" ]] && echo "Scope:  $WORK_SCOPE"
[[ $MAX_ITERATIONS -gt 0 ]] && echo "Max:    $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ============================================================
# PLAN MODE — Dispatch early, no state machine needed
# ============================================================
if [[ "$MODE" == "plan" ]] || [[ "$MODE" == "plan-work" ]]; then
  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "Error: $PROMPT_FILE not found" >&2
    echo "Run /ralph init first, or create it manually." >&2
    exit 1
  fi
  run_plan_mode "$PROMPT_FILE" "$MAX_ITERATIONS"
fi

# ============================================================
# BUILD MODE — Full state machine
# ============================================================

# Verify prerequisites
if [[ ! -f "$RALPH_STATE_FILE" ]]; then
  echo "Error: $RALPH_STATE_FILE not found" >&2
  echo "Run /ralph init to create the project state." >&2
  exit 1
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Error: $PROMPT_FILE not found" >&2
  echo "Run /ralph init first, or create it manually." >&2
  exit 1
fi

# Verify jq is available
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed" >&2
  exit 3
fi

# Verify tasks exist
TASK_COUNT=$(jq '.tasks | length' "$RALPH_STATE_FILE")
if [[ "$TASK_COUNT" -eq 0 ]]; then
  echo "Error: No tasks in $RALPH_STATE_FILE" >&2
  echo "Run the plan phase first: ./loop.sh plan" >&2
  exit 1
fi

# Ensure ralph directory and journal exist
mkdir -p ralph
touch "$RALPH_JOURNAL"

# ============================================================
# MAIN BUILD LOOP
# ============================================================
ITERATION=$(read_state '.iteration // 0')

while true; do
  ITERATION=$((ITERATION + 1))

  # ── Step 0: Safety check ──────────────────────────────────
  if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -gt $MAX_ITERATIONS ]]; then
    echo ""
    echo "SAFETY: Max iterations reached ($MAX_ITERATIONS)"
    log_iteration 0 false "none" "max_iterations" 0
    exit 1
  fi

  # ── Step 1: Read state ────────────────────────────────────
  TASK_ID=$(read_state '.currentTaskId')

  if [[ -z "$TASK_ID" ]] || [[ "$TASK_ID" == "null" ]]; then
    echo "Error: No currentTaskId in state.json" >&2
    exit 1
  fi

  # Check if current task exists and is pending
  TASK_STATUS=$(jq -r --arg tid "$TASK_ID" '.tasks[] | select(.id == $tid) | .status' "$RALPH_STATE_FILE")
  if [[ "$TASK_STATUS" == "done" ]]; then
    # Try to advance past done tasks
    if ! advance_task; then
      # All tasks done — fall through to Tier 3 below
      TASK_ID="ALL_DONE"
    else
      TASK_ID=$(read_state '.currentTaskId')
    fi
  fi

  # Update iteration and task attempts in one write (guard ALL_DONE)
  if [[ "$TASK_ID" != "ALL_DONE" ]]; then
    write_state --argjson iter "$ITERATION" --arg tid "$TASK_ID" \
      '.iteration = $iter | .taskIteration = (.taskIteration + 1) |
       (.tasks[] | select(.id == $tid)).attempts += 1'
  else
    write_state --argjson iter "$ITERATION" '.iteration = $iter'
  fi

  echo ""
  echo "================================================================"
  echo "  RALPH ITERATION $ITERATION — Task: $TASK_ID"
  echo "  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "================================================================"
  echo ""

  # ── All tasks done? Run Tier 3 ────────────────────────────
  if [[ "$TASK_ID" == "ALL_DONE" ]]; then
    echo "All tasks complete. Running Tier 3 quality gate..."

    # Need changed files for gate commands
    detect_changed_files

    ITER_START=$(date +%s)

    gate3_rc=0
    run_gate 3 "$ITERATION" "$TASK_ID" || gate3_rc=$?

    ITER_END=$(date +%s)
    DURATION_MS=$(( (ITER_END - ITER_START) * 1000 ))

    if [[ $gate3_rc -eq 3 ]]; then
      log_iteration 3 false "infrastructure" "infrastructure_fail" "$DURATION_MS"
      echo "INFRASTRUCTURE FAILURE during Tier 3 gate" >&2
      exit 3
    elif [[ $gate3_rc -eq 0 ]]; then
      echo ""
      echo "============================================"
      echo "  ALL TASKS COMPLETE — TIER 3 PASSED"
      echo "============================================"
      log_iteration 3 true "none" "success" "$DURATION_MS"
      vcs_push "$CURRENT_BRANCH"
      exit 0
    else
      echo "Tier 3 failed. Creating final cleanup task..."
      log_iteration 3 false "code" "tier3_fail" "$DURATION_MS"

      # Create a cleanup fix task from the last completed task
      LAST_DONE_ID=$(jq -r '[.tasks[] | select(.status == "done")] | last | .id // empty' "$RALPH_STATE_FILE")

      if [[ -z "$LAST_DONE_ID" ]]; then
        echo "ESCALATION: Tier 3 failed but no completed tasks to create fix task from" >&2
        exit 2
      fi

      if ! create_fix_task "$LAST_DONE_ID" 3; then
        echo "ESCALATION: Cannot create more fix tasks" >&2
        exit 2
      fi

      TASK_ID=$(read_state '.currentTaskId')
      # Continue the loop with the new fix task
      continue
    fi
  fi

  # ── Step 2: Assemble context ──────────────────────────────
  assemble_current_task "$TASK_ID"

  # Read task description and attempt info in one call
  TASK_INFO=$(jq -r --arg tid "$TASK_ID" '
    (.tasks[] | select(.id == $tid) | .description) + "\t" +
    (.taskIteration | tostring) + "\t" + (.maxTaskIterations | tostring)
  ' "$RALPH_STATE_FILE")
  IFS=$'\t' read -r TASK_DESC TASK_ITER MAX_TASK_ITER <<< "$TASK_INFO"
  echo "Task: $TASK_DESC"
  echo "Attempt: $TASK_ITER of $MAX_TASK_ITER"
  echo ""

  # ── Step 3: Run agent ─────────────────────────────────────
  ITER_START=$(date +%s)

  # Run claude -p with the build prompt. The agent reads current-task.md,
  # AGENTS.md, and last-gate-result.json as referenced in PROMPT_build.md.
  set +e
  claude -p \
    --dangerously-skip-permissions \
    --output-format=stream-json \
    --model "$CLAUDE_MODEL" \
    --verbose \
    < "$PROMPT_FILE"
  AGENT_EXIT=$?
  set -e

  if [[ $AGENT_EXIT -ne 0 ]]; then
    echo "Warning: Agent exited with code $AGENT_EXIT (may be token limit)" >&2
  fi

  # ── Step 4: Detect changed files ──────────────────────────
  detect_changed_files

  CHANGED_COUNT=0
  if [[ -s "$RALPH_CHANGED_FILES" ]]; then
    CHANGED_COUNT=$(wc -l < "$RALPH_CHANGED_FILES" | tr -d ' ')
  fi
  echo "Changed files: $CHANGED_COUNT"

  if [[ $CHANGED_COUNT -eq 0 ]]; then
    echo "Warning: No files changed in this iteration" >&2
    ITER_END=$(date +%s)
    DURATION_MS=$(( (ITER_END - ITER_START) * 1000 ))
    log_iteration 0 false "none" "no_changes" "$DURATION_MS"

    # Check for cycle (no-change iterations count as repeated failure)
    if ! check_cycle "$TASK_ID"; then
      exit 2
    fi
    continue
  fi

  # ── Step 5: Run Tier 1 gate ───────────────────────────────
  echo ""
  echo "── Tier 1 Gate ──"

  gate1_rc=0
  run_gate 1 "$ITERATION" "$TASK_ID" || gate1_rc=$?

  # ── Step 6: Tag iteration ─────────────────────────────────
  tag_iteration "$ITERATION"

  ITER_END=$(date +%s)
  DURATION_MS=$(( (ITER_END - ITER_START) * 1000 ))

  # ── Step 7: Evaluate ──────────────────────────────────────

  # Infrastructure failure → EXIT immediately
  if [[ $gate1_rc -eq 3 ]]; then
    echo "INFRASTRUCTURE FAILURE — halting loop" >&2
    log_iteration 1 false "infrastructure" "infrastructure_fail" "$DURATION_MS"
    exit 3
  fi

  # Tier 1 failed → check for cycles, loop back
  if [[ $gate1_rc -ne 0 ]]; then
    echo "Tier 1 FAILED — looping back"
    log_iteration 1 false "code" "gate_fail" "$DURATION_MS"

    if ! check_cycle "$TASK_ID"; then
      exit 2
    fi
    continue
  fi

  # ── Step 8: Tier 1 passed — VCS commit + push ────────────
  echo "Tier 1 PASSED"

  COMMIT_SHA=""
  COMMIT_MSG="ralph: $TASK_ID iteration $ITERATION"
  vcs_commit "$COMMIT_MSG"

  # Capture commit SHA
  if [[ "$(_ralph_vcs)" != "jj" ]]; then
    COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "")
  fi

  vcs_push "$CURRENT_BRANCH"

  # ── Run Tier 2 gate ───────────────────────────────────────
  echo ""
  echo "── Tier 2 Gate ──"

  gate2_rc=0
  run_gate 2 "$ITERATION" "$TASK_ID" || gate2_rc=$?

  if [[ $gate2_rc -eq 3 ]]; then
    echo "INFRASTRUCTURE FAILURE during Tier 2 — halting loop" >&2
    log_iteration 2 false "infrastructure" "infrastructure_fail" "$DURATION_MS" "$COMMIT_SHA"
    exit 3
  fi

  if [[ $gate2_rc -eq 0 ]]; then
    echo "Tier 2 PASSED — task $TASK_ID complete"
    log_iteration 2 true "none" "task_advance" "$DURATION_MS" "$COMMIT_SHA"

    # Advance to next task
    if ! advance_task; then
      # All tasks done — next iteration will run Tier 3
      echo "All tasks complete. Next iteration will run Tier 3."
    fi
    continue
  fi

  # Tier 2 failed → create fix task
  echo "Tier 2 FAILED — creating fix task"
  log_iteration 2 false "code" "tier2_fail" "$DURATION_MS" "$COMMIT_SHA"

  if ! create_fix_task "$TASK_ID" 2; then
    echo "ESCALATION: Fix task limit exceeded for $TASK_ID" >&2
    exit 2
  fi

  # Loop continues with the fix task
done
