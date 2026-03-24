---
name: review
description: "Route a PR or branch to the review lifecycle."
argument-hint: '"PR #N" or "branch-name"'
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Agent
  - LSP
---

# /cos:review

Route review work to the appropriate handler. For PRs, delegates to `/cycle:pr` for the full review lifecycle (poll, fix comments, push, re-poll, merge). For branches without a PR, spawns a code-reviewer agent directly.

## Usage

```bash
/cos:review "PR #42"
/cos:review "#42"              # also interpreted as PR
/cos:review "feature/foo"      # branch review
/cos:review "PR #42 #43 #44"  # multiple PRs
```

## Arguments

- `PR #N` or `#N` — one or more PR numbers
- Branch name — a branch to review (no PR required)
- Multiple — space-separated PR numbers

$ARGUMENTS

---

## Workflow

### 1. Parse Input

Extract PR numbers and/or branch names from the input.

**Detect PR references:**

```bash
# Extract all numbers preceded by #, PR #, or PR
PR_NUMBERS=$(echo "$ARGUMENTS" | grep -oP '(?:PR\s*)?#?\K\d+' | sort -u)
```

**Detect branch references:** Anything that is not a number and looks like a branch name (contains `/` or is alphanumeric with hyphens).

```bash
# After extracting PR numbers, remaining tokens may be branch names
BRANCH_NAME=$(echo "$ARGUMENTS" | sed 's/PR\s*#\?[0-9]*//g' | xargs)
```

### 2. Validate References

**For each PR number**, verify it exists and is open:

```bash
gh pr view $PR_NUMBER --json number,title,state,headRefName,url,reviewDecision
```

If the PR does not exist:

```text
PR #N not found. Check the number and try again.
```

If the PR is already merged or closed:

```text
PR #N is already <merged|closed>. Nothing to review.
```

**For branch names**, check if a PR already exists for the branch:

```bash
# Check if branch exists
git branch --list "$BRANCH_NAME" --remotes

# Check if a PR exists for this branch
gh pr list --head "$BRANCH_NAME" --json number,title,state
```

- If a PR exists for the branch, switch to PR review mode (use the PR number).
- If the branch does not exist locally or on remote:

```text
Branch '<name>' not found locally or on remote.
```

### 3. Session State Check

Check for an active `/cos` session. If invoked standalone, create a minimal session following the [canonical schema](../specs/state-schema.md).

Create a work item entry for each review target:

```json
{
  "id": "item-1",
  "description": "review PR #42",
  "type": "review",
  "issue": null,
  "pr_number": 42,
  "wave": 1,
  "depends_on": [],
  "agent_id": null,
  "workspace": null,
  "workspace_type": "none",
  "branch": "feature/foo",
  "status": "pending",
  "started_at": null,
  "completed_at": null,
  "result_summary": null,
  "error": null
}
```

---

## Routing: PR Review

When the target is one or more PRs, delegate to `/cycle:pr` for the full review lifecycle.

### 4a. Check for /cycle:pr Availability

```bash
# Check if cycle plugin is installed
# Read state.json installed_plugins or check plugin directory
```

**If `/cycle:pr` is available:**

### 5a. Delegate to /cycle:pr

For single PR:

```
Invoke /cycle:pr <pr-number>
```

For multiple PRs:

```
Invoke /cycle:pr <pr-number-1> <pr-number-2> <pr-number-3>
```

The cycle plugin handles the full lifecycle:

1. Poll for CI and reviews
2. Address all comments (CodeRabbit, human reviewers)
3. Push fixes
4. Re-poll for new comments
5. Repeat until clean
6. Merge with `--squash --delete-branch`

Display:

```text
Routing PR #<N> to /cycle:pr for full review lifecycle.
```

**Update `state.json`:**

```json
{
  "status": "dispatched",
  "pr_number": 42,
  "started_at": "<timestamp>"
}
```

When `/cycle:pr` completes (PR merged or escalated):

```json
{
  "status": "complete",
  "completed_at": "<timestamp>",
  "result_summary": "PR #42 merged via /cycle:pr"
}
```

### 5a-fallback. If /cycle:pr Not Available

Fall back to spawning a reviewer agent (same path as branch review below), but targeting the PR diff:

```bash
gh pr diff $PR_NUMBER
```

---

## Routing: Branch Review

When the target is a branch without an existing PR, spawn a code-reviewer agent directly.

### 4b. Read Project Conventions

```bash
CONVENTIONS=""
[ -f CLAUDE.md ] && CONVENTIONS="$CONVENTIONS\n$(cat CLAUDE.md)"
[ -f AGENTS.md ] && CONVENTIONS="$CONVENTIONS\n$(cat AGENTS.md)"
```

### 5b. Fill Review Prompt Template

Read the template from `templates/review-prompt.md` and fill all placeholders:

| Placeholder | Source |
|---|---|
| `{{PR_URL}}` | `"N/A (branch review)"` |
| `{{BRANCH}}` | Branch name |
| `{{CONVENTIONS}}` | Project conventions from Step 4b |
| `{{FOCUS_AREAS}}` | Extracted from user input or `"None"` |

### 6b. Dispatch Reviewer Agent

Spawn the reviewer agent in the background:

