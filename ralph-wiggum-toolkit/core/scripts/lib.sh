#!/bin/bash
# Ralph Wiggum Toolkit v2 — Shared library
# Source this file from loop.sh, stop-hook.sh, and setup-loop.sh
#
# All consumers must set these before sourcing:
#   RALPH_STATE_FILE  (default: ralph/state.json)
#   RALPH_GATE_RESULT (default: ralph/last-gate-result.json)
#   RALPH_CURRENT_TASK (default: ralph/current-task.md)
#   RALPH_CHANGED_FILES (default: ralph/changed-files.txt)
#   RALPH_JOURNAL (default: ralph/iteration-journal.jsonl)
#   RALPH_ESCALATION (default: ralph/escalation.md)

# Defaults (consumers can override before sourcing)
: "${RALPH_STATE_FILE:=ralph/state.json}"
: "${RALPH_GATE_RESULT:=ralph/last-gate-result.json}"
: "${RALPH_CURRENT_TASK:=ralph/current-task.md}"
: "${RALPH_CHANGED_FILES:=ralph/changed-files.txt}"
: "${RALPH_JOURNAL:=ralph/iteration-journal.jsonl}"
: "${RALPH_ESCALATION:=ralph/escalation.md}"

# Cache VCS type (read once, never changes during a run)
_RALPH_VCS=""
_ralph_vcs() {
  if [[ -z "$_RALPH_VCS" ]]; then
    _RALPH_VCS=$(jq -r '.vcs // "git"' "$RALPH_STATE_FILE" 2>/dev/null || echo "git")
  fi
  echo "$_RALPH_VCS"
}

# ============================================================
# STATE HELPERS
# ============================================================
read_state() {
  jq -r "$1" "$RALPH_STATE_FILE"
}

write_state() {
  # Usage: write_state [--arg k v | --argjson k v ...] 'filter'
  # All arguments passed directly to jq.
  local tmp
  tmp=$(mktemp)
  jq "$@" "$RALPH_STATE_FILE" > "$tmp" && mv "$tmp" "$RALPH_STATE_FILE"
}

