# Ralph Wiggum Toolkit v2.0 — Architecture Spec

**Date:** 2026-03-20
**Status:** Draft (adversarial-reviewed)
**Author:** George-RD
**Scope:** Redesign the build loop to use external quality gates, JSON state machine, and mechanical enforcement.

---

## Problem Statement

The v1.0 build loop does not enforce the Huntley paradigm. Empirically observed:

1. Claude ignores "choose the most important item" (singular) and batches entire waves
2. PROMPT_build.md contradicts itself: "parallel subagents" vs "choose the most important item"
3. The methodology reference that says "one task per iteration" is never loaded into the loop context
4. The in-session stop hook preserves context across iterations (not fresh context)
5. loop.sh is faithful to Huntley (`while :; do cat PROMPT.md | claude -p; done`) but has no verification, no state tracking, no failure feedback

Root cause: enforcement lives in prompts (suggestions the agent can ignore) rather than in infrastructure (mechanical constraints the agent cannot bypass).

---

## Design Principle

**The loop owns enforcement. The agent just writes code.**

| Responsibility | Owner |
|---------------|-------|
| What task to work on | Loop script (reads state machine) |
| Quality verification | Loop script (runs gates) |
| When to advance | Loop script (Tier 2 gate pass) |
| When to stop | Loop script (all tasks done + Tier 3 pass) |
| Committing | Loop script (commit after gate pass) |
| Task completion detection | Loop script (gate-based, no self-reporting) |
| Writing code | Agent |
| Updating AGENTS.md | Agent |

The agent never decides it is done. The gates decide.

---

## Architecture

### Loop Flow

```text
loop.sh (enhanced)
  │
  ├─ 1. Read state: ralph/state.json
  │     → currentTaskId, iteration count, gate history
  │
  ├─ 2. Assemble context
  │     → ralph/current-task.md (composite: task metadata + full spec content + attempt count)
  │     → ralph/last-gate-result.json (failures from previous iteration, if any)
  │
  ├─ 3. Run agent
  │     → claude -p --model $MODEL < PROMPT_build.md
  │     → Agent reads current-task.md, AGENTS.md, last-gate-result.json
  │     → Agent writes code, updates AGENTS.md
  │     → Agent exits (naturally or token limit)
  │
  ├─ 4. Detect changed files
  │     → Union of: git diff --name-only HEAD, git diff --cached --name-only,
  │       git ls-files --others --exclude-standard
  │     → Store as ralph/changed-files.txt
  │
  ├─ 5. Run Tier 1 quality gate
  │     → Compile + fast lint (scoped to changed files where possible)
  │     → Classify exit codes: 126/127 = infrastructure failure → halt immediately
  │     → Write results to ralph/last-gate-result.json with failureType field
  │
  ├─ 6. Log iteration
  │     → Append to ralph/iteration-journal.jsonl
  │     → VCS tag: git tag ralph/iter-NNN or jj bookmark set ralph/iter-NNN
  │
  ├─ 7. Evaluate
  │     → Infrastructure failure? EXIT loop (code 3, fix toolchain)
  │     → Tier 1 failed? Check for cycles → loop back to step 1
  │     → Tier 1 passed? Commit, then always attempt Tier 2
  │       → Tier 2 passed? Advance to next task
  │       → Tier 2 failed? Create fix task, loop back
  │     → All tasks done? Run Tier 3
  │       → Tier 3 passed? EXIT loop (code 0, success)
  │       → Tier 3 failed? Create final cleanup task, loop back
  │     → Max iterations reached? EXIT loop (code 1, safety)
  │     → Cycle detected (same failure 3x)? EXIT loop (code 2, escalate)
  │
  └─ 8. VCS commit + push (only after Tier 1 pass)
        → Stage changed files (scoped, not git add -A)
        → Commit: "ralph: $TASK_ID iteration $N"
        → Push: git push origin $BRANCH || true
```

**Key change from draft:** Tier 2 runs after every Tier-1-passing iteration. The agent never self-reports completion. If Tier 2 passes, the task IS done by definition. If Tier 2 fails, the loop creates a fix task with the specific test failures.

### State Machine: `ralph/state.json`

