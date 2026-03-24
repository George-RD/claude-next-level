---
name: implement
description: "Spawn an implementation agent in an isolated workspace. Creates PR on completion."
argument-hint: '"#issue-number" or "description of work"'
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

# /cos:implement

Spawn an implementation agent in an isolated workspace (JJ workspace or git worktree). The agent implements the task following TDD discipline, runs quality gates, commits, pushes, and creates a PR. Uses merge-as-you-go strategy.

## Usage

```bash
/cos:implement "#18"
/cos:implement "#18 focus on the API endpoint only"
/cos:implement "add rate limiting to /api/auth"
```

## Arguments

- `#N` — GitHub issue number to implement
- Free text — description of work to implement
- Mixed — `#N` with additional focus instructions

$ARGUMENTS

---

## Workflow

### 1. Parse Input

Extract the issue number and any supplemental description from the input.

**Detect issue reference:**

```bash
# If input contains #N, extract N
ISSUE_NUMBER=$(echo "$ARGUMENTS" | grep -oP '#\K\d+' | head -1)
EXTRA_CONTEXT=$(echo "$ARGUMENTS" | sed 's/#[0-9]*//' | xargs)
```

**If issue number found**, fetch issue details:

```bash
gh issue view $ISSUE_NUMBER --json number,title,body,labels,milestone,assignees
```

If the issue does not exist, stop immediately:

```text
Issue #N not found. Check the number and try again.
```

**If no issue number**, use the entire input as the task description.

**Build task brief:** Combine issue title, body, labels, and any user-provided extra context into a consolidated description.

### 2. Session State Check

Check for an active `/cos` session. If this command was invoked standalone (not from `/cos` or `/cos:wave`), create a minimal session:

```bash
SESSION_DIR=~/.chief-of-staff/sessions/${SESSION_ID:-$(uuidgen)}
mkdir -p "$SESSION_DIR"
```

Read existing `state.json` if present. If not, initialize a minimal state following the [canonical schema](../specs/state-schema.md):

```json
{
  "session_id": "<session-id>",
  "created_at": "<timestamp>",
  "updated_at": "<timestamp>",
  "vcs_type": "<detected>",
  "installed_plugins": [],
  "status": "DISPATCHING",
  "work_items": [],
  "waves": [],
  "agents": {},
  "quality_gates": {},
  "context": { "percentage": 0, "last_checked": "<timestamp>", "checkpoints": [] }
}
```

Create a work item entry for this task:

```json
{
  "id": "item-1",
  "description": "<task brief>",
  "type": "implement",
  "issue": 18,
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
```

### 3. Detect VCS Type

Detect once per session. If `state.json` already has `vcs_type`, use it. Otherwise:

```bash
if jj root >/dev/null 2>&1; then
  VCS_TYPE="jj"
else
  VCS_TYPE="git"
fi
```

Store the result in `state.json` `vcs_type` field. Never mix VCS types within a session.

### 4. Generate Branch Name

Derive a branch name from the task:

- **From issue:** `cos/<issue-number>-<slugified-title>` (e.g., `cos/18-add-rate-limiting`)
- **From description:** `cos/<slugified-first-5-words>` (e.g., `cos/add-rate-limiting-api-auth`)

Rules:

- Max 50 characters
- Lowercase
- Hyphens only (no underscores, spaces, or special characters)
- Strip trailing hyphens

### 5. Create Isolated Workspace

**JJ mode:**

```bash
WORKSPACE_PATH=~/.chief-of-staff/workspaces/item-${ITEM_ID}
jj workspace add "$WORKSPACE_PATH"
cd "$WORKSPACE_PATH"
jj new main
jj describe -m "wip: <task brief, max 72 chars>"
```

**Git mode:**

Use the Agent tool with `isolation: "worktree"`. The Agent SDK handles worktree creation and cleanup automatically. The workspace path is managed by the SDK.

Alternatively, for manual worktree management:

```bash
WORKSPACE_PATH=~/.chief-of-staff/workspaces/item-${ITEM_ID}
git worktree add "$WORKSPACE_PATH" -b $BRANCH_NAME
```

**If workspace creation fails:**

| VCS | Fallback |
|-----|----------|
| JJ workspace fails | Fall back to git worktree |
| Git worktree fails | Report error, suggest manual workspace creation |

Update `state.json` with workspace info:

```json
{
  "workspace": "~/.chief-of-staff/workspaces/item-1",
  "workspace_type": "jj",
  "branch": "cos/18-add-rate-limiting"
}
```

### 6. Read Project Conventions

Gather conventions and quality gate configuration from the project:

```bash
# Read project conventions
CONVENTIONS=""
[ -f CLAUDE.md ] && CONVENTIONS="$CONVENTIONS\n$(cat CLAUDE.md)"
[ -f AGENTS.md ] && CONVENTIONS="$CONVENTIONS\n$(cat AGENTS.md)"

# Detect quality gates from project config
# Check package.json, Makefile, Cargo.toml, pyproject.toml, etc.
```