# ============================================================
# CONTEXT ASSEMBLY
# ============================================================
assemble_current_task() {
  local task_id=$1

  # Extract all task fields + state metadata in one jq call
  local task_data
  task_data=$(jq -r --arg tid "$task_id" '
    (.tasks[] | select(.id == $tid)) as $t |
    if $t then
      [$t.id, $t.description, ($t.acceptance // "See spec"),
       ($t.spec // ""), ($t.parentId // ""),
       .taskIteration, .maxTaskIterations,
       ([$t.dependencies[]?] | join(","))] | @tsv
    else "NOT_FOUND" end
  ' "$RALPH_STATE_FILE")

  if [[ "$task_data" == "NOT_FOUND" ]]; then
    echo "Error: Task '$task_id' not found in state.json" >&2
    return 1
  fi

  local id desc acceptance spec_file parent_id task_iter max_task_iter deps_csv
  IFS=$'\t' read -r id desc acceptance spec_file parent_id task_iter max_task_iter deps_csv <<< "$task_data"

  {
    echo "# Current Task"
    echo ""
    echo "**ID:** $id"
    echo "**Description:** $desc"
    echo "**Acceptance:** $acceptance"
    echo "**Attempt:** $task_iter of $max_task_iter"
    echo ""

    if [[ -n "$spec_file" ]] && [[ -f "$spec_file" ]]; then
      echo "## Spec"
      echo ""
      cat "$spec_file"
      echo ""
    fi

    if [[ -n "$deps_csv" ]]; then
      echo "## Dependencies"
      echo ""
      echo "$deps_csv" | tr ',' '\n'
      echo ""
    fi

    if [[ -n "$parent_id" ]]; then
      echo "## Fix Context"
      echo ""
      echo "This is a fix task for $parent_id. The quality gate failures that need fixing:"
      echo ""
      if [[ -f "$RALPH_GATE_RESULT" ]]; then
        jq -r '.results[] | select(.exitCode != 0) | "### \(.command)\n\(.output)\n"' "$RALPH_GATE_RESULT"
      fi
    fi
  } > "$RALPH_CURRENT_TASK"
}

# ============================================================
# CHANGED FILE DETECTION
# ============================================================
detect_changed_files() {
  {
    git diff --name-only HEAD 2>/dev/null
    git diff --cached --name-only 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | sort -u > "$RALPH_CHANGED_FILES"
}

# ============================================================
# QUALITY GATE RUNNER
# ============================================================
run_gate() {
  local tier=$1
  local iteration=${2:-$(read_state '.iteration')}
  local task_id=${3:-$(read_state '.currentTaskId')}

  # Read commands + timeout in one jq call
  local gate_data
  gate_data=$(jq -r --argjson t "$tier" '
    (.gateConfig["tier\($t)"].commands | join("\n")) + "\t" +
    ((.gateConfig["tier\($t)"].timeout // 120) | tostring)
  ' "$RALPH_STATE_FILE")

  local commands timeout_val
  IFS=$'\t' read -r commands timeout_val <<< "$gate_data"

  local changed_files=""
  [[ -f "$RALPH_CHANGED_FILES" ]] && changed_files=$(tr '\n' ' ' < "$RALPH_CHANGED_FILES")

  # Accumulate results in a temp file (one jq call per command, not per-append)
  local tmp_results
  tmp_results=$(mktemp)
  local all_passed=true

  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue

    cmd="${cmd//\{changed_files\}/$changed_files}"

    local output exit_code=0
    output=$(timeout "$timeout_val" bash -c "$cmd" 2>&1) || exit_code=$?

    # Infrastructure failure detection
    if [[ $exit_code -eq 126 ]] || [[ $exit_code -eq 127 ]]; then
      echo "INFRASTRUCTURE FAILURE: $cmd (exit $exit_code)" >&2
      jq -n --arg cmd "$cmd" --arg out "$output" --argjson code "$exit_code" \
        --argjson iter "$iteration" --arg tid "$task_id" --argjson t "$tier" \
        '{iteration: $iter, taskId: $tid, tier: $t, passed: false,
          failureType: "infrastructure",
          results: [{command: $cmd, exitCode: $code, output: $out}]}' \
        > "$RALPH_GATE_RESULT"
      rm -f "$tmp_results"
      return 3
    fi

    local truncated="false"
    if [[ ${#output} -gt 4096 ]]; then
      output="${output:0:4096}... (truncated)"
      truncated="true"
    fi

    jq -n -c --arg cmd "$cmd" --argjson code "$exit_code" \
      --arg out "$output" --argjson trunc "$truncated" \
      '{command: $cmd, exitCode: $code, output: $out, truncated: $trunc}' \
      >> "$tmp_results"

    [[ $exit_code -ne 0 ]] && all_passed=false
  done <<< "$commands"

  local failure_type="code"
  $all_passed && failure_type="none"

  local results
  results=$(jq -s '.' "$tmp_results")
  rm -f "$tmp_results"

  jq -n --argjson iter "$iteration" --arg tid "$task_id" --argjson t "$tier" \
    --argjson passed "$all_passed" --arg ft "$failure_type" --argjson res "$results" \
    '{iteration: $iter, taskId: $tid, tier: $t, passed: $passed,
      failureType: $ft, results: $res}' \
    > "$RALPH_GATE_RESULT"

  $all_passed && return 0 || return 1
}

# ============================================================
# VCS OPERATIONS
# ============================================================
vcs_commit() {
  local message=$1
  if [[ "$(_ralph_vcs)" == "jj" ]]; then
    jj describe -m "$message"
    jj new
  else
    if [[ -s "$RALPH_CHANGED_FILES" ]]; then
      xargs git add -- < "$RALPH_CHANGED_FILES" 2>/dev/null || true
      git commit -m "$message" 2>/dev/null || true
    fi
  fi
}

vcs_push() {
  local branch=${1:-}
  if [[ "$(_ralph_vcs)" == "jj" ]]; then
    jj git push 2>/dev/null || true
  else
    if [[ -n "$branch" ]]; then
      git push origin "$branch" 2>/dev/null || {
        git push -u origin "$branch" 2>/dev/null || true
      }
    fi
  fi
}

tag_iteration() {
  local iter=$1
  local tag="ralph/iter-$(printf '%03d' "$iter")"
  if [[ "$(_ralph_vcs)" == "jj" ]]; then
    jj bookmark set "$tag" 2>/dev/null || true
  else
    git tag "$tag" 2>/dev/null || true
  fi
}

# ============================================================
# CYCLE DETECTION
# ============================================================
write_escalation() {
  local task_id=$1
  local signature=$2
  local consecutive=$3

  local task_desc
  task_desc=$(jq -r --arg tid "$task_id" '.tasks[] | select(.id == $tid) | .description' "$RALPH_STATE_FILE")

  {
    echo "# Escalation: Cycle Detected"
    echo ""
    echo "**Task:** $task_id — $task_desc"
    echo "**Cycle threshold:** $consecutive consecutive identical failures"
    echo "**Failure signature:** $signature"
    echo ""
    echo "## Failure History"
    echo ""
    jq -r --arg tid "$task_id" '
      [.gateHistory[] | select(.taskId == $tid)] | reverse | .[0:10] |
      .[] | "- \(.timestamp): \(.signature)"
    ' "$RALPH_STATE_FILE"
    echo ""
    echo "## Last Gate Result"
    echo ""
    if [[ -f "$RALPH_GATE_RESULT" ]]; then
      jq -r '.results[] | select(.exitCode != 0) |
        "### \(.command) (exit \(.exitCode))\n```\n\(.output)\n```\n"' "$RALPH_GATE_RESULT"
    fi
    echo ""
    echo "## Recommended Actions"
    echo ""
    echo "1. Review the failure output above"
    echo "2. Adjust the spec, plan, or approach"
    echo "3. Restart the loop: ./loop.sh build"
  } > "$RALPH_ESCALATION"
}

check_cycle() {
  local task_id=$1

  local threshold
  threshold=$(read_state '.cycleThreshold // 3')

  # Build failure signature from last gate result
  if [[ ! -f "$RALPH_GATE_RESULT" ]]; then
    return 0
  fi

  local current_sig
  current_sig=$(jq -r '
    [.results[] | select(.exitCode != 0) |
      .command + ":" + (.exitCode | tostring) + ":" + (.output | split("\n")[0] // "")]
    | join("|")' "$RALPH_GATE_RESULT")

  [[ -z "$current_sig" ]] && return 0

  # Append signature to gate history
  write_state --arg sig "$current_sig" --arg tid "$task_id" \
    '.gateHistory += [{taskId: $tid, signature: $sig, timestamp: (now | todate)}]'

  # Count consecutive identical signatures for this task from tail
  local consecutive
  consecutive=$(jq --arg sig "$current_sig" --arg tid "$task_id" '
    [.gateHistory[] | select(.taskId == $tid) | .signature] | reverse |
    . as $sigs |
    reduce range(length) as $i (0;
      if $i == . and ($sigs[$i] == $sig) then . + 1 else . end
    )
  ' "$RALPH_STATE_FILE")

  if [[ $consecutive -ge $threshold ]]; then
    write_escalation "$task_id" "$current_sig" "$consecutive"
    echo "CYCLE DETECTED: Same failure $consecutive times for task $task_id" >&2
    echo "See $RALPH_ESCALATION for details" >&2
    return 1
  fi

  return 0
}

# ============================================================
# FIX TASK CREATION
# ============================================================
create_fix_task() {
  local parent_id=$1
  local tier=${2:-2}

  # Count existing fix tasks for root task (transitive: T003 -> T003.1 -> T003.2)
  local root_id
  root_id=$(echo "$parent_id" | cut -d'.' -f1)

  # Read fix count and max in one call
  local fix_data
  fix_data=$(jq -r --arg root "$root_id" '
    [([.tasks[] | select(.id | startswith($root + "."))] | length),
     (.maxFixTasksPerOriginal // 3)] | @tsv
  ' "$RALPH_STATE_FILE")

  local fix_count max_fix
  IFS=$'\t' read -r fix_count max_fix <<< "$fix_data"

  if [[ $fix_count -ge $max_fix ]]; then
    local task_desc
    task_desc=$(jq -r --arg pid "$parent_id" '.tasks[] | select(.id == $pid) | .description' "$RALPH_STATE_FILE")

    {
      echo "# Escalation: Fix Task Limit Exceeded"
      echo ""
      echo "**Original task:** $root_id"
      echo "**Fix tasks created:** $fix_count (limit: $max_fix)"
      echo "**Last parent:** $parent_id — $task_desc"
      echo ""
      echo "## Last Gate Result"
      echo ""
      if [[ -f "$RALPH_GATE_RESULT" ]]; then
        jq -r '.results[] | select(.exitCode != 0) |
          "### \(.command) (exit \(.exitCode))\n```\n\(.output)\n```\n"' "$RALPH_GATE_RESULT"
      fi
      echo ""
      echo "## Recommended Actions"
      echo ""
      echo "1. Review the accumulated fix attempts"
      echo "2. Reconsider the approach for $root_id"
      echo "3. Adjust the spec or plan, then restart"
    } > "$RALPH_ESCALATION"

    echo "FIX TASK LIMIT: $fix_count fix tasks for $root_id (max $max_fix)" >&2
    echo "See $RALPH_ESCALATION for details" >&2
    return 1
  fi

  local fix_id="${root_id}.$((fix_count + 1))"

  # Read parent desc + spec in one call
  local parent_data
  parent_data=$(jq -r --arg pid "$parent_id" '
    .tasks[] | select(.id == $pid) | [.description, (.spec // "")] | @tsv
  ' "$RALPH_STATE_FILE")

  local parent_desc parent_spec
  IFS=$'\t' read -r parent_desc parent_spec <<< "$parent_data"

  write_state --arg fid "$fix_id" --arg pid "$parent_id" \
    --arg desc "Fix Tier $tier failures for $parent_id" \
    --arg spec "$parent_spec" \
    --arg acc "All Tier $tier quality gates pass" \
    '.tasks += [{
      id: $fid, description: $desc, spec: $spec, acceptance: $acc,
      status: "pending", dependencies: [], attempts: 0, parentId: $pid
    }] | .currentTaskId = $fid | .taskIteration = 1'

  echo "Created fix task $fix_id for $parent_id" >&2
  echo "$fix_id"
  return 0
}

# ============================================================
# TASK ADVANCEMENT
# ============================================================
advance_task() {
  local current_id=${1:-$(read_state '.currentTaskId')}

  write_state --arg tid "$current_id" \
    '(.tasks[] | select(.id == $tid)).status = "done"'

  # Find next pending or in-progress task
  local next_id
  next_id=$(jq -r '[.tasks[] | select(.status == "pending" or .status == "in-progress")] | .[0].id // "DONE"' "$RALPH_STATE_FILE")

  if [[ "$next_id" == "DONE" ]]; then
    return 1
  fi

  write_state --arg nid "$next_id" \
    '.currentTaskId = $nid | .taskIteration = 1'

  echo "Advanced to task $next_id" >&2
  return 0
}

# ============================================================
# ITERATION JOURNAL
# ============================================================
log_iteration() {
  local tier=$1
  local passed=$2
  local failure_type=$3
  local exit_reason=$4
  local duration_ms=${5:-0}
  local commit_sha=${6:-""}
  local iteration=${7:-$(read_state '.iteration')}
  local task_id=${8:-$(read_state '.currentTaskId')}

  local commits="[]"
  if [[ -n "$commit_sha" ]]; then
    commits=$(jq -n --arg sha "$commit_sha" '[$sha]')
  fi

  local task_iter
  task_iter=$(read_state '.taskIteration')

  jq -n -c \
    --argjson iter "$iteration" \
    --arg tid "$task_id" \
    --argjson taskIter "$task_iter" \
    --argjson tier "$tier" \
    --argjson passed "$passed" \
    --arg ft "$failure_type" \
    --arg reason "$exit_reason" \
    --argjson dur "$duration_ms" \
    --argjson commits "$commits" \
    '{iteration: $iter, taskId: $tid, taskIteration: $taskIter,
      tier: $tier, passed: $passed, failureType: $ft,
      exitReason: $reason, duration_ms: $dur, commits: $commits,
      timestamp: (now | todate)}' \
    >> "$RALPH_JOURNAL"
}
