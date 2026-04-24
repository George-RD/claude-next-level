---
name: graphite-atomic
description: Use when the user mentions Graphite, the `gt` CLI, stacked PRs, atomic commits, or splitting a large change into reviewable pieces, OR when working in a repo that has `.graphite_repo_config` set. Guides agents to produce atomic commits (≤400 lines each) and stacked pull requests via `gt` in Graphite-initialised repos. Worktree-safe. Read references/setup.md before initialising a new project.
---

# Graphite Atomic Commits and Stacked PRs

## When this skill is active

Only in repositories that have been initialised with Graphite. Check before acting:

```bash
test -f "$(git rev-parse --git-common-dir)/.graphite_repo_config"
```

If that command fails or returns no output, the repo is not Graphite-initialised. Use plain `git`. Do not attempt `gt` commands. If the user wants to initialise, read `references/setup.md`.

This check uses `--git-common-dir` instead of `.git/.graphite_repo_config` directly so it works correctly inside git worktrees, where `.git` is a pointer file rather than a directory.

## Core rules

1. **One logical unit per commit.** Target ≤250 lines added+removed. Hard cap ≤400 lines. If a single change is larger, split the logical unit. See `references/commit-sizing.md` for splitting heuristics.
2. **One commit is one PR.** Create each commit with `gt create -am "<subject>"`. Each call adds a new branch and PR to the current stack.
3. **Stack per agent, per worktree.** Each worktree owns its own stack. Never push commits onto another agent's branch. Sync trunk via `gt sync` at phase or wave boundaries, not mid-commit. Full protocol in `references/stack-per-agent.md`.
4. **Prefer `gt` over `git` for branch and history operations.** Plain `git status`, `git log`, `git diff` remain fine. The substitution table is in `references/command-mapping.md`.
5. **Conventional commit subjects.** `<type>(<scope>): <capitalised subject>`. Plain English. No em-dashes. No LLM filler phrases.
6. **Return the Graphite PR URL** (`app.graphite.dev/github/pr/…`), not the GitHub URL, so the user can navigate the stack.
7. **Trunk is whatever `gt trunk` reports.** Never assume `main`. Never assume `dev`. If `gt trunk` returns no value, the repo is not initialised. See the activation rule above.
8. **Amend only for review feedback on the current PR.** `gt modify -a` updates the current branch with staged changes. For anything else, create a new branch with `gt create -am`.

## Typical session

The end-to-end happy path for a stacked-PR session. Run these in order:

```bash
# 1. Pick up trunk before you start (avoids stale-base stacks)
gt sync --no-interactive --force

# 2. Work on the first logical unit. When done, stage ONLY the files
#    that belong in this commit — not the whole tree. Most sessions carry
#    .claude/, graphify-out/, lock files, or scratch edits that must not
#    enter the commit. `gt create -am` would sweep them all in.
git status                           # verify what's modified
git add <files-for-this-unit>        # selective stage
gt create -m "<conv-commit-subject>" # -m, NOT -am — preserves the selection

# 3. Repeat for each additional logical unit in the stack.

# 4. Publish the stack directly as non-draft PRs (CodeRabbit and other
#    reviewers skip drafts):
gt submit --stack --publish --no-interactive
```

`--publish` is load-bearing. Without it `--no-interactive` creates drafts by
default, and you have to run `gh pr ready <N>` after every submit to get
automated reviews running. Always include `--publish` for agent-driven flows.

### Amending on review feedback

```bash
git add <files-for-the-fix>
gt modify -a                          # amend current branch
gt submit --publish --no-interactive  # force-push via Graphite, re-review runs
```

The force-push after `gt modify` is expected — Graphite manages the refspec.
No panic at `+` in the push output.

## Commit boundary in practice

When you have changes staged, before running `git commit` or `gt create`, ask:

1. Does this represent one logical unit that can be described in one conventional-commit subject?
2. Is the diff ≤400 lines?
3. Does the build still pass at this commit?

If all three are yes, commit via `gt create -m` (or `gt create -am` when you
are certain every tracked modification belongs in this commit). If any answer
is no, split or finish the unit first. Worked examples in `references/commit-sizing.md`.

## Retro-split fallback (headless-safe path)

If the current branch already holds one large squashed commit that should have been a stack, the recovery path depends on whether you are interactive or headless.

**Interactive (human at the keyboard):** `gt split --by-hunk` walks through interactive staging.

**Headless (agent session):** `--by-hunk` is unusable (interactive only). `gt split --by-file` works programmatically but typically over-splits, because a phase-sized commit spans many files across `src/`, tests, specs, and fixtures. Prefer this recovery path instead:

```bash
# 1. Reset to the trunk merge-base. All changes become staged.
git reset --soft "$(git merge-base HEAD "$(gt trunk)")"

# 2. Unstage everything; the changes stay in the working tree untouched.
git reset HEAD

# 3. For each logical unit, stage only its files and commit with gt create -m.
#    Use -m, NOT -am. The -a flag re-stages all tracked modifications, which
#    would undo the selective `git add` and collapse the split back into one commit.
git add <files-for-unit-1>
gt create -m "<type>(<scope>): <subject for unit 1>"

git add <files-for-unit-2>
gt create -m "<type>(<scope>): <subject for unit 2>"
# …continue per logical unit.
```

This mirrors the forward path (commit atomically as units land) rather than rescuing a squashed commit mechanically.

## Publishing the stack

Once the stack is ready:

```bash
gt submit --stack --publish --no-interactive
```