If `state.json` `quality_gates.conventions_loaded` is false, detect quality tooling:

- **Build command:** Check for `npm run build`, `cargo build`, `make build`, `go build ./...`
- **Test command:** Check for `npm test`, `cargo test`, `pytest`, `go test ./...`
- **Lint command:** Check for `npm run lint`, `cargo clippy`, `ruff check`, `golangci-lint run`
- **Formatters:** Check for `prettier`, `ruff format`, `gofmt`, `rustfmt`

Update `quality_gates` in `state.json`.

### 7. Fill Implementation Prompt Template

Read the template from `templates/implementation-prompt.md` and fill all placeholders:

| Placeholder | Source |
|---|---|
| `{{ISSUE_TITLE}}` | Issue title or task description |
| `{{ISSUE_BODY}}` | Issue body + extra context from user |
| `{{ACCEPTANCE_CRITERIA}}` | Extracted from issue body (checklist items) or generated from description |
| `{{WORKSPACE_PATH}}` | Absolute path to isolated workspace |
| `{{CONVENTIONS}}` | Rendered conventions from Step 6 |
| `{{QUALITY_GATES}}` | Detected quality gate commands |
| `{{VCS_TYPE}}` | `git` or `jj` |

If acceptance criteria cannot be extracted from the issue body, generate reasonable criteria from the task description:

```markdown
- [ ] Implementation matches the described behavior
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Code follows project conventions
```

### 8. Dispatch Implementation Agent

Spawn the implementer agent in the background:

```
Agent tool call:
  description: "Implement: <task brief, max 60 chars>"
  prompt: <filled implementation-prompt.md>
  subagent_type: "general-purpose"
  mode: "bypassPermissions"
  isolation: "worktree"         # git mode only; JJ uses manual workspace from Step 5
  run_in_background: true
```

The agent definition is in `agents/implementer.md`. The agent:

1. Orients (reads issue, codebase context)
2. Plans (3-7 bullet checklist)
3. Implements via TDD cycle (failing test, implement, refactor)
4. Runs all quality gates
5. Commits with conventional commit format
6. Pushes to remote
7. Produces `=== IMPLEMENTATION REPORT ===`

**Immediately after dispatch**, update `state.json`:

```json
{
  "status": "dispatched",
  "agent_id": "<agent-id>",
  "started_at": "<timestamp>",
  "workspace": "<workspace-path>",
  "workspace_type": "<jj|git-worktree>",
  "branch": "<branch-name>"
}
```

Update session status to `"MONITORING"`.

Record the agent in `state.json` `agents` map:

```json
{
  "agents": {
    "<agent-id>": {
      "name": "implement-<slugified-task>",
      "type": "implement",
      "status": "running",
      "work_item_id": "<item-id>",
      "workspace_path": "<workspace-path>",
      "started_at": "<timestamp>",
      "completed_at": null
    }
  }
}
```

### 9. Display Dispatch Confirmation

```text
Implementation agent dispatched: "<task brief>"
Branch: <branch-name>
Workspace: <workspace-type> at <path>
Agent running in background. Use /cos:status for updates.
```

---

## Post-Completion Pipeline

When the background agent returns, execute this pipeline. If this command was called from `/cos:wave`, the wave orchestrator handles post-completion instead.

### 10. Parse Agent Output

Search the agent output for the implementation report:

```
=== IMPLEMENTATION REPORT ===
...
=== END REPORT ===
```

Extract the `Status:` field. Expected values: `COMPLETE`, `PARTIAL`, `BLOCKED`.

**If report is missing or Status is not COMPLETE:**

- Update work item: `status: "failed"`, `error: "<details>"`
- Update agent: `status: "failed"`, `completed_at: "<timestamp>"`
- Check retry budget: count agents in `agents` map referencing this `work_item_id`
  - If < 3 total attempts: re-dispatch (go to Step 8 with same workspace)
  - If >= 3 attempts: mark as permanently failed, report to user

```text
Implementation FAILED: "<task brief>"
Status: <PARTIAL|BLOCKED|MISSING REPORT>
Error: <extracted issues or "Agent did not produce a completion report">
Workspace preserved at: <path>
Branch: <branch-name> (partial work may be on this branch)
```

**If Status is COMPLETE**, proceed to Step 11.

### 11. Verify Quality Gates

Even though the agent reports quality gates passed, verify from the report:

- Check `Quality Gates:` section for any `FAIL` entries
- If any gate shows `FAIL`, treat as failure (go to retry logic in Step 10)

Extract from the report:

- Files changed list
- Test results
- Commit SHAs
- Branch/bookmark name

