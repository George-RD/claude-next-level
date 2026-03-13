---
name: pr
description: Monitor one or more PRs through review lifecycle — fix comments, push, repeat until clean, merge. Supports single PR, multiple PRs, or --all.
argument-hint: "[pr-number...] or --all"
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

# /cycle:pr

Monitor one or more PRs through their full review lifecycle: wait for reviews, address all comments, push fixes, repeat until clean, then merge.

## Usage

```bash
/cycle:pr [pr-number...]
/cycle:pr 42
/cycle:pr 42 43 44
/cycle:pr --all
```

## Arguments

- One or more PR numbers: `42`, `42 43 44`
- `--all`: Find all open PRs authored by the current user in this repo
- No arguments: Use the most recent PR on the current branch

$ARGUMENTS

---

## Preferences (Non-Negotiable Defaults)

These rules apply to ALL PR cycle operations. Do NOT deviate without explicit user override.

1. **Fix ALL comments including nits** — clean PRs merge faster and build reviewer trust
2. **Fix out-of-diff suggestions** if small and correct; file GitHub issues for large ones
3. **Individual commits per fix** — don't squash during the cycle; helps reviewers verify their feedback was addressed
4. **First poll at 2-3 min** after push, subsequent polls every 3-5 min
5. **Max 5 review rounds** per PR before escalating to user
6. **Squash merge** with `--delete-branch`
7. **After merge**: `git checkout main && git pull`
8. **Run autonomously** — do NOT stop and ask between cycles
9. **Only ask when truly blocked** (merge conflicts, branch protection, ambiguous reviewer intent)
10. **For parallel agents**: use worktrees for isolation — agents sharing git fight
11. **CodeRabbit converges** after ~3 rounds typically
12. **Reply to every comment** — reviewers need to know their feedback was seen
13. **Build after every fix** — never push broken code
14. **Stage specific files** — never `git add -A` or `git add .`

---

## Mode Selection

### Single-PR Mode (1 PR)

When given one PR number (or none, defaulting to current branch):

1. Identify the PR
2. Poll for CI + reviews
3. Address all comments
4. Push fixes
5. Re-poll for new comments
6. Repeat until clean
7. Merge

### Multi-PR Mode (2+ PRs)

When given multiple PR numbers or `--all`:

1. Gather all PR metadata
2. Run centralized monitoring loop
3. Dispatch fix agents per PR (one at a time for same-repo, parallel for worktrees)
4. Track progress on dashboard
5. Merge in dependency order when clean

---

## Single-PR Workflow

### 1. Identify the PR

```bash
# If pr-number provided:
gh pr view <PR_NUMBER> --json number,title,state,headRefName,reviewDecision,statusCheckRollup,url

# If no pr-number, find PR for current branch:
gh pr view --json number,title,state,headRefName,reviewDecision,statusCheckRollup,url
```

If no PR exists, stop and tell the user.

### 2. Wait for CI + Reviews

Poll until at least one review bot has commented OR CI checks complete:

```bash
gh pr checks $PR_NUMBER --watch --fail-fast
```

Then fetch all review comments:

```bash
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/reviews
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments
gh pr view $PR_NUMBER --json comments,reviews,reviewDecision
```

**Polling cadence**: First check at 2-3 min after push. Subsequent checks every 3-5 min.

### 3. Categorize and Address ALL Comments

For every unresolved comment (CodeRabbit, human reviewers, CI failures):

**a. Read the comment carefully.** Understand what's being asked.

**b. Classify:**

- **Actionable fix** (bug, missing check, wrong pattern) → Fix it
- **Nitpick** (style, naming, wording) → Fix it anyway. Clean PRs merge faster.
- **Out-of-diff suggestion** (reviewer suggests changes to code not in this PR) → Fix it if it's small and correct. If it's a large scope change, create a GitHub issue for follow-up.
- **Question/clarification** → Reply with a clear answer on the PR
- **Incorrect suggestion** → Reply explaining why, with evidence from the codebase

**c. For each fix:**

