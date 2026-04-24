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

## Commit boundary in practice

When you have changes staged, before running `git commit` or `gt create`, ask:

1. Does this represent one logical unit that can be described in one conventional-commit subject?
2. Is the diff ≤400 lines?
3. Does the build still pass at this commit?

If all three are yes, commit via `gt create -am`. If any is no, split or finish the unit first. Worked examples in `references/commit-sizing.md`.

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
gt submit --stack --no-interactive
```

The `--no-interactive` flag skips prompts, safe in non-interactive agent sessions. Drop `--stack` to update only the current branch.

After submit, return the Graphite PR URL to the user, not the GitHub URL. `gt submit` prints a Graphite URL per branch in its output (format `https://app.graphite.dev/github/pr/<owner>/<repo>/<number>/...`). Extract the URL for the stack tip (or the full list if the user wants to navigate the stack) from the command's stdout; do not fabricate a URL from the PR number and GitHub repo path.

## Conflicts

- Auto-resolve where safe: whitespace, formatting, non-overlapping additions, and imports *in languages where import order is semantically inert*.
- Escalate: same region edited differently, delete-vs-modify, semantic conflicts, test-expectation divergence, lockfile conflicts.

Full policy in `references/conflict-resolution.md`.

## Setting up a new project

Read `references/setup.md`. It covers installing `gt`, running `gt init --trunk <trunk>` with a version gate, `gt auth` via browser OAuth (credential-safe), anchoring the skill directive in the project's `CLAUDE.md`, the optional protective PreToolUse hook (fail-closed pattern), and consumer clauses for cflx `apply_prompt` and sauron waves.

## Quick reference

| Intent | Command |
|---|---|
| Start new branch + commit | `gt create -am "<subject>"` |
| Amend the current PR | `gt modify -a` |
| Add another commit on the same branch | `gt modify -c -am "<subject>"` |
| Publish the whole stack | `gt submit --stack --no-interactive` |
| Pull trunk and restack | `gt sync` |
| Show the stack | `gt log` |
| Navigate up/down | `gt up` / `gt down` |
| Split an existing commit (headless) | See "Retro-split fallback" above |

Full table with notes in `references/command-mapping.md`.