```
Agent tool call:
  description: "Review branch: <branch-name>"
  prompt: |
    ## Code Review

    Review the changes on branch `<branch-name>` compared to `main`.

    ```bash
    git diff main...<branch-name> --stat
    git diff main...<branch-name>
    git log main...<branch-name> --oneline
    ```

    ## Project Conventions

    <conventions from Step 4b>

    ## Review Checklist

    For each file changed:
    1. **Correctness**: Does the code do what it claims?
    2. **Edge cases**: Are error paths handled?
    3. **Tests**: Are there tests? Do they cover the changes?
    4. **Style**: Does it follow the project's conventions?
    5. **Security**: Any credentials, injection risks, or auth gaps?
    6. **Performance**: Any obvious N+1 queries, unbounded loops, or memory leaks?

    ## Output Format

    Produce a report in this exact format:

    === REVIEW REPORT ===
    Status: COMPLETE

    PR: N/A (branch review)
    Branch: <branch-name>
    Verdict: APPROVE | REQUEST_CHANGES | COMMENT

    Summary:
    <2-3 sentence assessment>

    Findings:
    1. [SEVERITY] <file>:<line> — <description>
       Suggestion: <concrete fix>

    Checklist:
    - Correctness: PASS | ISSUES
    - Testing: PASS | ISSUES
    - Security: PASS | N/A | ISSUES
    - Conventions: PASS | ISSUES
    - Design: PASS | ISSUES
    - Performance: PASS | N/A | ISSUES
    === END REPORT ===

  subagent_type: "research"
  run_in_background: true
```

The agent is read-only: no `Write`, `Edit`, or file-modifying `Bash` commands.

**Update `state.json` on dispatch:**

```json
{
  "status": "dispatched",
  "agent_id": "<agent-id>",
  "started_at": "<timestamp>"
}
```

Record in `agents` map:

```json
{
  "<agent-id>": {
    "name": "review-<branch-name>",
    "type": "review",
    "status": "running",
    "work_item_id": "<item-id>",
    "workspace_path": null,
    "started_at": "<timestamp>",
    "completed_at": null
  }
}
```

Display:

```text
Code review agent dispatched for branch: <branch-name>
Agent running in background. Use /cos:status for updates.
```

---

## Post-Completion (Branch Review)

### 7b. Parse Agent Output

Search the agent output for the review report:

```
=== REVIEW REPORT ===
...
=== END REPORT ===
```

Extract the `Status:` field and `Verdict:` field.

**If report is missing:**

- Update work item: `status: "failed"`, `error: "Agent did not produce a review report"`
- Check retry budget (max 2 retries, 3 total attempts)
  - If retries remain: re-dispatch agent
  - If exhausted: report failure, suggest manual review

**If report is present:**

- Update work item: `status: "complete"`, `completed_at: "<timestamp>"`
- Update agent: `status: "complete"`, `completed_at: "<timestamp>"`
- Store `result_summary` (first 200 chars of Summary section)

### 8b. Display Review Results

Display the full review report from the agent as-is. Then provide a summary:

```text
Review complete for branch: <branch-name>
Verdict: <APPROVE|REQUEST_CHANGES|COMMENT>
Findings: <N> total (<X> blockers, <Y> major, <Z> minor)
```

If the verdict is `REQUEST_CHANGES` and the branch has associated work items, suggest:

```text
To address review findings, run:
  /cos:implement "<branch-name> — address review findings"
```

---

## Multi-PR Review

When multiple PRs are provided, handle each independently:

### Parallel Dispatch

```
For each PR in PR_NUMBERS:
  1. Validate PR exists and is open
  2. Create work item in state.json
  3. Route to /cycle:pr (or spawn reviewer if cycle unavailable)
```

If `/cycle:pr` supports multiple PRs natively:

```
Invoke /cycle:pr <pr1> <pr2> <pr3>
```

Otherwise, dispatch each PR review independently with `run_in_background: true`.

Display:

```text
Routing <N> PRs to review lifecycle:
  PR #42 — <title>
  PR #43 — <title>
  PR #44 — <title>

Use /cos:status for progress updates.
```

---

## State Updates Summary

| Event | State change |
|-------|-------------|
| Review dispatched (branch) | `status: "dispatched"`, `agent_id`, `started_at` |
| Review dispatched (PR via /cycle:pr) | `status: "dispatched"`, `pr_number`, `started_at` |
| Branch review complete | `status: "complete"`, `completed_at`, `result_summary` |
| PR merged (via /cycle:pr) | `status: "complete"`, `completed_at`, `result_summary` |
| Review failed or stuck | `status: "failed"`, `error` |
| Retry dispatched | `status: "dispatched"` (new `agent_id`), previous agent `status: "failed"` |

Session status flow for standalone invocation:

```
DISPATCHING ──> MONITORING ──> COMPLETE
```

---

## Error Handling

| Problem | Action |
|---------|--------|
| PR does not exist | Report: `"PR #N not found."` Exclude from plan, continue with valid PRs. |
| PR already merged/closed | Report: `"PR #N is already <state>."` Skip. |
| Branch does not exist | Report: `"Branch '<name>' not found locally or on remote."` Stop. |
| `/cycle:pr` not available | Fall back to spawning a reviewer agent directly. Review-only (no fix cycle). |
| Agent timeout | Report timeout. Suggest: `"Review agent timed out. Try reviewing manually or with a more specific focus."` |
| Agent produces no report | Retry once. If second attempt fails, report failure. |
| `gh` CLI not authenticated | Report: `"GitHub CLI not authenticated. Run gh auth login."` Stop. |
| Agent produces empty findings | Valid outcome — report APPROVE with clean review. |
