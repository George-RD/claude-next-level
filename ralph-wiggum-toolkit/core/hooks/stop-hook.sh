#!/bin/bash
# Ralph Wiggum Stop Hook v2
# Prevents session exit when a loop is active, feeding the prompt back to continue.
# In v2 build mode with state.json: runs tiered quality gates, manages state machine,
# commits on gate pass, creates fix tasks on gate fail, detects cycles.

set -euo pipefail

# Source shared library
source "$(cd "$(dirname "$0")/../scripts" && pwd)/lib.sh"

RALPH_LOCAL_STATE=".claude/ralph-wiggum.local.md"

if [[ ! -f "$RALPH_LOCAL_STATE" ]]; then
  exit 0
fi

HOOK_INPUT=$(cat)

# ============================================================
# STOP-HOOK-SPECIFIC HELPERS
# ============================================================

# Clean up state file and exit (loop is done or broken)
end_loop() {
  [[ -n "${1:-}" ]] && echo "Ralph Wiggum: $1" >&2
  rm -f "$RALPH_LOCAL_STATE"
  exit 0
}

# Parse markdown frontmatter (YAML between ---) and extract values
get_field() { echo "$FRONTMATTER" | grep "^$1:" | sed "s/$1: *//" ; }

# Output JSON to block exit with continuation prompt
block_exit() {
  local reason=$1
  local system_msg=$2

  jq -n \
    --arg prompt "$reason" \
    --arg msg "$system_msg" \
    '{
      "decision": "block",
      "reason": $prompt,
      "systemMessage": $msg
    }'
}

# ============================================================
# PARSE FRONTMATTER
# ============================================================

FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPH_LOCAL_STATE")
ITERATION=$(get_field iteration)
MAX_ITERATIONS=$(get_field max_iterations)
MODE=$(get_field mode)
COMPLETION_PROMISE=$(get_field completion_promise | sed 's/^"\(.*\)"$/\1/')

