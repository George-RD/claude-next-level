---
name: pr-review-workflow
description: Use when you need to open and shepherd multiple PRs through review — spawns parallel agents per branch, runs local lint + cloud review, monitors comments, iterates until all PRs are clean and mergeable.
---

# PR Review Sprint

Orchestrate team-based PR reviews with parallel agents. Each agent owns a branch, opens a PR, runs lint, resolves review comments, and pushes until clean.

## When to Use

- You have 2+ feature branches ready for PR
- Each branch needs: local lint, PR creation, cloud review, comment resolution
- You want parallel execution with a central monitoring loop

## Prerequisites

- Branches exist (locally or on remote)
- `gh` CLI authenticated
- `cr` CLI installed (CodeRabbit) for local lint — or substitute your linter
- Git worktrees set up if agents edit concurrently (see worktree setup below)

---

## Phase 1: Setup

### 1A. Inventory Branches

List all branches that need PRs:

```text
BRANCH INVENTORY
────────────────
Branch: feature/foo       → PR Title: "Add foo feature"     → Closes: #12
Branch: feature/bar       → PR Title: "Fix bar handling"    → Closes: #15, #16
Branch: fix/baz           → PR Title: "Fix baz regression"  → Closes: #20
```

### 1B. Create Worktrees (if parallel editing needed)

Each agent needs its own working directory to avoid git conflicts:

```bash
# From the main repo
git worktree add ../repo-worktree-foo feature/foo
git worktree add ../repo-worktree-bar feature/bar
```

### 1C. Create Team

Use `TeamCreate` to set up the team, then create tasks per branch with `TaskCreate`.

### 1D. Spawn PR Agents

Spawn one `general-purpose` agent per branch using the Task tool with `team_name`. Use the **pr-agent-prompt** template (`templates/pr-agent-prompt.md`) — fill in placeholders for each branch.

Spawn all agents in **parallel** in a single message with multiple Task tool calls.

### 1E. Optional: Spawn Plugin Builder

If you also need a plugin or documentation agent, spawn it in the same parallel batch.

---

## Phase 2: Local Review + PR Creation

Each PR agent executes this sequence independently (defined in the agent prompt template):

1. **Checkout** — Ensure branch is up to date with remote
2. **Local lint** — Run `cr review` (or equivalent) on the branch diff
3. **Fix findings** — Address lint issues, commit fixes
4. **Push** — Push branch to remote
5. **Open PR** — Use `gh pr create` with proper title, body, and `Closes #issue` references
6. **Report** — Send message to team lead with PR URL and lint summary

### Key Commands

```bash
# Local CodeRabbit review
cr review

# Push with upstream tracking
git push -u origin {{BRANCH}}

# Open PR
gh pr create --title "{{PR_TITLE}}" --body "$(cat <<'EOF'
## Summary
- {{BULLET_POINTS}}

## Test plan
- [ ] {{TEST_ITEMS}}

Closes {{CLOSES_ISSUES}}

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Phase 3: Comment Monitoring Loop

The team lead runs a monitoring loop after all PRs are open. Use the **lead-monitoring-loop** template (`templates/lead-monitoring-loop.md`) for the full pattern.

### 3A. Poll PR Status

For each open PR, periodically check:

```bash
# CI/check status
gh pr checks {{PR_NUMBER}}

# Review comments (pending reviews)
gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR_NUMBER}}/reviews

# Inline comments
gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR_NUMBER}}/comments