1. Make the code change
2. Run `lsp_diagnostics` on changed files
3. Build to verify (use the project's build command from AGENTS.md or package.json)
4. Stage specific files only: `git add <file1> <file2>` — never `git add -A`
5. Commit with a descriptive message referencing the review comment
6. Do NOT squash — individual fix commits help reviewers verify their feedback was addressed

**d. After all comments addressed:**

```bash
git push
```

### 4. Reply to Review Comments

After pushing fixes, reply to each addressed comment on the PR:

```bash
# For inline review comments:
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments/$COMMENT_ID/replies \
  -f body="Fixed in <commit-sha>"

# For general PR comments:
gh api repos/{owner}/{repo}/issues/$PR_NUMBER/comments \
  -f body="Addressed — <brief summary of fixes>"
```

For questions or disagreements, reply with context. **Reply to every comment** — reviewers need to know their feedback was seen.

### 5. Re-check for New Comments

Wait 2-3 minutes for bots to re-review, then:

```bash
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments --jq '[.[] | select(.created_at > "LAST_CHECK_TIME")] | length'
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/reviews --jq '[.[] | select(.submitted_at > "LAST_CHECK_TIME")] | length'
```

If new comments exist → Go to Step 3.
If no new comments → Proceed to Step 6.

**Round tracking**: Increment round counter each cycle. If round > 5, stop and escalate to user.

### 6. Verify Clean State

Before merging, confirm:

- [ ] All CI checks pass: `gh pr checks $PR_NUMBER`
- [ ] No unresolved review comments
- [ ] No "Changes requested" review status
- [ ] Build succeeds locally
- [ ] Tests pass (if applicable)

### 7. Merge

```bash
gh pr merge $PR_NUMBER --squash --delete-branch
```

If merge fails (branch protection, conflicts), report the blocker — don't retry blindly.

After merge:

```bash
git checkout main && git pull
```

---

## Multi-PR Workflow

### 1. Gather PRs

```bash
# If --all:
gh pr list --author @me --state open --json number,title,headRefName,url,additions,deletions

# If specific numbers:
gh pr view <N> --json number,title,headRefName,url,additions,deletions  # for each
```

Build a tracking table:

```text
PR DASHBOARD
────────────────────────────────────────────────────────────────
PR    Branch                State     CI     Round  Comments
#42   feature/foo           open      -      0      -
#43   feature/bar           open      -      0      -
#44   fix/baz               open      -      0      -
────────────────────────────────────────────────────────────────
```

### 2. Detect Worktree Availability

```bash
git worktree list
```

If PRs have associated worktrees, note the paths — fix agents will use them for isolation.
If no worktrees are available, process fix agents **serially** (one at a time) to avoid git conflicts.

### 3. Centralized Monitoring Loop

Poll all PRs in a batch:

```bash
# For each PR:
gh pr checks <PR_NUMBER>
gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments --jq 'length'
gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/reviews --jq '[.[] | select(.state != "COMMENTED")] | length'
```

**Polling cadence**:
- First poll: 2-3 min after PRs were pushed
- Subsequent: every 3-5 min while any PR has pending comments
- Wind down: one final check 5 min after last activity

### 4. Dispatch Fix Agents

When a PR has unresolved comments, dispatch a background agent to fix them.

**Agent dispatch pattern** (using the Agent tool):

```
Agent tool call:
  description: "Fix PR #<N> review comments"
  prompt: <filled pr-agent-prompt template>
  subagent_type: "general-purpose"
  run_in_background: true
```

The agent prompt template is at:
`${CLAUDE_PLUGIN_ROOT}/skills/cycle/templates/pr-agent-prompt.md`

Fill in the template placeholders:
- `{{WORKTREE_PATH}}`: The worktree path for this branch (or repo root if no worktree)
- `{{BRANCH}}`: The PR's head branch name
- `{{PR_NUMBER}}`: The PR number
- `{{OWNER}}` / `{{REPO}}`: Repository owner and name
- `{{COMMENT_LIST}}`: The actual review comments to address, formatted as:
  ```
  Comment #<id> by <reviewer> on <file>:<line>:
  > <comment body>
  ```

**Dispatch rules**:
- With worktrees: dispatch agents in parallel (each has its own working directory)
- Without worktrees: dispatch one agent at a time, wait for completion before next
- Never dispatch a new agent for a PR that already has one running

### 5. Track Agent Progress

Per-PR state machine:

```
open → fixing → pushed → polling → [open|clean]
                                       ↓
                                    merged
```

States:
- **open**: Has unresolved comments, no agent dispatched
- **fixing**: Agent dispatched and working
- **pushed**: Agent pushed fixes, waiting for re-review
- **polling**: Checking for new comments after push
- **clean**: All checks pass, no pending comments
- **merged**: Successfully merged

Update the dashboard after each poll cycle.

### 6. Merge in Order

When PRs reach **clean** state, merge in this order:

1. **Dependency chains first**: If PR B was branched from PR A, merge A first
2. **Smallest diff next**: Fewer changes = less conflict risk for remaining PRs
3. **After each merge**: Wait for remaining PRs' CI to re-run (base branch changed)

```bash
gh pr merge <PR_NUMBER> --squash --delete-branch
```

After all merges:

```bash
git checkout main && git pull
```

### 7. Exit Conditions

- **All merged** → Print summary table, report SUCCESS
- **Any PR hits round 5** with unresolved comments → Stop that PR, escalate to user, continue others
- **Agent fails** (can't fix, blocked) → Mark PR as blocked, continue others
- **All PRs blocked or merged** → Print final status, exit

### 8. Cleanup

If worktrees were used:

```bash
git worktree remove <path>  # for each worktree
```

---

## Cross-PR Intelligence

When monitoring multiple PRs, watch for:

- **Same feedback on multiple PRs**: A style or convention comment that applies broadly → apply the fix to all affected PRs, not just the one where it was raised
- **Merge conflicts between PRs**: If two PRs touch the same files → merge the simpler one first, then rebase the other
- **Architecture feedback**: If a reviewer suggests a structural change → evaluate whether it affects other PRs before dispatching a narrow fix

---

## Cycle Limits

- **Max rounds per PR**: 5 (escalate to user after that)
- **Max wait per poll**: 5 minutes
- **Total timeout**: None — keep going until all PRs are merged or escalated
- **CodeRabbit convergence**: Typically 2-3 rounds; if still getting new comments after 3, check for a pattern

## Pre-commit Hook Notes

- If pre-commit hooks exist, respect them — fix lint issues, don't skip with `--no-verify`
- If a hook fails due to external service (rate limits, auth), it's OK as long as the hook still passes overall
- If pre-push hooks run tests you've already verified this session, check for a skip env var (e.g., `SKIP_PREPUSH=1`)

## Error Recovery

| Problem | Action |
|---------|--------|
| Agent stops after editing without committing | Resume agent with explicit instruction to commit and push |
| CI failing on unrelated test | Re-run CI: `gh run rerun --failed` or push empty commit |
| Merge conflict | Rebase the PR branch on main; if complex, escalate to user |
| CodeRabbit not reviewing | Check `.coderabbit.yaml` exists; close and reopen PR |
| Reviewer requests large refactor | Create a follow-up issue; don't block the PR |
| Agent dispatched but no output | Wait 5 min, then check agent status; redispatch if needed |