# Session isolation: only this session's loop should block
STATE_SESSION=$(get_field session_id || true)
HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
if [[ -n "$STATE_SESSION" ]] && [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  exit 0
fi

# Validate numeric fields
[[ "$ITERATION" =~ ^[0-9]+$ ]]      || end_loop "State file corrupted (invalid iteration: '$ITERATION')"
[[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] || end_loop "State file corrupted (invalid max_iterations: '$MAX_ITERATIONS')"

# Check max iterations
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  end_loop "Max iterations ($MAX_ITERATIONS) reached. Mode: $MODE"
fi

# ============================================================
# FRONTMATTER UPDATE
# ============================================================

update_frontmatter_iteration() {
  local next_iter=$1
  local tmp
  tmp=$(mktemp)
  sed "s/^iteration: .*/iteration: $next_iter/" "$RALPH_LOCAL_STATE" > "$tmp"
  mv "$tmp" "$RALPH_LOCAL_STATE"
}

get_last_commit_hash() {
  git rev-parse --short HEAD 2>/dev/null || echo ""
}

# ============================================================
# V2 BUILD MODE (state machine with quality gates)
# ============================================================

handle_v2_build() {
  # Batch-read current state fields in one jq call
  local state_data
  state_data=$(jq -r '[.currentTaskId, .iteration] | @tsv' "$RALPH_STATE_FILE")
  local current_task_id iteration
  IFS=$'\t' read -r current_task_id iteration <<< "$state_data"

  # Increment iteration in state.json
  write_state --argjson n "$((iteration + 1))" '.iteration = $n'

  # ── Step 1: Detect changed files ──
  detect_changed_files

  local has_changes=false
  [[ -s "$RALPH_CHANGED_FILES" ]] && has_changes=true

  # ── Step 2: Run Tier 1 gate ──
  local tier1_result=0
  if $has_changes; then
    run_gate 1 "$((iteration + 1))" "$current_task_id" || tier1_result=$?
  else
    # No changes — treat as Tier 1 fail (nothing was done)
    jq -n --argjson iter "$((iteration + 1))" --arg tid "$current_task_id" \
      '{iteration: $iter, taskId: $tid, tier: 1, passed: false,
        failureType: "code", results: [{command: "(no changes detected)",
        exitCode: 1, output: "No files were changed in this iteration.", truncated: false}]}' \
      > "$RALPH_GATE_RESULT"
    tier1_result=1
  fi

  # ── Infrastructure failure: halt immediately ──
  if [[ $tier1_result -eq 3 ]]; then
    log_iteration 1 false "infrastructure" "infrastructure_halt" 0 "" "$((iteration + 1))" "$current_task_id"
    end_loop "Infrastructure failure: gate command not found or not executable. Check ralph/state.json gateConfig."
  fi

  # ── Tier 1 failed ──
  if [[ $tier1_result -ne 0 ]]; then
    # check_cycle returns 1 on cycle detected, 0 on no cycle
    if ! check_cycle "$current_task_id"; then
      log_iteration 1 false "code" "cycle_escalation" 0 "" "$((iteration + 1))" "$current_task_id"
      end_loop "Cycle detected for task $current_task_id. See $RALPH_ESCALATION"
    fi

    # Read task iteration limits in one call
    local iter_data
    iter_data=$(jq -r '[.taskIteration, (.maxTaskIterations // 5)] | @tsv' "$RALPH_STATE_FILE")
    local task_iter max_task_iter
    IFS=$'\t' read -r task_iter max_task_iter <<< "$iter_data"

    if [[ $task_iter -ge $max_task_iter ]]; then
      log_iteration 1 false "code" "max_task_iterations" 0 "" "$((iteration + 1))" "$current_task_id"
      end_loop "Max task iterations reached for $current_task_id."
    fi

    write_state --argjson n "$((task_iter + 1))" '.taskIteration = $n'
    log_iteration 1 false "code" "gate_fail" 0 "" "$((iteration + 1))" "$current_task_id"

    local prompt="Continue working on the current task. The Tier 1 quality gate FAILED.

Read @ralph/current-task.md for your assignment.
Read @AGENTS.md for build/test/lint commands.
Read @ralph/last-gate-result.json for the specific failures to fix.

Fix the gate failures first, then continue implementing the task."

    local sys_msg="Ralph v2 iteration $((iteration + 1)) [BUILD] | Task: $current_task_id | Gate: Tier 1 FAILED"

    update_frontmatter_iteration "$((ITERATION + 1))"

    block_exit "$prompt" "$sys_msg"
    exit 0
  fi

  # ── Tier 1 passed: commit changes ──
  local commit_msg="ralph: $current_task_id iteration $((iteration + 1))"
  vcs_commit "$commit_msg"
  local commit_hash
  commit_hash=$(get_last_commit_hash)

  # ── Step 3: Run Tier 2 gate ──
  local tier2_result=0
  run_gate 2 "$((iteration + 1))" "$current_task_id" || tier2_result=$?

  # Infrastructure failure on Tier 2
  if [[ $tier2_result -eq 3 ]]; then
    log_iteration 2 false "infrastructure" "infrastructure_halt" 0 "$commit_hash" "$((iteration + 1))" "$current_task_id"
    end_loop "Infrastructure failure during Tier 2. Check ralph/state.json gateConfig."
  fi

  if [[ $tier2_result -eq 0 ]]; then
    # ── Tier 2 passed: advance to next task ──
    log_iteration 2 true "none" "task_advance" 0 "$commit_hash" "$((iteration + 1))" "$current_task_id"

    # advance_task returns 1 when all tasks are done
    if advance_task "$current_task_id"; then
      # More tasks to do — read the new task ID
      local next_id
      next_id=$(read_state '.currentTaskId')

      assemble_current_task "$next_id"
      update_frontmatter_iteration "$((ITERATION + 1))"

      local prompt="Continue building. Previous task completed successfully.

Read @ralph/current-task.md for your next assignment.
Read @AGENTS.md for build/test/lint commands.

Implement the task described in current-task.md. Nothing else."

      local sys_msg="Ralph v2 iteration $((iteration + 1)) [BUILD] | Task: $next_id | Gate: Tier 2 PASSED — advancing"
      block_exit "$prompt" "$sys_msg"
      exit 0
    else
      # ── All tasks complete: run Tier 3 ──
      local tier3_result=0
      run_gate 3 "$((iteration + 1))" "$current_task_id" || tier3_result=$?

      if [[ $tier3_result -eq 3 ]]; then
        log_iteration 3 false "infrastructure" "infrastructure_halt" 0 "$commit_hash" "$((iteration + 1))" "$current_task_id"
        end_loop "Infrastructure failure during Tier 3. Check ralph/state.json gateConfig."
      fi

      if [[ $tier3_result -eq 0 ]]; then
        # All done, Tier 3 passed
        log_iteration 3 true "none" "complete" 0 "$commit_hash" "$((iteration + 1))" "$current_task_id"
        end_loop "All tasks complete. Tier 3 passed. Build successful!"
      else
        # Tier 3 failed: create cleanup task
        log_iteration 3 false "code" "tier3_fail" 0 "$commit_hash" "$((iteration + 1))" "$current_task_id"

        # Create a cleanup task
        local cleanup_id="CLEANUP.1"
        local existing_cleanup
        existing_cleanup=$(jq '[.tasks[] | select(.id | startswith("CLEANUP"))] | length' "$RALPH_STATE_FILE")
        if [[ $existing_cleanup -gt 0 ]]; then
          cleanup_id="CLEANUP.$((existing_cleanup + 1))"
        fi

        write_state --arg cid "$cleanup_id" \
          '.tasks += [{
            id: $cid,
            description: "Fix Tier 3 final quality gate failures",
            spec: "",
            acceptance: "All Tier 3 gates pass",
            status: "pending",
            dependencies: [],
            attempts: 0,
            parentId: null
          }] | .currentTaskId = $cid | .taskIteration = 1'

        assemble_current_task "$cleanup_id"
        update_frontmatter_iteration "$((ITERATION + 1))"

        local prompt="Continue building. Tier 3 final quality gate FAILED.

