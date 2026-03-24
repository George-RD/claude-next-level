---
name: wave
description: "Analyze dependencies, group into waves, dispatch parallel agents with isolated workspaces."
argument-hint: '"issues: 18,12,15,13" or "tasks: description1; description2; ..."'
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
  - LSP
---

# /cos:wave

The power command. Takes a batch of issues or task descriptions, analyzes their dependency graph, detects file overlap, groups them into waves of parallelizable work, and executes each wave with isolated workspaces. Implements merge-as-you-go: as each agent completes, quality gates run, PR is created, and if clean, merged before the next wave starts.

## Usage

```bash
/cos:wave "issues: 18,12,15,13"
/cos:wave "issues: 18,12,15,13 deps: 12->18, 15->18"
/cos:wave "tasks: add auth middleware; refactor user model; update API docs"
```

## Arguments

- `issues: N,N,N,...` — comma-separated GitHub issue numbers
- `tasks: desc1; desc2; desc3` — semicolon-separated task descriptions
- `deps: A->B, C->D` — explicit dependency pairs (A depends on B completing first)
- Mixed format supported: issues + deps in one input

$ARGUMENTS

---

## Workflow

### 1. Parse Input

Extract issues, tasks, and explicit dependencies from the input.

**Parse issue list:**

```bash
# If input contains "issues:", extract comma-separated numbers
ISSUES=$(echo "$ARGUMENTS" | grep -oP 'issues:\s*\K[\d,\s]+' | tr ',' '\n' | xargs)
```

**Parse task list:**

```bash
# If input contains "tasks:", extract semicolon-separated descriptions
TASKS=$(echo "$ARGUMENTS" | grep -oP 'tasks:\s*\K[^$]+' | tr ';' '\n' | xargs -I{} echo "{}")
```

**Parse explicit dependencies:**

```bash
# If input contains "deps:", extract A->B pairs
DEPS=$(echo "$ARGUMENTS" | grep -oP 'deps:\s*\K[^$]+' | grep -oP '\d+->\d+')
```

Dependency format: `A->B` means "A depends on B" (B must complete before A starts).

### 2. Fetch Issue Details

For each issue number, fetch metadata from GitHub:

```bash
gh issue view $N --json number,title,body,labels,milestone
```

**Collect into work items list.** For each valid issue:

```json
{
  "id": "item-<index>",
  "description": "#<N> <title>",
  "type": "implement",
  "issue": N,
  "title": "<title>",
  "body": "<body>",
  "labels": ["<label>", ...],
  "milestone": "<milestone or null>"
}
```

For task descriptions (no issue number):

```json
{
  "id": "item-<index>",
  "description": "<task description>",
  "type": "implement",
  "issue": null,
  "title": "<task description>",
  "body": null,
  "labels": [],
  "milestone": null
}
```

**Validate all issues exist.** Report missing issues and exclude them:

```text
Issue #N not found — excluded from wave plan.
```

If ALL issues are invalid, stop:

```text
No valid issues found. Check issue numbers and try again.
```

### 3. Dependency Analysis

Build the dependency graph in three passes.

**Pass 1: Explicit dependencies** from the `deps:` parameter.

For each `A->B` pair, record: item for issue A depends on item for issue B.

```
adjacency_list[A] = [B, ...]
```

**Pass 2: Implicit dependencies from issue content.**

Scan each issue body for dependency keywords:

```bash
# Check issue bodies for references to other issues in the set
# Keywords: "depends on #N", "blocked by #N", "after #N", "requires #N"
```

Also check GitHub issue links:

```bash
gh api repos/{owner}/{repo}/issues/$N/timeline \
  --jq '[.[] | select(.event == "cross-referenced")] | .[].source.issue.number'
```

If issue A references issue B and both are in the work set, add the dependency.

**Pass 3: File overlap detection.**

For each pair of issues, estimate whether they touch the same files:

```bash
# Search codebase for files mentioned in issue bodies
# Check for module/directory references
# Example: if issue #12 mentions "src/auth" and issue #15 mentions "src/auth/middleware"
```

If overlap is detected between two issues in the same wave:

```text
Issues #12 and #15 both reference `src/auth/`. Run in parallel anyway? (y/n)
```

- If user confirms: allow parallel execution
- If user declines (or no response): add sequential dependency (higher-numbered issue depends on lower)
- Default to sequential if overlap detected and user does not confirm

### 4. Validate the DAG