Flags:
- `--stack` — submit every branch in the current stack (drop to submit only the current branch).
- `--publish` — create PRs as ready-for-review, not drafts. Without this, CodeRabbit and other AI reviewers skip the PR until someone marks it ready.
- `--no-interactive` — safe in agent sessions; skips prompts.

After submit, return the Graphite PR URL to the user, not the GitHub URL. `gt submit` prints a Graphite URL per branch in its output (format `https://app.graphite.dev/github/pr/<owner>/<repo>/<number>/...`). Extract the URL for the stack tip (or the full list if the user wants to navigate the stack) from the command's stdout; do not fabricate a URL from the PR number and GitHub repo path.

## Merging the stack

Three merge paths, in order of preference. Pick the one that matches your setup.

### Option 1 — Graphite merge queue (web-app feature, preferred for real stacks)

If your org has the Graphite GitHub App installed and the merge queue enabled, toggle "merge when ready" on each stacked PR (via app.graphite.dev) — Graphite merges bottom-up and auto-restacks upstream PRs onto trunk as each one lands. No manual cascade. This is the only merge path that handles a multi-PR stack cleanly. Verify with your org admin before assuming it is available — it is not a CLI command, it is a product feature that requires installation.

### Option 2 — Serial bottom-up via `gh pr merge` + `gt sync`

Works without the merge queue, but has a sharp edge.

```bash
gh pr merge <bottom-PR> --squash --delete-branch
gt sync --no-interactive --force
# repeat for the next PR, now the new bottom
```

**Warning — cascade close.** `--delete-branch` deletes the bottom PR's remote branch. Any stacked PR whose base was that branch is auto-closed by GitHub (its base no longer exists). For multi-PR stacks under this path, either (a) submit every PR with `--base main` instead of stacked, or (b) expect to re-submit each upstream PR after the one below merges (see recovery path below).

**Warning — `gt sync --force` reaps tracking.** After a PR closes (whether merged or auto-closed), `gt sync --force` deletes the local tracking for that branch. If the commits are still on your disk (e.g. an auto-closed upstream PR whose work you want to re-submit), note the branch's old base SHA **before** running `gt sync --force`, because the branch reference itself may be pruned.

### Option 3 — Recovery from auto-closed stacked PR

Your upstream PR auto-closed when its base branch was deleted. The commits still exist but the PR is dead and cannot be reopened. Rebuild on top of fresh trunk:

```bash
# 1. Find the old base SHA if you didn't record it before gt sync --force.
#    Reflog for the dead branch shows its recent HEADs.
git reflog show <dead-branch-name>

# 2. Create a fresh branch from the current HEAD of the dead one.
git checkout <dead-branch-name>      # if it still exists locally
git checkout -b <fresh-branch-name>

# 3. Tell Graphite this branch sits on main.
gt track --parent main

# 4. Rebase its commits off the (deleted) old base onto current main.
git rebase --onto main <old-base-sha> HEAD

# 5. Submit as a fresh non-draft PR.
gt submit --publish --no-interactive
```

`gt track` only updates tracking metadata — it accepts whatever shape git reports, so rebasing before or after is fine. The old base SHA is the one thing that must not be lost; keep it recorded before any `gt sync --force` in a merge session.

## Conflicts

- Auto-resolve where safe: whitespace, formatting, non-overlapping additions, and imports *in languages where import order is semantically inert*.
- Escalate: same region edited differently, delete-vs-modify, semantic conflicts, test-expectation divergence, lockfile conflicts.

Full policy in `references/conflict-resolution.md`.

## Setting up a new project

Read `references/setup.md`. It covers installing `gt`, running `gt init --trunk <trunk>` with a version gate, `gt auth` via browser OAuth (credential-safe), anchoring the skill directive in the project's `CLAUDE.md`, the optional protective PreToolUse hook (fail-closed pattern), and consumer clauses for cflx `apply_prompt` and sauron waves.

## Speed tips

Review cycles iterate quickly when you skip gates that don't add signal:

- **`SKIP_PREPUSH=1 gt submit …`** — on repos where the pre-push hook runs an iOS/Xcode build or other heavy suite, skip it for pure-backend (e.g. Supabase edge-function) stacks. The full build gates the iOS side, not backend correctness. Only skip when you know the diff doesn't touch the iOS side.
- **`SKIP_AI_REVIEW=1 gt create … / gt modify …`** — during a batch session where you are about to make several commits and already ran type-check / tests locally, per-commit AI review on the staged diff is redundant. The PR-level review will still run. Project CLAUDE.md typically documents when this is acceptable.
- **Amend-then-submit is one round trip.** Stage all review-fix edits, `gt modify -a` once, `gt submit --publish --no-interactive` once. Don't `gt modify` after each individual fix in the same round — every `gt submit` triggers a force-push plus a ~2-3 min pre-push gate.

## Quick reference

| Intent | Command |
|---|---|
| Start new branch + commit (selective stage — default) | `git add <files>; gt create -m "<subject>"` |
| Start new branch + commit (sweep all tracked changes) | `gt create -am "<subject>"` |
| Amend the current PR | `git add <files>; gt modify` (or `gt modify -a` to sweep) |
| Add another commit on the same branch | `gt modify -c -am "<subject>"` |
| Publish the whole stack as non-draft PRs | `gt submit --stack --publish --no-interactive` |
| Pull trunk and restack | `gt sync --no-interactive --force` |
| Show the stack | `gt log` |
| Navigate up/down | `gt up` / `gt down` |
| Track an untracked branch | `gt track --parent <trunk-or-parent>` |
| Split an existing commit (headless) | See "Retro-split fallback" above |
| Recover an auto-closed stacked PR | See "Merging the stack → Option 3" above |

Full table with notes in `references/command-mapping.md`.