Read @ralph/current-task.md for your assignment.
Read @AGENTS.md for build/test/lint commands.
Read @ralph/last-gate-result.json for the specific failures to fix.

Fix all remaining quality issues to pass the final gate."

        local sys_msg="Ralph v2 iteration $((iteration + 1)) [BUILD] | Task: $cleanup_id | Gate: Tier 3 FAILED"
        block_exit "$prompt" "$sys_msg"
        exit 0
      fi
    fi
  else
    # ── Tier 2 failed: create fix task ──
    local fix_id
    if fix_id=$(create_fix_task "$current_task_id"); then
      log_iteration 2 false "code" "fix_task_created" 0 "$commit_hash" "$((iteration + 1))" "$current_task_id"
      assemble_current_task "$fix_id"
      update_frontmatter_iteration "$((ITERATION + 1))"

      local prompt="Continue building. Tier 1 passed but Tier 2 FAILED. A fix task has been created.

Read @ralph/current-task.md for your assignment (fix task $fix_id).
Read @AGENTS.md for build/test/lint commands.
Read @ralph/last-gate-result.json for the specific test failures to fix.

Fix the test failures. Do not change unrelated code."

      local sys_msg="Ralph v2 iteration $((iteration + 1)) [BUILD] | Task: $fix_id | Gate: Tier 2 FAILED — fix task created"
      block_exit "$prompt" "$sys_msg"
      exit 0
    else
      # create_fix_task returns 1 on escalation (writes escalation file internally)
      log_iteration 2 false "code" "fix_limit_escalation" 0 "$commit_hash" "$((iteration + 1))" "$current_task_id"
      end_loop "Fix task limit exceeded for $current_task_id. See $RALPH_ESCALATION"
    fi
  fi
}

# ============================================================
# V1 BEHAVIOR (plan mode, non-v2 build)
# ============================================================

handle_v1() {
  # Extract last assistant output from transcript
  local TRANSCRIPT_PATH
  TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')
  [[ -f "$TRANSCRIPT_PATH" ]] || end_loop "Transcript file not found"

  local LAST_LINES
  LAST_LINES=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -n 100)
  [[ -n "$LAST_LINES" ]] || end_loop "No assistant messages in transcript"

  set +e
  local LAST_OUTPUT
  LAST_OUTPUT=$(echo "$LAST_LINES" | jq -rs '
    map(.message.content[]? | select(.type == "text") | .text) | last // ""
  ' 2>&1)
  local JQ_EXIT=$?
  set -e

  [[ $JQ_EXIT -eq 0 ]] || end_loop "Failed to parse transcript JSON"

  # Check for completion promise
  if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
    # Extract last <promise> tag and normalize whitespace (trim + collapse internal runs)
    local PROMISE_TEXT
    PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
    # Normalize the expected promise too (trim + collapse whitespace)
    local COMPLETION_PROMISE_NORMALIZED
    COMPLETION_PROMISE_NORMALIZED=$(printf '%s' "$COMPLETION_PROMISE" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g')
    if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE_NORMALIZED" ]]; then
      end_loop "Completion promise detected. Mode: $MODE"
    fi
  fi

  # Continue loop - update iteration counter
  local NEXT_ITERATION=$((ITERATION + 1))

  local PROMPT_TEXT
  PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$RALPH_LOCAL_STATE")
  [[ -n "$PROMPT_TEXT" ]] || end_loop "No prompt found in state file"

  update_frontmatter_iteration "$NEXT_ITERATION"

  # Build system message
  local MODE_UPPER
  MODE_UPPER=$(echo "$MODE" | tr '[:lower:]' '[:upper:]')
  local SYSTEM_MSG
  if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
    SYSTEM_MSG="Ralph Wiggum iteration $NEXT_ITERATION [$MODE_UPPER] | To stop: output <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE)"
  else
    SYSTEM_MSG="Ralph Wiggum iteration $NEXT_ITERATION [$MODE_UPPER] | No completion promise set"
  fi

  block_exit "$PROMPT_TEXT" "$SYSTEM_MSG"
}

# ============================================================
# MAIN DISPATCH
# ============================================================

# V2 build mode: state.json exists with v2 structure and mode is build
if [[ "$MODE" == "build" ]] && [[ -f "$RALPH_STATE_FILE" ]]; then
  if jq -e '.currentTaskId and .gateConfig' "$RALPH_STATE_FILE" >/dev/null 2>&1; then
    handle_v2_build
  else
    handle_v1
  fi
else
  handle_v1
fi
