---
name: pr-review-workflow
description: Domain knowledge for multi-PR review orchestration — monitoring patterns, fix dispatch, worktree management, cross-PR intelligence, and CodeRabbit specifics. Referenced by /pr-cycle for batch PR operations.
---

# PR Review Workflow — Domain Knowledge

Reference knowledge for orchestrating PR review cycles. The procedural workflow lives in `/pr-cycle`; this skill provides the patterns and expertise that workflow depends on.

## When This Activates

- `/pr-cycle` is running in multi-PR mode and needs domain knowledge
- You're designing or debugging a batch PR review process
- You need to understand CodeRabbit behavior, worktree management, or cross-PR patterns

---

## Monitoring Patterns

### Polling Strategy

CodeRabbit and GitHub Actions have predictable timing:

| Event | Typical Delay | What to Check |
|-------|--------------|---------------|
| Push → CI start | 10-30 sec | `gh pr checks <N>` |
| Push → CI complete | 1-5 min | `gh pr checks <N>` (look for all green/red) |
| Push → CodeRabbit review | 1-3 min | `gh api repos/{o}/{r}/pulls/{n}/comments` |
| Fix push → CodeRabbit re-review | 1-2 min | Same, filter by `created_at > last_check` |

**Optimal cadence**: First poll at 2-3 min. Then every 3-5 min. CodeRabbit converges after ~3 rounds — if you're past round 3 and still getting new comments, check for a recurring pattern rather than fixing one-off.

### What to Poll

```bash
# CI status (pass/fail/pending)
gh pr checks {{PR_NUMBER}}

# Inline review comments (CodeRabbit, humans)
gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR_NUMBER}}/comments \
  --jq '.[] | {id, path, line, body, user: .user.login, created_at}'

# Review summaries (approve/request-changes/comment)
gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR_NUMBER}}/reviews \
  --jq '.[] | {id, state, body, user: .user.login}'

# General PR comments (issue-level)
gh api repos/{{OWNER}}/{{REPO}}/issues/{{PR_NUMBER}}/comments \
  --jq '.[] | {id, body, user: .user.login, created_at}'
```

### Detecting "Clean" State

A PR is clean when ALL of:
- `gh pr checks` shows all green
- Zero unresolved inline comments
- No "CHANGES_REQUESTED" reviews outstanding
- No merge conflicts with base branch

---

## Fix Dispatch Patterns

### Dispatch-and-Poll (Not Team/SendMessage)

The monitoring loop dispatches finite background agents. Each agent:
1. Receives specific comments to fix
2. Fixes them, commits, pushes
3. Reports results and exits

The agent does NOT wait for re-review. The monitoring loop handles the re-poll.

### Agent Prompt Template

Located at: `templates/pr-agent-prompt.md`

Required placeholders:
- `{{WORKTREE_PATH}}`: Working directory (worktree path or repo root)
- `{{BRANCH}}`: Head branch name
- `{{PR_NUMBER}}`: GitHub PR number
- `{{OWNER}}` / `{{REPO}}`: Repository coordinates
- `{{COMMENT_LIST}}`: Formatted comment list for the agent to address

### Preventing Silent Stops

Agents sometimes complete edits but stop before committing. The agent prompt template includes a MUST-complete section to prevent this. If an agent still stops early:
1. Check its output for error messages
2. Resume the agent with explicit "commit and push" instructions
3. If it fails twice, take over manually

### Serial vs Parallel Dispatch

| Scenario | Strategy |
|----------|----------|
| Worktrees available | Dispatch all fix agents in parallel |
| No worktrees, different repos | Parallel is fine |
| No worktrees, same repo | Serialize — one agent at a time |
| Agent already running for a PR | Wait for it to complete |

---

## Worktree Management

### Setup

```bash
# Create worktree for a branch
git worktree add ../repo-worktree-<branch-suffix> <branch-name>

# List all worktrees
git worktree list
```

### Gotchas

- Worktrees share the git object store but have independent working trees
- Pre-push hooks may fail in worktrees (e.g., no simulator access for iOS) — use `SKIP_PREPUSH=1` after manual build verification
- After merging, clean up immediately: `git worktree remove <path>`
- Stale worktrees cause confusion — run `git worktree prune` periodically

### Worktree Path Convention

When dispatching agents, always provide the **absolute worktree path** so the agent can `cd` directly. Check `git worktree list` to find it.

---

## Cross-PR Intelligence

### Overlap Detection

Watch for these patterns when reviewing comments across multiple PRs:

| Pattern | Signal | Action |
|---------|--------|--------|
| Same style comment on 2+ PRs | Convention issue | Apply fix to ALL affected PRs |
| Architecture feedback | Structural concern | Evaluate cross-PR impact before fixing |
| Merge conflict warning | Overlapping changes | Merge simpler PR first, rebase others |
| Shared dependency change | Coordination needed | Fix in one PR, verify in others |

### Merge Ordering

1. **Dependencies first**: If PR B branched from PR A → merge A first
2. **Smallest diff**: Less change = less conflict surface
3. **After each merge**: Remaining PRs may need CI re-run (base changed)
4. **Conflict resolution**: If two PRs touch the same files, merge the simpler one, then rebase the other on the updated main

---

## CodeRabbit Specifics

### Behavior

- Posts an initial summary comment + inline comments within 1-3 min of push
- Re-reviews on each push, but only comments on new/changed code
- Converges after 2-3 rounds typically — diminishing new comments
- Sometimes re-raises resolved comments if the fix changes nearby code

### Configuration

- `.coderabbit.yaml` in repo root controls behavior
- If CodeRabbit doesn't review: check the file exists, try closing/reopening the PR
- CodeRabbit respects `@coderabbitai resolve` to mark threads as resolved

### Comment Types

| CodeRabbit Comment | How to Handle |
|-------------------|---------------|
| Bug/logic error | Fix immediately — these are high-signal |
| Security issue | Fix immediately |
| Style/nitpick | Fix it — clean PRs merge faster |
| Performance suggestion | Fix if small; issue if large refactor |
| False positive | Reply explaining why it's incorrect |

---

## Error Recovery

| Problem | Root Cause | Resolution |
|---------|-----------|------------|
| Agent edits but doesn't commit | Agent hit context limit or stopped early | Resume agent or take over manually |
| CI fails on unrelated test | Flaky test or upstream break | `gh run rerun --failed` or push empty commit |
| Merge conflict post-fix | Base branch moved | `git rebase main` in the PR branch |
| CodeRabbit not posting | Missing config or rate limit | Check `.coderabbit.yaml`; close/reopen PR |
| Reviewer requests large refactor | Scope creep | Create follow-up issue; keep PR focused |
| Agent infinite loop | Keeps re-fixing same thing | Stop after 3 identical fixes; escalate to user |
| Worktree in bad state | Uncommitted changes or detached HEAD | `git worktree remove --force` + recreate |