# General PR comments
gh api repos/{{OWNER}}/{{REPO}}/issues/{{PR_NUMBER}}/comments
```

### 3B. Dashboard Tracking

Maintain a mental or written dashboard:

```text
PR DASHBOARD
────────────────────────────────────────────────
PR   Branch              Status    CI    Comments
#42  feature/foo         Open      Pass  3 pending
#43  feature/bar         Open      Fail  0 pending
#44  fix/baz             Open      Pass  1 resolved
────────────────────────────────────────────────
```

### 3C. Route Comments to Agents

When new comments appear:
1. Read the comment content
2. Identify which PR agent owns that branch
3. Send a message to the agent with the comment text and file/line reference
4. Track that the comment is being addressed

### 3D. Cross-PR Overlap Detection

Watch for comments that affect multiple PRs:
- Architecture feedback that applies broadly
- Style/convention comments that should be consistent
- Merge conflict warnings between branches

If overlap detected, **broadcast** to all affected agents with the shared feedback.

### 3E. Polling Cadence

- **First check**: 2-3 minutes after PRs open (CI usually takes 1-5 min)
- **Subsequent checks**: Every 3-5 minutes while comments are pending
- **Wind down**: Once all PRs show 0 pending comments, do a final check after 5 min

---

## Phase 4: Comment Resolution

When a PR agent receives routed comments, it executes:

### 4A. Evaluate Comments

For each comment, decide:
- **Fix**: Agree and implement the change
- **Discuss**: Disagree but explain reasoning
- **Won't fix**: Explain why (style preference, out of scope, etc.)

### 4B. Fix and Push

```bash
# Make changes
# Stage and commit
git add {{FILES}}
git commit -m "$(cat <<'EOF'
Address review feedback: {{SUMMARY}}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"

# Push
git push
```

### 4C. Reply to Comments

```bash
# Reply to a review comment
gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR_NUMBER}}/comments/{{COMMENT_ID}}/replies \
  -f body="{{REPLY_TEXT}}"

# Reply to a general issue comment
gh api repos/{{OWNER}}/{{REPO}}/issues/comments/{{COMMENT_ID}} \
  -X PATCH -f body="{{UPDATED_BODY}}"
```

### 4D. Report Back

Agent sends message to team lead confirming:
- Which comments were addressed
- What changes were made
- Any comments that need team lead input

---

## Phase 5: Finalization

### 5A. All-Clear Check

All PRs must meet:
- [ ] CI passing (`gh pr checks` all green)
- [ ] No unresolved review comments
- [ ] No pending reviews
- [ ] No merge conflicts

### 5B. Merge Order

If PRs have dependencies, recommend merge order:

```text
MERGE ORDER
───────────
1. #44 fix/baz          (no dependencies, smallest diff)
2. #42 feature/foo      (depends on #44 for clean merge)
3. #43 feature/bar      (independent, largest diff — merge last)
```

Consider:
- **Dependency chains**: If branch B was based on branch A, merge A first
- **Conflict risk**: Merge smallest/simplest first to reduce conflict surface
- **CI re-run**: After each merge, remaining PRs may need CI re-run

### 5C. Shutdown

1. Send shutdown requests to all PR agents
2. Clean up worktrees: `git worktree remove ../repo-worktree-foo`
3. Delete the team: `TeamDelete`

---

## Quick Reference: Key Commands

| Action | Command |
|--------|---------|
| Local lint | `cr review` |
| Push branch | `git push -u origin {{BRANCH}}` |
| Open PR | `gh pr create --title "..." --body "..."` |
| Check CI | `gh pr checks {{PR_NUMBER}}` |
| List reviews | `gh api repos/OWNER/REPO/pulls/PR/reviews` |
| List comments | `gh api repos/OWNER/REPO/pulls/PR/comments` |
| Reply to comment | `gh api repos/OWNER/REPO/pulls/PR/comments/ID/replies -f body="..."` |
| Merge PR | `gh pr merge {{PR_NUMBER}} --squash --delete-branch` |
| Remove worktree | `git worktree remove {{PATH}}` |

## Worktree Tips

- Pre-push hooks may fail in worktrees (no simulator access, etc.) — use `SKIP_PREPUSH=1` after manual build verification
- Each worktree has its own working directory but shares the git object store
- Clean up worktrees after merging to avoid stale references

## Error Recovery

| Problem | Action |
|---------|--------|
| Agent stuck on lint | Check if lint finding is false positive; send agent guidance to skip with justification |
| CI failing on unrelated test | Re-run CI: `gh pr checks {{PR}} --watch` or push empty commit |
| Merge conflict | Rebase agent's branch: send agent instructions to `git rebase main` |
| CodeRabbit not reviewing | Check `.coderabbit.yaml` exists; may need to close/reopen PR |
| Agent idle too long | Send a message to poke the agent; if 2+ stops, analyze feedback patterns |