**Check for cycles:**

Run cycle detection on the adjacency list (DFS-based or Kahn's algorithm).

If cycles are detected:

```text
Dependency cycle detected: #12 -> #18 -> #15 -> #12
Cannot proceed with circular dependencies.
Please remove one dependency to break the cycle, e.g.:
  /cos:wave "issues: 18,12,15 deps: 12->18"
```

Stop and wait for user to provide corrected dependencies.

**Check for self-dependencies:** Remove any `A->A` entries (warn but continue).

**Check for dangling references:** If a dependency references an issue not in the work set, warn and ignore:

```text
Warning: dep 12->99 references #99 which is not in the work set. Ignoring.
```

### 5. Topological Sort into Waves

Sort the validated DAG into waves:

- **Wave 1:** Issues with in-degree 0 (no dependencies in the set)
- **Wave N:** Issues whose ALL dependencies are in waves 1..N-1
- **Within each wave:** Order by estimated complexity (smaller issues first — use label heuristics, body length, or title keywords)
- **Max agents per wave:** 4 (configurable via `~/.chief-of-staff/config.json` `max_parallel_agents`)

If a wave exceeds the max, split it into sub-waves (Wave 1a, 1b) while preserving the property that no item in 1b depends on 1a.

### 6. Display Wave Plan

Present the plan and wait for user confirmation before dispatching:

```text
WAVE PLAN
═══════════════════════════════════════════════════

Wave 1 (parallel):
  #18 - Add rate limiting         [no deps]
  #13 - Fix typo in README        [no deps]

Wave 2 (parallel):
  #12 - Auth middleware            [depends on #18]
  #15 - Update API docs           [depends on #18]

Detected overlap: none
Total waves: 2
Estimated agents: 4

Proceed? (y/n)
```

**If user declines:** Stop. Suggest editing dependencies or reordering:

```text
Wave plan declined. To adjust:
  - Change deps: /cos:wave "issues: 18,12,15,13 deps: 12->18"
  - Remove items: /cos:wave "issues: 18,13"
  - Run individually: /cos:implement "#18"
```

### 7. Initialize Session

Create or update the `/cos` session.

```bash
SESSION_DIR=~/.chief-of-staff/sessions/${SESSION_ID}
mkdir -p "$SESSION_DIR"
```

Write `state.json` following the [canonical schema](../specs/state-schema.md) with all work items, waves, and detected quality gates:

```json
{
  "session_id": "<session-id>",
  "created_at": "<timestamp>",
  "updated_at": "<timestamp>",
  "vcs_type": "<detected>",
  "installed_plugins": [],
  "status": "PLANNING",
  "work_items": [
    {
      "id": "item-1",
      "description": "#18 Add rate limiting",
      "type": "implement",
      "issue": 18,
      "pr_number": null,
      "wave": 1,
      "depends_on": [],
      "agent_id": null,
      "workspace": null,
      "workspace_type": null,
      "branch": "cos/18-add-rate-limiting",
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "result_summary": null,
      "error": null
    }
  ],
  "waves": [
    { "number": 1, "status": "pending", "items": ["item-1", "item-2"], "started_at": null, "completed_at": null },
    { "number": 2, "status": "pending", "items": ["item-3", "item-4"], "started_at": null, "completed_at": null }
  ],
  "agents": {},
  "quality_gates": {},
  "context": { "percentage": 0, "last_checked": "<timestamp>", "checkpoints": [] }
}
```

### 8. Detect VCS Type

Detect once for the entire session:

```bash
if jj root >/dev/null 2>&1; then
  VCS_TYPE="jj"
else
  VCS_TYPE="git"
fi
```

Store in `state.json` `vcs_type`. All workspaces in this session use the same VCS type.

### 9. Read Project Conventions

Gather conventions and quality gate configuration (same as `/cos:implement` Step 6):

```bash
CONVENTIONS=""
[ -f CLAUDE.md ] && CONVENTIONS="$CONVENTIONS\n$(cat CLAUDE.md)"
[ -f AGENTS.md ] && CONVENTIONS="$CONVENTIONS\n$(cat AGENTS.md)"
```

Detect quality gate commands from project config. Update `state.json` `quality_gates`.

---

## Wave Dispatch

### 10. Create Workspaces for Wave N

For each item in the current wave, create an isolated workspace.

**JJ mode:**

```bash
for ITEM_ID in $WAVE_ITEMS; do
  WORKSPACE=~/.chief-of-staff/workspaces/wave-${WAVE_NUM}-item-${ITEM_ID}
  jj workspace add "$WORKSPACE"
  cd "$WORKSPACE"
  jj new main
  jj describe -m "wip: #${ISSUE} ${TITLE}"
done
```

**Git mode:**

Use the Agent tool with `isolation: "worktree"` for each agent dispatch. The SDK manages worktree creation.

Alternatively, for manual worktree management:

```bash
for ITEM_ID in $WAVE_ITEMS; do
  WORKSPACE=~/.chief-of-staff/workspaces/wave-${WAVE_NUM}-item-${ITEM_ID}
  BRANCH=cos/${ISSUE}-${SLUG}
  git worktree add "$WORKSPACE" -b "$BRANCH"
done
```

**If a workspace creation fails for one item:**

- **JJ fails:** Fall back to git worktree for that specific item
- **Git worktree fails:** Report error, exclude item from this wave, mark as `"failed"`
- Continue with remaining items in the wave

Update `state.json` for each item:

```json
{
  "workspace": "~/.chief-of-staff/workspaces/wave-1-item-1",
  "workspace_type": "jj",
  "branch": "cos/18-add-rate-limiting"
}
```

### 11. Dispatch Wave N Agents

For each item in the current wave, fill the implementation prompt template and dispatch an agent. All agents in the same wave are dispatched simultaneously.

**For each item:**

1. Fill `templates/implementation-prompt.md` with item-specific placeholders (same as `/cos:implement` Step 7)
2. Generate branch name (same as `/cos:implement` Step 4)
3. Dispatch:

```
Agent tool call:
  description: "Implement: #<issue> <title, max 50 chars>"
  prompt: <filled implementation-prompt.md>
  subagent_type: "general-purpose"
  mode: "bypassPermissions"
  isolation: "worktree"         # git mode only
  run_in_background: true
```

**All dispatches happen in parallel** with `run_in_background: true`.

**Update `state.json` after each dispatch:**

Work item:

```json
{
  "status": "dispatched",
  "agent_id": "<agent-id>",
  "started_at": "<timestamp>"
}
```

Agent:

```json
{
  "<agent-id>": {
    "name": "implement-<slug>",
    "type": "implement",
    "status": "running",
    "work_item_id": "<item-id>",
    "workspace_path": "<workspace-path>",
    "started_at": "<timestamp>",
    "completed_at": null
  }
}
```

Wave:

```json
{
  "number": N,
  "status": "active",
  "started_at": "<timestamp>"
}
```

Session status: `"MONITORING"`.

**Display dispatch confirmation:**

```text
Wave <N> dispatched (<count> agents):
  #18 - Add rate limiting         [agent: <id>]
  #13 - Fix typo in README        [agent: <id>]

Use /cos:status for live progress.
```

---

## Wave Monitoring and Completion

### 12. Monitor Agent Completions

As each background agent returns, process its output immediately. Do NOT wait for all agents in the wave to finish before processing the first one.

**For each completing agent:**

#### 12a. Parse Implementation Report

Search the agent output for:

```
=== IMPLEMENTATION REPORT ===
...
=== END REPORT ===
```

Extract `Status:` field (`COMPLETE`, `PARTIAL`, `BLOCKED`).

#### 12b. Handle Success (Status: COMPLETE)

Verify quality gates from the report (check for any `FAIL` entries).

**Create PR:**

**JJ mode:**

```bash
cd <workspace-path>
jj bookmark set cos/<issue>-<slug> -r @-
jj git push --bookmark cos/<issue>-<slug> --allow-new
gh pr create --head cos/<issue>-<slug> \
  --title "<issue title>" \
  --body "$(cat <<'EOF'
## Summary

<auto-generated from implementation report>

Closes #<issue-number>

## Quality Gates

- [x] Build passes
- [x] Tests pass
- [x] Lint clean

Automated by chief-of-staff (wave <N>)
EOF
)"
```

**Git mode:**

```bash
git push -u origin cos/<issue>-<slug>
gh pr create --head cos/<issue>-<slug> \
  --title "<issue title>" \
  --body "<same format>"
```

Update `state.json`: `pr_number: <N>`.

#### 12c. Merge Immediately (merge-as-you-go)

```bash
# Wait for CI (max 10 minutes)
gh pr checks <pr-number> --watch --fail-fast

# If CI passes, merge
gh pr merge <pr-number> --squash --delete-branch
```

If merge succeeds:

- Update work item: `status: "complete"`, `completed_at`, `result_summary`
- Update agent: `status: "complete"`, `completed_at`

If merge fails (conflict, branch protection):

- Attempt rebase:

  ```bash
  cd <workspace-path>
  git fetch origin main && git rebase origin/main
  git push --force-with-lease
  ```

- If rebase succeeds, retry merge
- If rebase fails, mark item as `"failed"` with conflict details, leave PR open

Display per-item completion:

```text
#18 - Add rate limiting: MERGED (PR #56)
```

#### 12d. Handle Failure (Status: PARTIAL, BLOCKED, or missing report)

- Update work item: `status: "failed"`, `error: "<details>"`
- Update agent: `status: "failed"`, `completed_at`
- Check retry budget (max 2 retries, 3 total attempts per item):
  - If retries remain: re-dispatch agent with failure context appended to prompt
  - If exhausted: mark as permanently failed

```text
#15 - Update API docs: FAILED (quality gate: lint)
  Error: eslint found 3 errors in src/docs/api.ts
  Retries remaining: 1
```

### 13. Wave Completion

A wave is complete when ALL items in it have reached a terminal state (`complete` or `failed`).

**Check wave completion after each agent finishes:**

```python
# Pseudocode
wave_items = [item for item in work_items if item.wave == current_wave]
all_terminal = all(item.status in ("complete", "failed") for item in wave_items)
any_succeeded = any(item.status == "complete" for item in wave_items)
all_failed = all(item.status == "failed" for item in wave_items)
```

**Wave status transitions:**

| Condition | Wave status | Action |
|-----------|-------------|--------|
| All items complete or failed, at least one complete | `"complete"` | Proceed to next wave |
| All items failed | `"failed"` | STOP. Do not dispatch next wave. |
| Some items still running | `"active"` | Continue monitoring |

Update wave in `state.json`:

```json
{
  "number": N,
  "status": "complete",
  "completed_at": "<timestamp>"
}
```

**Display wave transition:**

```text
Wave 1 COMPLETE (2/2 merged)
─────────────────────────────
  #18 - Add rate limiting       merged (PR #56)
  #13 - Fix typo in README      merged (PR #57)

Dispatching Wave 2 (2 agents)...
```

If partial failure:

```text
Wave 1 COMPLETE (1/2 merged, 1 failed)
─────────────────────────────
  #18 - Add rate limiting       merged (PR #56)
  #13 - Fix typo in README      FAILED (agent crash)

Warning: item-2 (#13) failed. Downstream items with dependency on #13: none.
Proceeding with Wave 2.
```

If ALL failed:

```text
Wave 1 FAILED (0/2 succeeded)
─────────────────────────────
  #18 - Add rate limiting       FAILED (test failures)
  #13 - Fix typo in README      FAILED (workspace creation)

STOPPING. All items in Wave 1 failed. Cannot proceed to Wave 2.
Review errors above and retry individual items with /cos:implement.
```

### 14. Rebase Downstream Before Next Wave

Before dispatching the next wave, ensure workspaces are on an updated base.

**JJ mode:** Automatic. JJ auto-rebases descendants when the parent change is updated. No action needed if workspaces track main.

**Git mode:**

```bash
# Pull updated main (includes merged PRs from this wave)
git checkout main && git pull

# For each workspace in the next wave (if pre-created):
cd <workspace-path>
git rebase main
```

If rebase fails for an item:

- Mark that item as `"failed"` with conflict details
- Continue dispatching remaining items in the wave

### 15. Dispatch Next Wave

Repeat from Step 10 for Wave N+1:

1. Create workspaces for Wave N+1 items
2. Dispatch agents for all items in Wave N+1
3. Monitor completions
4. Merge-as-you-go
5. On wave completion, transition to Wave N+2 (or finish)

Update session status: `"DISPATCHING"` during workspace creation and agent launch, `"MONITORING"` once all agents in the wave are running.

---

## Final Completion

### 16. All Waves Complete

When the last wave completes (or fails), display the final summary:

```text
ALL WAVES COMPLETE
═══════════════════════════════════════════════════

┌────────┬──────────────────────┬─────────┬───────┐
│ Issue  │ Title                │ PR      │ Status│
├────────┼──────────────────────┼─────────┼───────┤
│ #18    │ Add rate limiting    │ #56     │ merged│
│ #13    │ Fix typo in README   │ #57     │ merged│
│ #12    │ Auth middleware       │ #58     │ merged│
│ #15    │ Update API docs      │ #59     │ merged│
└────────┴──────────────────────┴─────────┴───────┘

4/4 items completed. 4 PRs merged.
Duration: 41 minutes.
```

If there were failures:

```text
WAVES COMPLETE (partial)
═══════════════════════════════════════════════════

┌────────┬──────────────────────┬─────────┬────────┐
│ Issue  │ Title                │ PR      │ Status │
├────────┼──────────────────────┼─────────┼────────┤
│ #18    │ Add rate limiting    │ #56     │ merged │
│ #13    │ Fix typo in README   │ #57     │ merged │
│ #12    │ Auth middleware       │ -       │ FAILED │
│ #15    │ Update API docs      │ #59     │ merged │
└────────┴──────────────────────┴─────────┴────────┘

3/4 items completed. 3 PRs merged. 1 failed.
Failed: #12 Auth middleware — merge conflict on src/auth/middleware.ts
Duration: 41 minutes.
```

Update session status: `"COMPLETE"`.

### 17. Workspace Cleanup

After all waves complete (or on abort):

**JJ mode:**

```bash
# Forget all workspaces from this session
for WORKSPACE in ~/.chief-of-staff/workspaces/wave-*; do
  WORKSPACE_NAME=$(basename "$WORKSPACE")
  jj workspace forget "$WORKSPACE_NAME" 2>/dev/null || true
done
rm -rf ~/.chief-of-staff/workspaces/wave-*
```

**Git mode:**

Agent SDK handles worktree cleanup automatically for `isolation: "worktree"` agents. For any manually created worktrees:

```bash
# Remove worktrees
for WORKSPACE in ~/.chief-of-staff/workspaces/wave-*; do
  git worktree remove "$WORKSPACE" 2>/dev/null || true
done
rm -rf ~/.chief-of-staff/workspaces/wave-*
```

**Failed items:** Preserve workspaces for debugging. Report paths:

```text
Preserved workspaces for failed items:
  ~/.chief-of-staff/workspaces/wave-2-item-3  (#12 Auth middleware)
```

---

## Dashboard Updates

Throughout the wave lifecycle, update the dashboard accessible via `/cos:status`. The dashboard reads from `state.json` which is updated at every state transition:

- Agent dispatched
- Agent completed
- PR created
- PR merged
- Wave transition
- Final completion

Each update writes `updated_at` to `state.json`.

---

## Error Handling

| Problem | Action |
|---------|--------|
| Issue does not exist | Exclude from plan. Report. Continue with valid issues. |
| All issues invalid | Stop: `"No valid issues found."` |
| Cycle in dependency graph | Report the cycle. Stop. Ask user to break it. |
| Agent fails quality gates | Mark item `"failed"`, check retry budget, retry or report. |
| Merge conflict on PR | Attempt rebase. If rebase fails, mark `"failed"`, leave PR open. |
| All agents in a wave fail | STOP. Do not dispatch next wave. Report all failures. |
| Partial wave failure | Continue with succeeded items. Warn about downstream deps on failed items. |
| File overlap at runtime | If two agents edited the same file, merge first PR, rebase second, re-run quality gates. |
| JJ workspace add fails | Fall back to git worktree for that specific item. |
| Git worktree creation fails | Exclude item from wave, mark `"failed"`. |
| User declines wave plan | Stop. Suggest editing deps or running items individually. |
| `gh` CLI not authenticated | Stop: `"GitHub CLI not authenticated. Run gh auth login."` |
| Session directory creation fails | Fall back to `/tmp/chief-of-staff/sessions/`. |
| Context window filling up | Trigger checkpoint via `/cos:status` context tracking. Summarize state to disk. |

## State Transitions Summary

**Session:**

```
PLANNING ──> DISPATCHING ──> MONITORING ──> DISPATCHING (next wave) ──> ... ──> COMPLETE
                                  |
                                  v
                            CHECKPOINTING (on PreCompact/Stop)
```

**Work items:**

```
pending ──> dispatched ──> complete (merged)
                |
                v
             failed ──> dispatched (retry, max 2)
                |
                v
             failed (permanent)
```

**Waves:**

```
pending ──> active ──> complete (at least one item succeeded)
                |
                v
             failed (ALL items failed)
```