Update agent: `status: "complete"`, `completed_at: "<timestamp>"`

### 12. Create PR

**JJ mode:**

```bash
cd <workspace-path>
jj bookmark set <branch-name> -r @-
jj git push --bookmark <branch-name> --allow-new
gh pr create --head <branch-name> \
  --title "<issue title or task brief>" \
  --body "$(cat <<'EOF'
## Summary

<auto-generated from commits in the implementation report>

Closes #<issue-number>

## Quality Gates

- [x] Build passes
- [x] Tests pass
- [x] Lint clean

## Changes

<files changed list from report>

Automated by chief-of-staff
EOF
)"
```

**Git mode:**

```bash
git push -u origin <branch-name>
gh pr create --head <branch-name> \
  --title "<issue title or task brief>" \
  --body "<same format as above>"
```

**If PR creation fails:**

- The branch is still pushed to remote
- Report the error: `"PR creation failed: <error>. Branch <name> is pushed — create the PR manually."`
- Update work item with error but do NOT mark as failed (the code is delivered)

**On PR creation success**, update `state.json`:

```json
{
  "pr_number": 56,
  "result_summary": "<first 200 chars of implementation summary>"
}
```

Display:

```text
PR #<N> created for: <task brief>
URL: <pr-url>
Status: awaiting CI / awaiting review
```

### 13. Merge-as-you-go

After PR creation, attempt to merge immediately if CI passes and no review is required:

```bash
# Wait for CI (max 10 minutes)
gh pr checks <pr-number> --watch --fail-fast
```

**If CI passes and auto-merge is possible:**

```bash
gh pr merge <pr-number> --squash --delete-branch
```

**If review is required** (branch protection rules):

- Leave the PR open
- Note in state: `result_summary` includes "PR open, awaiting review"
- If `/cycle:pr` is available (check `installed_plugins`), suggest routing to review

**If merge conflict:**

- Report: `"Merge conflict on PR #N. Left open for manual resolution."`
- Do NOT mark as failed — the PR exists and can be resolved manually

### 14. Rebase Downstream Work

If other work items in later waves depend on this item (check `depends_on` references), the merge updates main so downstream agents start from a clean base.

**JJ mode:** Automatic. JJ auto-rebases descendants.

**Git mode:**

```bash
# Pull updated main for downstream worktrees
git checkout main && git pull
# Downstream worktrees will rebase when their wave starts
```

### 15. Workspace Cleanup

**After successful merge:**

**JJ mode:**

```bash
jj workspace forget <workspace-name>
rm -rf ~/.chief-of-staff/workspaces/item-${ITEM_ID}
```

**Git mode:**
Agent SDK handles worktree cleanup automatically for `isolation: "worktree"` agents. For manual worktrees:

```bash
git worktree remove ~/.chief-of-staff/workspaces/item-${ITEM_ID}
```

**After failure** (all retries exhausted):

- Preserve workspace for debugging
- Report workspace path to user

### 16. Final State Update

Update work item to terminal state:

| Outcome | State changes |
|---------|--------------|
| Merged | `status: "complete"`, `completed_at`, `pr_number`, `result_summary` |
| PR open (awaiting review) | `status: "complete"`, `completed_at`, `pr_number`, `result_summary: "PR open, awaiting review"` |
| Failed (all retries) | `status: "failed"`, `completed_at`, `error` |

Update session `updated_at`. If this was the only work item, set session status to `"COMPLETE"`.

---

## Error Handling

| Problem | Action |
|---------|--------|
| Issue does not exist | Report: `"Issue #N not found."` Stop. |
| `gh` CLI not authenticated | Report: `"GitHub CLI not authenticated. Run gh auth login."` Stop. |
| JJ workspace creation fails | Fall back to git worktree. If that also fails, report error. |
| Git worktree creation fails | Report error with suggestion: `"Could not create worktree. Check for existing worktrees with git worktree list."` |
| Agent fails mid-implementation | Save partial work (branch is pushed). Check retry budget. Re-dispatch or report. |
| Agent produces no report | Treat as failure. Check workspace for partial commits. Retry or report. |
| Build/test fails in quality gates | Report which gate failed and the error output. Retry agent with failure context. |
| PR creation fails | Branch is still pushed. Report error. User can create PR manually. |
| Merge conflict on PR | Report conflict details. Leave PR open for manual resolution. |
| Session directory cannot be created | Fall back to `/tmp/chief-of-staff/sessions/`. |

## State Transitions Summary

```
pending ──> dispatched ──> complete (quality gates pass, PR created/merged)
                |
                v
             failed ──> dispatched (retry, max 2 retries)
                |
                v
             failed (permanent, after 3 total attempts)
```

Session status flow for standalone invocation:

```
DISPATCHING ──> MONITORING ──> COMPLETE
```