```json
{
  "version": "2.0.0",
  "recipe": "greenfield",
  "model": "opus",
  "vcs": "git",
  "currentTaskId": "T001",
  "iteration": 0,
  "maxIterations": 100,
  "taskIteration": 1,
  "maxTaskIterations": 5,
  "maxFixTasksPerOriginal": 3,
  "phase": "build",
  "awaitingApproval": false,
  "tasks": [
    {
      "id": "T001",
      "description": "Implement hero section per spec",
      "spec": "specs/hero-subhead.md",
      "acceptance": "Hero renders with headline, subhead, CTA button",
      "status": "pending",
      "dependencies": [],
      "attempts": 0,
      "parentId": null
    }
  ],
  "gateConfig": {
    "tier1": {
      "commands": ["npx tsc --noEmit", "npx eslint --cache {changed_files}"],
      "timeout": 30
    },
    "tier2": {
      "commands": ["npx tsc --noEmit", "npx eslint .", "npx vitest --related {changed_files}"],
      "timeout": 120
    },
    "tier3": {
      "commands": ["npx tsc --noEmit --strict", "npx eslint . --max-warnings 0", "npx vitest"],
      "timeout": 300
    }
  },
  "allowlist": [],
  "gateHistory": [],
  "cycleThreshold": 3
}
```

**Key changes from draft:**

- `currentTaskId` replaces `taskIndex`. Tasks are found by ID, not array position. Fix tasks append to the array without corrupting the cursor.
- `parentId` on tasks enables fix task lineage (T003.1 has parentId: "T003").
- `acceptance` field per task for structured completion criteria.
- `{changed_files}` placeholder in gate commands, expanded by the gate runner.
- `vcs` field for git/JJ detection.
- `awaitingApproval` for phase gates.

### Tiered Quality Gates

| Tier | When | Scope | Strictness | Timeout |
|------|------|-------|-----------|---------|
| 1 | Every iteration | Changed files + project-wide type check | Relaxed (suppress unused declarations) | 30s |
| 2 | Every Tier-1-passing iteration | Full project, affected test suites | Strict | 2min |
| 3 | All tasks complete | Full project, all tests, warnings-as-errors | Strictest | 5min |

**Note on Tier 1 scope:** Type checkers (tsc, cargo check, go vet) always run project-wide because deletions/renames in changed files can break unchanged files with dangling imports. Linters scope to changed files for speed.

Gate commands are configured per-project during `ralph init`. Defaults by language:

| Language | Tier 1 | Tier 2 | Tier 3 |
|----------|--------|--------|--------|
| TypeScript | `tsc --noEmit` + eslint changed | `tsc --noEmit` + eslint all + vitest related | `tsc --noEmit --strict` + eslint `--max-warnings 0` + vitest |
| Python | `ruff check --select=E` changed | `ruff check` + mypy + pytest related | `ruff check --strict` + mypy --strict + pytest |
| Go | `go vet ./...` | `go vet` + staticcheck + `go test` related | `go vet` + staticcheck strict + `go test ./...` + `go build ./...` |
| Rust | `cargo check` | `cargo clippy` + `cargo test` related | `cargo clippy -- -D warnings` + `cargo test` |

### Gate Runner

The gate runner must handle:

1. **Changed file detection:** Union of tracked-modified, staged, and untracked files.
2. **Placeholder expansion:** `{changed_files}` in gate commands gets replaced with the file list.
3. **Infrastructure vs code failure:** Exit codes 126 (permission denied) and 127 (command not found) are infrastructure failures. The gate runner halts immediately with a clear message instead of wasting iterations.
4. **Output capture:** stdout + stderr captured per command. Truncated to 4KB if larger (prevents bloated failure logs).

