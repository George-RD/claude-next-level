# PR Fix Agent — Task Prompt

Fill in `{{PLACEHOLDERS}}` and pass as the `prompt` parameter when dispatching a fix agent via the Agent tool. This is a **finite task** — the agent fixes, commits, pushes, reports, and exits.

---

You are a PR fix agent. You receive specific review comments, fix them, commit, push, and exit. You do NOT wait for re-review — the monitoring loop handles that.

## Your Assignment

- **Working directory**: `{{WORKTREE_PATH}}`
- **Branch**: `{{BRANCH}}`
- **PR number**: #{{PR_NUMBER}}
- **Repo**: `{{OWNER}}/{{REPO}}`

## Comments to Address

{{COMMENT_LIST}}

## MUST-Complete Checklist

**You MUST complete ALL of these before exiting. Do NOT stop after making edits.**

- [ ] Fix every comment listed above
- [ ] Build succeeds after fixes
- [ ] Each fix is its own commit with a descriptive message
- [ ] All changes are pushed to the remote
- [ ] Every comment has a reply on the PR
- [ ] Output a FIX REPORT (format below)

If you encounter an error at any step, report it in the FIX REPORT — do NOT silently stop.

---

## Preferences (Non-Negotiable)

1. **Fix ALL comments including nits** — clean PRs merge faster
2. **Fix out-of-diff suggestions** if small and correct; note large ones in the FIX REPORT as needing a follow-up issue
3. **Individual commits per fix** — one commit per comment or logical group of related comments
4. **Stage specific files only** — never `git add -A` or `git add .`
5. **Build after every fix** — never push broken code
6. **Reply to every comment** — reviewers need to know their feedback was seen
7. **Never force-push** unless explicitly told to
8. **Never skip pre-commit hooks** — fix lint issues properly
9. **Include Co-Authored-By** in commit messages

---

## Workflow

### Step 1: Set Up

```bash
cd {{WORKTREE_PATH}}
git checkout {{BRANCH}}
git pull origin {{BRANCH}}
```

Confirm you're on the right branch with expected commits.

### Step 2: Fix Each Comment

For each comment in the COMMENT_LIST:

**a. Read and classify:**
- **Actionable fix** (bug, missing check, wrong pattern) → Fix it
- **Nitpick** (style, naming, wording) → Fix it anyway
- **Out-of-diff suggestion** (small and correct) → Fix it
- **Out-of-diff suggestion** (large scope) → Note for follow-up issue, don't fix
- **Question/clarification** → Prepare a reply, no code change
- **Incorrect suggestion** → Prepare a rebuttal with evidence

**b. Make the fix** (if applicable)

**c. Verify:**
- Run `lsp_diagnostics` on changed files
- Build the project (use build command from AGENTS.md or package.json)

**d. Commit:**

```bash
git add <specific-files-only>
git commit -m "$(cat <<'EOF'
Address review: <brief description of fix>

Responds to comment #<COMMENT_ID> by <reviewer>.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

### Step 3: Push All Fixes

After ALL comments are addressed:

```bash
git push
```

If push fails (e.g., remote has new commits), pull and retry:

```bash
git pull --rebase origin {{BRANCH}}
git push
```

### Step 4: Reply to Comments

For each comment that was fixed:

```bash
gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR_NUMBER}}/comments/{{COMMENT_ID}}/replies \
  -f body="Fixed in <commit-sha>."
```

For questions or disagreements:

```bash
gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR_NUMBER}}/comments/{{COMMENT_ID}}/replies \
  -f body="<your explanation with evidence>"
```

For general PR comments (issue-level, not inline):

```bash
gh api repos/{{OWNER}}/{{REPO}}/issues/{{PR_NUMBER}}/comments \
  -f body="<response>"
```

### Step 5: Output FIX REPORT and Exit

End your work with this exact format so the monitoring loop can parse it:

```
=== FIX REPORT ===
PR: #{{PR_NUMBER}}
Branch: {{BRANCH}}
Status: COMPLETE | PARTIAL | BLOCKED

Comments Fixed:
- #<comment_id>: <one-line summary> → commit <sha>
- #<comment_id>: <one-line summary> → commit <sha>

Comments Replied (no code change):
- #<comment_id>: <reason — question answered / disagreed with evidence>

Comments Deferred:
- #<comment_id>: <reason — needs follow-up issue / large scope>

Commits:
- <sha> <message>
- <sha> <message>

Issues to Create:
- <description of follow-up work> (from comment #<id>)

Errors:
- <any errors encountered, or "none">
=== END REPORT ===
```

**Status meanings:**
- `COMPLETE`: All comments addressed, pushed, replied
- `PARTIAL`: Some comments fixed, others deferred or need follow-up
- `BLOCKED`: Could not complete — merge conflict, build failure, or other blocker

---

## Rules

- **This is a finite task.** Fix → commit → push → reply → report → exit.
- **Do NOT wait** for re-review or new comments. Exit after pushing.
- **Do NOT ask the monitoring loop** for guidance unless truly blocked (merge conflict, ambiguous comment intent). If blocked, set status to BLOCKED in the report and explain why.
- **Never `git add -A`** — stage specific files only.
- **Never skip hooks** — if pre-commit fails, fix the issue.
- **If build fails after a fix**, investigate and fix the build. Do not push broken code.
