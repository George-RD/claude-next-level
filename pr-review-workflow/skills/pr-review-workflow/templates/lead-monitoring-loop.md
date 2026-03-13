# Monitoring Loop — Poll and Dispatch

Reference template for the centralized monitoring loop that manages multiple PRs through review. Used by `/pr-cycle` in multi-PR mode.

---

## State Machine

Each PR moves through these states:

```
open → fixing → pushed → polling → open    (new comments found)
                                  → clean   (no new comments)
                                  → merged  (squash merged)
```

**State definitions:**

| State | Meaning | Action |
|-------|---------|--------|
| `open` | Has unresolved comments, no agent running | Dispatch a fix agent |
| `fixing` | Fix agent dispatched and working | Wait for agent to complete |
| `pushed` | Agent pushed fixes, awaiting re-review | Start poll timer |
| `polling` | Checking for new comments after push | Run poll commands |
| `clean` | All checks pass, no pending comments | Ready to merge |
| `merged` | Squash merged and branch deleted | Done |
| `blocked` | Agent failed or hit round 5 | Escalate to user |

---

## Dashboard Format

Maintain this dashboard and update it after every poll cycle:

```text
PR DASHBOARD — <timestamp>
──────────────────────────────────────────────────────────────────
PR    Branch                State     CI     Round  Pending  Agent
#42   feature/foo           open      pass   1      3        -
#43   feature/bar           fixing    pend   0      0        bg-agent-1
#44   fix/baz               clean     pass   2      0        -
──────────────────────────────────────────────────────────────────
Next: Dispatch fix agent for #42 (3 comments). Merge #44 (clean).
```

---

## Polling Commands

Run these for each PR. Execute all PR checks in parallel when possible.

### CI Status

```bash
gh pr checks {{PR_NUMBER}}
```

### Inline Review Comments

```bash
gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR_NUMBER}}/comments \
  --jq '[.[] | select(.created_at > "{{LAST_POLL_TIME}}")] | length'
```

To get full comment details:

```bash
gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR_NUMBER}}/comments \
  --jq '.[] | {id, path, line, body, user: .user.login, created_at}'
```

### Review Summaries

```bash
gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR_NUMBER}}/reviews \
  --jq '.[] | {id, state, body, user: .user.login}'
```

### Unresolved Count

```bash
# Count of pending inline comments (not replied to)
gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR_NUMBER}}/comments \
  --jq '[.[] | select(.in_reply_to_id == null)] | length'
```

---

## Polling Cadence

```text
T+0:       PRs pushed / fix agents dispatched
T+2-3min:  First poll (CI usually completes, CodeRabbit posts)
T+5-8min:  Second poll (most automated reviews are in)
T+10min+:  Every 3-5 min while any PR has state != clean/merged/blocked
T+final:   One last check 5 min after last state change
```

CodeRabbit converges after ~3 rounds. If round > 3 and still getting new comments, look for a pattern (same issue being re-raised) rather than blind-fixing.

---

## Dispatching Fix Agents

When a PR transitions to `open` state (has unresolved comments):

### 1. Collect Comments

Gather all unresolved comments for that PR:

```bash
gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR_NUMBER}}/comments \
  --jq '.[] | {id, path, line, body, user: .user.login}'
```

Format them as a COMMENT_LIST:

```text
Comment #<id> by <reviewer> on <file>:<line>:
> <comment body>

Comment #<id> by <reviewer> on <file>:<line>:
> <comment body>
```

### 2. Fill Template

Use the fix agent template (`templates/pr-agent-prompt.md`) with these placeholders:

| Placeholder | Value |
|-------------|-------|
| `{{WORKTREE_PATH}}` | Absolute path to worktree (or repo root) |
| `{{BRANCH}}` | PR head branch name |
| `{{PR_NUMBER}}` | GitHub PR number |
| `{{OWNER}}` | Repository owner |
| `{{REPO}}` | Repository name |
| `{{COMMENT_LIST}}` | Formatted comments from step 1 |

### 3. Dispatch

```
Agent tool:
  description: "Fix PR #<N> review comments"
  prompt: <filled template>
  subagent_type: "general-purpose"
  run_in_background: true
```

### 4. Track

Set PR state to `fixing`. Record agent ID for status checking.

### Dispatch Rules

- **With worktrees**: Dispatch agents for multiple PRs in parallel
- **Without worktrees**: One agent at a time (serialize to avoid git conflicts)
- **Never double-dispatch**: Don't send a new agent if one is already `fixing` that PR
- **On agent completion**: Parse the FIX REPORT from agent output, update dashboard

---

## Merge Ordering

When PRs reach `clean` state, merge in this order:

### Algorithm

1. **Build dependency graph**: Check if any PR branch was based on another PR branch
2. **Topological sort**: Dependencies first
3. **Break ties by diff size**: Smallest additions+deletions first (less conflict surface)
4. **After each merge**: Wait for remaining PRs to re-run CI (base branch changed)

### Execution

```bash
# Merge one PR
gh pr merge {{PR_NUMBER}} --squash --delete-branch

# Wait for CI on remaining PRs
# Poll remaining PRs with `gh pr checks` until all re-run
```

### Conflict Handling

If a merge causes conflicts in remaining PRs:
1. Rebase the conflicting PR on updated main
2. Push the rebased branch
3. Wait for CI + re-review
4. The PR goes back to `polling` state

---

## Serial Queue (No Worktrees)

When worktrees aren't available, process PRs one at a time:

```text
SERIAL QUEUE
────────────
1. Check all PRs for comments
2. Pick the PR with fewest comments (fastest to fix)
3. Dispatch fix agent (foreground, not background)
4. Wait for completion
5. Poll for re-review
6. If clean → merge; if new comments → re-queue
7. Next PR in queue
```

This is slower but avoids git state conflicts.

---

## Exit Conditions

| Condition | Action |
|-----------|--------|
| All PRs merged | Print summary, report SUCCESS |
| PR hits round 5 | Mark BLOCKED, escalate to user, continue others |
| Agent fails twice on same PR | Mark BLOCKED, escalate |
| All PRs are merged or blocked | Print final dashboard, exit |
| User interrupts | Print current state, exit gracefully |

### Final Summary Format

```text
=== PR CYCLE COMPLETE ===
Total PRs: <N>
Merged: <N> (#42, #43, ...)
Blocked: <N> (#44 — reason)
Total rounds: <N>
Total time: <duration>
=== END ===
```

---

## Cross-PR Intelligence

While monitoring multiple PRs, actively look for:

1. **Repeated feedback**: Same comment on 2+ PRs → fix proactively in all affected PRs
2. **Convention comments**: Style/naming feedback → apply consistently across all PRs
3. **Merge conflicts**: Two PRs touching same files → merge simpler one first
4. **Shared dependency changes**: One reviewer asks for a model change → check if other PRs use that model

When cross-PR feedback is detected, include it in the COMMENT_LIST for affected fix agents with a note: `(Cross-PR: also applies to #<other-PR>)`.
