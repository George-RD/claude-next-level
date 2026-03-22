#!/bin/bash
# Ralph Wiggum Toolkit v2 — Plan-to-state validator
# Validates ralph/tasks.json and merges into ralph/state.json
#
# Runs at the plan→build phase gate, before any build iteration.
# Expects to be called from the project root directory.

set -euo pipefail

STATE_FILE="ralph/state.json"
TASKS_FILE="ralph/tasks.json"
PLAN_FILE="IMPLEMENTATION_PLAN.md"

# ============================================================
# HELPERS
# ============================================================

die() {
  echo "Error: $1" >&2
  exit 1
}

warn() {
  echo "Warning: $1" >&2
}

# ============================================================
# PRE-FLIGHT CHECKS
# ============================================================

# Require jq
command -v jq >/dev/null 2>&1 || die "jq is required but not installed. Install it with: brew install jq"

# Require tasks.json
[[ -f "$TASKS_FILE" ]] || die "$TASKS_FILE not found. Run /ralph plan first to generate tasks."

# Require state.json
[[ -f "$STATE_FILE" ]] || die "$STATE_FILE not found. Run /ralph init first."

# ============================================================
# STEP 1: Validate tasks.json structure
# ============================================================

# Check that tasks.json is valid JSON
if ! jq empty "$TASKS_FILE" 2>/dev/null; then
  die "$TASKS_FILE is not valid JSON."
fi

# Must be an array
TASKS_TYPE=$(jq -r 'type' "$TASKS_FILE")
if [[ "$TASKS_TYPE" != "array" ]]; then
  die "$TASKS_FILE must be a JSON array, got: $TASKS_TYPE"
fi

# Must have at least one task
TASK_COUNT=$(jq 'length' "$TASKS_FILE")
if [[ "$TASK_COUNT" -eq 0 ]]; then
  die "$TASKS_FILE is empty — at least one task is required."
fi

# Validate each task has required fields and correct types
VALIDATION_ERRORS=$(jq -r '
  [ to_entries[] |
    .key as $idx |
    .value as $task |
    (
      # Required: id (string)
      (if ($task.id | type) != "string" or ($task.id | length) == 0
       then "Task [\($idx)]: missing or invalid \"id\" (must be non-empty string)"
       else empty end),
      # Required: description (string)
      (if ($task.description | type) != "string" or ($task.description | length) == 0
       then "Task [\($idx)]: missing or invalid \"description\" (must be non-empty string)"
       else empty end),
      # id must match T\d+ pattern
      (if ($task.id | type) == "string" and ($task.id | test("^T\\d+$") | not)
       then "Task [\($idx)]: id \"\($task.id)\" does not match required pattern T\\d+ (e.g., T001)"
       else empty end),
      # Optional: spec (must be string if present)
      (if $task | has("spec") then
         if ($task.spec | type) != "string"
         then "Task [\($idx)]: \"spec\" must be a string"
         else empty end
       else empty end),
      # Optional: acceptance (must be string if present)
      (if $task | has("acceptance") then
         if ($task.acceptance | type) != "string"
         then "Task [\($idx)]: \"acceptance\" must be a string"
         else empty end
       else empty end),
      # Optional: dependencies (must be array of strings if present)
      (if $task | has("dependencies") then
         if ($task.dependencies | type) != "array"
         then "Task [\($idx)]: \"dependencies\" must be an array"
         elif ($task.dependencies | map(type) | unique) != ["string"] and ($task.dependencies | length) > 0
         then "Task [\($idx)]: \"dependencies\" must contain only strings"
         else empty end
       else empty end)
    )
  ] | .[]
' "$TASKS_FILE" 2>&1)

if [[ -n "$VALIDATION_ERRORS" ]]; then
  echo "Validation errors in $TASKS_FILE:" >&2
  echo "$VALIDATION_ERRORS" >&2
  exit 1
fi

# Check for duplicate IDs
DUPLICATE_IDS=$(jq -r '
  [.[].id] | group_by(.) | map(select(length > 1) | .[0]) | .[]
' "$TASKS_FILE")

if [[ -n "$DUPLICATE_IDS" ]]; then
  die "Duplicate task IDs found: $DUPLICATE_IDS"
fi

# ============================================================
# STEP 2: Cross-check with IMPLEMENTATION_PLAN.md
# ============================================================

if [[ -f "$PLAN_FILE" ]]; then
  PLAN_TASK_COUNT=$(grep -cE '^### T[0-9]+' "$PLAN_FILE" 2>/dev/null || echo "0")
  if [[ "$PLAN_TASK_COUNT" -ne "$TASK_COUNT" ]]; then
    warn "$PLAN_FILE has $PLAN_TASK_COUNT task blocks (### T\\d+) but $TASKS_FILE has $TASK_COUNT tasks."
  fi
else
  warn "$PLAN_FILE not found — skipping cross-check."
fi

# ============================================================
# STEP 3: Merge tasks into state.json
# ============================================================

# Validate state.json is valid JSON
if ! jq empty "$STATE_FILE" 2>/dev/null; then
  die "$STATE_FILE is not valid JSON."
fi

# Read the first task ID and description for the summary
FIRST_TASK_ID=$(jq -r '.[0].id' "$TASKS_FILE")
FIRST_TASK_DESC=$(jq -r '.[0].description' "$TASKS_FILE")

# Build the merged state:
# - Augment each task with defaults (status, attempts, parentId) if not already set
# - Update top-level state fields for build phase
MERGED=$(jq --slurpfile tasks "$TASKS_FILE" '
  # Augment tasks with defaults
  ($tasks[0] | map(
    . +
    (if has("status") then {} else {status: "pending"} end) +
    (if has("attempts") then {} else {attempts: 0} end) +
    (if has("parentId") then {} else {parentId: null} end)
  )) as $augmented_tasks |

  # Merge into state
  .tasks = $augmented_tasks |
  .currentTaskId = $augmented_tasks[0].id |
  .phase = "build" |
  .awaitingApproval = true |
  .iteration = 0 |
  .taskIteration = 1
' "$STATE_FILE")

# Write the merged state back
echo "$MERGED" | jq '.' > "$STATE_FILE"

# ============================================================
# STEP 4: Output summary
# ============================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Plan → Build transition"
echo ""
echo "Tasks loaded: $TASK_COUNT"
echo "First task: $FIRST_TASK_ID — $FIRST_TASK_DESC"
echo "Phase: build (awaiting approval)"
echo ""
echo "Review ralph/state.json, then run /ralph build to start."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