```bash
run_gate() {
  local tier=$1
  local commands
  commands=$(jq -r ".gateConfig.tier${tier}.commands[]" "$STATE_FILE")
  local timeout
  timeout=$(jq -r ".gateConfig.tier${tier}.timeout // 120" "$STATE_FILE")
  local changed_files
  changed_files=$(cat ralph/changed-files.txt | tr '\n' ' ')

  local results="[]"
  local all_passed=true

  while IFS= read -r cmd; do
    # Expand {changed_files} placeholder
    cmd="${cmd//\{changed_files\}/$changed_files}"

    local output exit_code
    output=$(timeout "$timeout" bash -c "$cmd" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    # Infrastructure failure detection
    if [[ $exit_code -eq 126 ]] || [[ $exit_code -eq 127 ]]; then
      echo "INFRASTRUCTURE FAILURE: $cmd (exit $exit_code)" >&2
      echo "$output" >&2
      jq -n --arg cmd "$cmd" --arg out "$output" --argjson code "$exit_code" \
        '{iteration: $ENV.ITERATION, taskId: $ENV.TASK_ID, tier: '$tier',
          passed: false, failureType: "infrastructure",
          results: [{command: $cmd, exitCode: $code, output: $out}]}' \
        > "$GATE_RESULT"
      exit 3  # Infrastructure failure exit code
    fi

    local truncated=false
    if [[ ${#output} -gt 4096 ]]; then
      output="${output:0:4096}... (truncated)"
      truncated=true
    fi

    results=$(echo "$results" | jq --arg cmd "$cmd" --argjson code "$exit_code" \
      --arg out "$output" --argjson trunc "$truncated" \
      '. + [{command: $cmd, exitCode: $code, output: $out, truncated: $trunc}]')

    [[ $exit_code -ne 0 ]] && all_passed=false
  done <<< "$commands"

  local failure_type="code"
  $all_passed && failure_type="none"

  jq -n --argjson iter "$ITERATION" --arg tid "$TASK_ID" --argjson tier "$tier" \
    --argjson passed "$all_passed" --arg ft "$failure_type" --argjson res "$results" \
    '{iteration: $iter, taskId: $tid, tier: $tier, passed: $passed,
      failureType: $ft, results: $res}' \
    > "$GATE_RESULT"

  $all_passed && return 0 || return 1
}
```

### Failure Log: `ralph/last-gate-result.json`

Overwritten each iteration:

```json
{
  "iteration": 7,
  "taskId": "T003",
  "tier": 1,
  "passed": false,
  "failureType": "code",
  "results": [
    {
      "command": "npx tsc --noEmit",
      "exitCode": 2,
      "output": "src/auth.ts(47,5): error TS2322: Type 'string' is not assignable...",
      "truncated": false
    }
  ]
}
```

`failureType` is one of: `"none"`, `"code"`, `"infrastructure"`.

### current-task.md Assembly

The loop script builds `ralph/current-task.md` as a composite document. The agent reads one file and has everything it needs.

```bash
assemble_current_task() {
  local task_id=$1
  local task
  task=$(jq ".tasks[] | select(.id == \"$task_id\")" "$STATE_FILE")
  local spec_file
  spec_file=$(echo "$task" | jq -r '.spec')

  {
    echo "# Current Task"
    echo ""
    echo "**ID:** $(echo "$task" | jq -r '.id')"
    echo "**Description:** $(echo "$task" | jq -r '.description')"
    echo "**Acceptance:** $(echo "$task" | jq -r '.acceptance // "See spec"')"
    echo "**Attempt:** $(read_state '.taskIteration') of $(read_state '.maxTaskIterations')"
    echo ""

    # Inline full spec content
    if [[ -n "$spec_file" ]] && [[ -f "$spec_file" ]]; then
      echo "## Spec"
      echo ""
      cat "$spec_file"
      echo ""
    fi

    # Inline dependencies
    local deps
    deps=$(echo "$task" | jq -r '.dependencies[]? // empty')
    if [[ -n "$deps" ]]; then
      echo "## Dependencies"
      echo ""
      echo "$deps"
      echo ""
    fi

    # If this is a fix task, include parent context
    local parent_id
    parent_id=$(echo "$task" | jq -r '.parentId // empty')
    if [[ -n "$parent_id" ]]; then
      echo "## Fix Context"
      echo ""
      echo "This is a fix task for $parent_id. The quality gate failures that need fixing:"
      echo ""
      if [[ -f "$GATE_RESULT" ]]; then
        jq -r '.results[] | select(.exitCode != 0) | "### \(.command)\n\(.output)\n"' "$GATE_RESULT"
      fi
    fi
  } > ralph/current-task.md
}
```

### Iteration Journal: `ralph/iteration-journal.jsonl`

Append-only. One JSON line per iteration:

```json
{"iteration":7,"taskId":"T003","taskIteration":2,"tier":1,"passed":false,"failureType":"code","exitReason":"gate_fail","duration_ms":45000,"commits":[],"timestamp":"2026-03-20T14:30:00Z"}
{"iteration":8,"taskId":"T003","taskIteration":3,"tier":2,"passed":true,"failureType":"none","exitReason":"task_advance","duration_ms":62000,"commits":["a1b2c3d"],"timestamp":"2026-03-20T14:31:05Z"}
```

### VCS Integration

Detect VCS during init. Store in `state.json` as `"vcs": "git"` or `"vcs": "jj"`.

