---
name: cos
description: "Parse a work description, analyze dependencies, route to workflows, dispatch agents in waves."
argument-hint: '"build feature X, review PRs 42-44, port module Y"'
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
---

# /cos

Main entry point for chief-of-staff. Accepts a natural-language work description containing one or more work items. Parses them, determines dependencies, routes each to the appropriate workflow, and dispatches Wave 1 agents.

## Usage

```bash
/cos "build feature X, review PRs 42-44, port module Y"
/cos "implement #18, #12 depends on #18, review PR #55"
/cos "research caching strategies, then implement #22"
```

$ARGUMENTS

---

## Workflow

### 1. Parse Work Items

Split the user's description into discrete work items. Delimiters: commas, "and", "then", semicolons. Each item becomes a node in the dependency graph.

### 2. Classify Each Work Item

Scan each item for keywords and assign a type:

| Pattern | Type | Route |
|---------|------|-------|
| `review PR #N`, `review PRs N-M` | review | `/cos:review` |
| `build`, `implement`, `create`, `add`, `fix` + `#issue` or description | implement | `/cos:implement` |
| `research`, `explore`, `investigate`, `analyze` | research | `/cos:research` |
| `port`, `migrate`, `clone` + module/repo reference | port | `repo-clone` plugin |
| `spec`, `design`, `plan` | spec | `ralph-wiggum` plugin |

### 3. Extract and Validate Identifiers

Pull out issue numbers (`#N`), PR numbers (`PR #N`, `PR N`), branch names, file paths, and free-text descriptions from each work item.

For each issue number:

```bash
gh issue view <N> --json number,title,state,body,labels,assignees
```

For each PR number:

```bash
gh pr view <N> --json number,title,state,headRefName,url
```

If an identifier does not exist, report the error and exclude the item from the plan. Continue with valid items.

### 4. Build Dependency Graph

Detect **explicit dependencies** from keywords: "depends on", "after", "then", "once X is done", "blocked by", "requires". Build a directed acyclic graph (DAG).

Detect **implicit dependencies** using heuristics:

- Same issue label or milestone suggests coupling
- "implement X" followed by "review X" implies sequence
- Research items feeding into implementation items implies sequence
- Two items referencing the same files or module cannot run in parallel

### 5. Topological Sort into Waves

Order the DAG into waves:

- **Wave 1**: All items with no unmet dependencies (root nodes)
- **Wave N**: Items whose dependencies were all in waves 1..N-1

If cycles are detected, report them to the user and ask for clarification before proceeding.

### 6. Detect VCS Type

```bash
jj root >/dev/null 2>&1
```

- If exits 0: set `vcs_type` to `"jj"`
- If exits non-zero: set `vcs_type` to `"git"`

### 7. Detect Installed Plugins

Check which sibling plugins are available by looking for their `plugin.json` files:

```bash
ls "${CLAUDE_PLUGIN_ROOT}/../cycle/plugin.json" 2>/dev/null && echo "cycle"
ls "${CLAUDE_PLUGIN_ROOT}/../ralph-wiggum/plugin.json" 2>/dev/null && echo "ralph-wiggum"
ls "${CLAUDE_PLUGIN_ROOT}/../next-level/plugin.json" 2>/dev/null && echo "next-level"
```

Record detected plugins in `installed_plugins`.

### 8. Create Session State

Use Claude Code's native `session_id` (from SessionStart hook stdin). If unavailable, read from existing `state.json` or fall back to a generated UUID.

```bash
mkdir -p ~/.chief-of-staff/sessions/{session-id}
```

Write initial `~/.chief-of-staff/sessions/{session-id}/state.json` following the canonical schema:

```json
{
  "session_id": "<session-id>",
  "created_at": "<ISO-8601-now>",
  "updated_at": "<ISO-8601-now>",
  "vcs_type": "<jj|git>",
  "installed_plugins": ["<detected-plugins>"],
  "status": "PLANNING",
  "work_items": [
    {
      "id": "item-1",
      "description": "<parsed description>",
      "type": "<implement|research|review|port|spec>",
      "issue": null,
      "pr_number": null,
      "wave": 1,
      "depends_on": [],
      "agent_id": null,
      "workspace": null,
      "workspace_type": null,
      "branch": null,
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "result_summary": null,
      "error": null
    }
  ],
  "waves": [
    { "number": 1, "status": "pending", "items": ["item-1"], "started_at": null, "completed_at": null }
  ],
  "agents": {},
  "quality_gates": {},
  "context": {
    "percentage": 0,
    "last_checked": "<ISO-8601-now>",
    "checkpoints": []
  }
}
```

If the session directory cannot be created under `~/.chief-of-staff/sessions/`, fall back to `/tmp/chief-of-staff/sessions/`.

### 9. Dispatch Wave 1

Update session status to `"DISPATCHING"`.

For each item in Wave 1, dispatch via the appropriate subcommand:

- **Research items**: call `/cos:research` logic
- **Implementation items**: call `/cos:implement` logic
- **Review items**: call `/cos:review` logic
- **Port items**: delegate to `repo-clone` plugin
- **Spec items**: delegate to `ralph-wiggum` plugin

All dispatches use `run_in_background: true`. After each dispatch, update `state.json`:

- Set work item `status` to `"dispatched"`
- Set `agent_id` to the assigned agent ID
- Set `started_at` to the current timestamp
- Record the agent entry in `agents` map

After all Wave 1 dispatches complete, update session status to `"MONITORING"` and mark Wave 1 as `"active"` with `started_at` set.

### 10. Display Status Dashboard

Show the initial dispatch plan:

```text
CHIEF OF STAFF - SESSION {session-id}
═══════════════════════════════════════════════════════════

Work Items:
┌────────┬──────────────────┬───────────┬───────┬─────────────┐
│ ID     │ Description      │ Type      │ Wave  │ Status      │
├────────┼──────────────────┼───────────┼───────┼─────────────┤
│ item-1 │ implement #18    │ implement │  1    │ dispatched  │
│ item-2 │ review PR #55    │ review    │  1    │ dispatched  │
│ item-3 │ research caching │ research  │  1    │ dispatched  │
│ item-4 │ implement #12    │ implement │  2    │ pending     │
└────────┴──────────────────┴───────────┴───────┴─────────────┘

Wave 1: 3 agents dispatched (item-1, item-2, item-3)
Wave 2: 1 item waiting on item-1

Run /cos:status for live updates.
```

### 11. Handle Agent Completions

When a background agent completes, update `state.json`:

- Set work item `status` to `"complete"` or `"failed"`
- Set agent `status` to `"complete"` or `"failed"`
- Record `completed_at` timestamp
- If failed, record `error` message

Check wave completion. If all items in the current wave are complete (or failed):

- If ALL items failed: mark wave as `"failed"`, stop, and report failures to user
- If at least one succeeded: mark wave as `"complete"`
- Set session status to `"DISPATCHING"` and dispatch the next wave

### 12. Session Completion

When the final wave completes, set session status to `"COMPLETE"` and display a summary:

```text
SESSION COMPLETE - {session-id}
═══════════════════════════════════════
Completed: 3/4 items
Failed: 1 item (item-4: merge conflict on src/auth.ts)
PRs created: #56, #57
PRs merged: #56
Duration: 23 minutes
```

---

## Error Handling

| Problem | Action |
|---------|--------|
| Issue number does not exist | Report error, exclude from plan, continue with valid items |
| PR number does not exist | Report error, exclude from plan, continue with valid items |
| Cycle in dependency graph | Report cycle to user, ask for resolution before proceeding |
| Agent fails | Mark item as `"failed"`, continue wave, report at wave completion |
| All items in a wave fail | Stop dispatching. Report failures with details to user |
| `gh` CLI not authenticated | Stop immediately: "Run `gh auth login` to authenticate." |
| Session directory cannot be created | Fall back to `/tmp/chief-of-staff/sessions/` |
| No valid work items after parsing | Report: "No valid work items found. Check issue/PR numbers and try again." |