```bash
vcs_commit() {
  local message=$1
  if [[ "$(read_state '.vcs')" == "jj" ]]; then
    jj describe -m "$message"
    jj new  # Fresh change for next iteration
  else
    # Scoped staging: only changed files, not git add -A
    cat ralph/changed-files.txt | xargs git add --
    git commit -m "$message"
  fi
}

tag_iteration() {
  local iter=$1
  local tag="ralph/iter-$(printf '%03d' "$iter")"
  if [[ "$(read_state '.vcs')" == "jj" ]]; then
    jj bookmark set "$tag"
  else
    git tag "$tag"
  fi
}
```

**JJ-specific gate adjustments:**

| Tier | Git | JJ |
|------|-----|-----|
| Tier 1 | Normal | Skip conflict checks (JJ conflicts are normal WIP state) |
| Tier 2 | Normal | Conflicts must be resolved |
| Tier 3 | Normal | `jj log --no-graph -r 'conflicts()'` must return empty |

### Cycle Detection

Track gate failure signatures (command + exit code + first error line) in `gateHistory`. If the same signature appears `cycleThreshold` (default 3) consecutive times for the same task:

1. Write `ralph/escalation.md` with: task description, failure history, what was attempted
2. Exit loop with code 2 (escalation)
3. User intervenes: adjusts spec, plan, or approach, then restarts loop

### Recovery Mode (Fix Tasks)

When a Tier-1-passing iteration fails Tier 2 (code compiles but tests fail):

1. Create fix task: `T003.1` (dot notation lineage, `parentId: "T003"`)
2. Fix task description: "Fix test failures for T003"
3. Fix task inherits parent's spec + specific Tier 2 failure output
4. Append to tasks array (does not shift indices since we use ID-based cursor)
5. Set `currentTaskId` to the fix task
6. Max `maxFixTasksPerOriginal` (default 3) fix tasks per original
7. After limit: escalate (same as cycle detection)

---

## PROMPT_build.md

Minimal, no contradictions. The loop assembles context; the prompt just says what to do.

```markdown
# Task

Read @ralph/current-task.md for your assignment.
Read @AGENTS.md for build/test/lint commands and operational notes.

# Quality Failures

If @ralph/last-gate-result.json exists and shows failures, fix those FIRST
before continuing with the task.

# Rules

- Implement the task described in current-task.md. Nothing else.
- Implement completely. No stubs, no placeholders, no TODOs.
- Single sources of truth. No duplicate logic across files.
- Search the codebase before assuming something is missing.
- If you find spec inconsistencies, note them in IMPLEMENTATION_PLAN.md.
- Update @AGENTS.md if you learn something operational (build quirks, env setup).
- Do not run tests or linters. The loop infrastructure handles verification.
- Do not commit or push. The loop infrastructure handles VCS operations.
```

18 lines. Three behavioral norms added back (no stubs, single source of truth, flag spec issues) that quality gates cannot mechanically enforce.

---

## Plan Phase Output

The planning agent produces two artifacts:

### 1. IMPLEMENTATION_PLAN.md (human-readable)

Structured markdown with parseable task blocks:

```markdown
# Implementation Plan

## Tasks

### T001: Implement hero section per spec
- **Spec:** specs/hero-subhead.md
- **Dependencies:** none
- **Acceptance:** Hero renders with headline, subhead, CTA button

### T002: Add authentication flow
- **Spec:** specs/auth-flow.md
- **Dependencies:** T001
- **Acceptance:** Login/logout cycle works end-to-end
```

### 2. ralph/tasks.json (machine-readable)

```json
[
  {
    "id": "T001",
    "description": "Implement hero section per spec",
    "spec": "specs/hero-subhead.md",
    "acceptance": "Hero renders with headline, subhead, CTA button",
    "dependencies": []
  },
  {
    "id": "T002",
    "description": "Add authentication flow",
    "spec": "specs/auth-flow.md",
    "acceptance": "Login/logout cycle works end-to-end",
    "dependencies": ["T001"]
  }
]
```

### plan-to-state.sh

Validates `ralph/tasks.json` and merges into `ralph/state.json`:

1. Validate JSON structure (hard error on malformed)
2. Check task count matches IMPLEMENTATION_PLAN.md (warning on mismatch)
3. Merge tasks into state.json, set `currentTaskId` to first task
4. Set `phase: "build"`, `awaitingApproval: true`

This runs at the plan→build phase gate, before any build iteration.

---

## Phase Gates

Adopted from smart-ralph's `awaitingApproval` pattern:

| Transition | Gate | Mechanism |
|-----------|------|-----------|
| spec → plan | User confirms specs are complete | `awaitingApproval: true`, `/ralph` prompts user |
| plan → build | User reviews plan + tasks.json | `awaitingApproval: true`, plan-to-state.sh validates |
| build → done | Tier 3 quality gate passes | Mechanical (no user input needed) |

The `/ralph` smart entry point checks `awaitingApproval` and prompts the user with appropriate options.

---

## In-Session Mode

In-session mode uses the **coordinator-as-delegator pattern** with the stop hook running quality gates.

### Architecture

```text
User runs /ralph build
  → setup-loop.sh writes .claude/ralph-wiggum.local.md
  → Main agent becomes coordinator (delegates, never implements)

Per iteration:
  1. Coordinator reads ralph/state.json for current task
  2. Coordinator delegates to a Task tool subagent with:
     → ralph/current-task.md + AGENTS.md + ralph/last-gate-result.json
  3. Subagent writes code, exits (fresh context boundary)
  4. Stop hook fires:
     a. Detects changed files
     b. Runs Tier 1 gate
     c. If Tier 1 fails: block exit, feed failure context
     d. If Tier 1 passes: commit, run Tier 2
     e. If Tier 2 passes: advance currentTaskId in state.json
     f. If Tier 2 fails: create fix task in state.json
     g. Log to iteration-journal.jsonl
     h. Assemble new current-task.md
     i. Block exit with continuation prompt
```

### Coordinator Prompt (in-session)

```markdown
# Ralph v2 In-Session Build

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
Each subagent gets fresh context. This is intentional.
```

### Differences between modes

| Aspect | loop.sh (headless) | In-session (interactive) |
|--------|-------------------|--------------------------|
| Fresh context | Natural (new `claude -p`) | Forced (Task tool subagent) |
| Gate execution | loop.sh runs gates in bash | Stop hook runs gates in bash |
| User steering | None (autonomous) | User can intervene between iterations |
| State machine | ralph/state.json | ralph/state.json (same) |

---

## Enhanced Init

### Init flow

```text
/ralph init [--recipe greenfield]
  → Detect recipe (greenfield default)
  → Scaffold: specs/, AGENTS.md, IMPLEMENTATION_PLAN.md
  → Detect language from project files (package.json, Cargo.toml, go.mod, etc.)
  → Detect available tools (eslint/biome, ruff/flake8, clippy, etc.)
  → Detect VCS (git/JJ)
  → Configure gate commands per tier with detected defaults
  → Generate ralph/state.json (empty tasks array, populated after plan phase)
  → Copy PROMPT_build.md (v2)
  → Copy loop.sh (v2)
  → Print detected configuration for user verification
```

### Gate Command Discovery

Auto-detect from project files, no interactive prompting:

1. **Language detection:** package.json → TypeScript/JS, Cargo.toml → Rust, go.mod → Go, pyproject.toml → Python
2. **Tool detection:** Check devDependencies (eslint, biome, vitest, jest) or project config files (.eslintrc, ruff.toml, clippy.toml)
3. **Populate defaults** in state.json gateConfig
4. **Print configuration:** Show detected Tier 1/2/3 commands so user can verify
5. **Override:** User edits `ralph/state.json` directly if defaults are wrong

---

## What Does NOT Change

- **Recipe architecture** — greenfield, port, retrospective recipes stay
- **JTBD spec methodology** — user-written specs via `/ralph spec`
- **AGENTS.md** — recipe-specific operational context, kept lean
- **Completion promises** — still available as secondary signal, not primary
- **Port recipe** — citation-backed extraction unchanged
- **Retrospective recipe** — gains iteration-journal.jsonl as structured input

---

## Migration from v1.0

1. `ralph/manifest.json` → merged into `ralph/state.json` (recipe, model, phases kept; tasks array added)
2. `PROMPT_build.md` → replaced with v2 version (18 lines)
3. `loop.sh` → replaced with v2 version (with gate runner, state machine, VCS integration)
4. `.claude/ralph-wiggum.local.md` → still used by stop hooks for in-session mode
5. `IMPLEMENTATION_PLAN.md` → kept as human-readable plan; `ralph/tasks.json` added as machine-readable companion

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success: all tasks complete, Tier 3 passed |
| 1 | Safety: max iterations reached |
| 2 | Escalation: cycle detected or fix task limit exceeded |
| 3 | Infrastructure: gate command not found or broken toolchain |
