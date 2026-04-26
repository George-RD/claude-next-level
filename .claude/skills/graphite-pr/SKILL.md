---
name: graphite-pr
description: Use this skill when working in a repo that uses Graphite (the `gt` CLI) for stacked PRs. Activates whenever the git common dir contains `.graphite_repo_config`, the project's CLAUDE.md mentions Graphite or `graphite-pr`, or the user mentions `gt`, stacked PRs, atomic commits, or splitting a change into reviewable pieces. Drives the daily commit → submit → review → merge loop and the rules for sizing atomic commits. To bootstrap Graphite in a new repo, read `references/setup.md` first.
---

# graphite-pr

Activates when this prints `OK`:

```bash
test -f "$(git rev-parse --git-common-dir)/.graphite_repo_config" && echo OK
```

Otherwise use plain `git`. New repo? See `references/setup.md`.

## Rule of the road

`gt` owns branch state. Every branch, commit, and push goes through `gt create` / `gt modify` / `gt submit`. Plain `git status`, `git log`, `git diff`, `git add`, `git reset`, `git stash` stay fine. Raw `git commit` / `git push` / `git checkout -b` / `git branch -D` bypass Graphite's metadata and corrupt the stack.

**One actor per stack.** Two delegation patterns:

- **Helper subagents on one stack** — orchestrator runs `gt`; subagents return file edits.
- **Parallel stacks** — each subagent owns its own worktree and runs `gt` itself, following this skill. Dispatch in `references/multi-worktree.md`.

What never works: two actors on the same stack in the same worktree.

## Default to serial PRs

Open one PR, merge, open the next. Stack only when rung B genuinely can't land without rung A. Independent units don't share a stack just because you're working on them in the same session.

## The 90% loop

```bash
# 1. Sync trunk (avoids stacks on a stale base).
gt sync --no-interactive --force

# 2. Edit. Stage only files for THIS commit.
git status
git add <files-for-this-unit>
gt create -m "<type>(<scope>): <subject>"

# 3. Repeat step 2 per logical unit.

# 4. Publish as non-draft (auto-review skips drafts).
gt submit --stack --publish --no-interactive
```

`--publish` is what makes auto-review run. `gt submit` prints a Graphite URL per branch (`https://app.graphite.dev/github/pr/...`) — return that to the user, not the GitHub URL.

## Sizing each commit

One commit = one logical unit titled in a single conventional-commit subject, that reverts cleanly, that leaves the build green.

- **Target**: ≤250 lines added+removed
- **Hard cap**: ≤400 lines
- **Mechanical exception**: lockfile bumps, generated code, bulk renames may exceed the cap — tag with `chore:` and note "mechanical" in the PR body.

When >400 lines, split by the first heuristic that fits:

1. **Interface before implementation** — types/signatures first, body second.
2. **Scaffolding before behaviour** — empty module first, fill it in next.
3. **Tests before wiring** — ignored tests first, implement + un-ignore next.
4. **Refactor before change** — behaviour-preserving move first, behaviour change next.
5. **Mechanical before semantic** — rename/regen first, meaningful change next.

Worked examples in `references/sizing.md`.

## Amending on review feedback

```bash
git add <files-for-the-fix>
gt modify -a                          # amend current branch
gt submit --publish --no-interactive  # force-push via gt; review re-runs
```

Batch all review fixes into one `gt modify -a` + `gt submit` to avoid multiple round-trips through the pre-push gate.

Amend (`gt modify -a`) for fixes to *this* PR. If the reviewer asks for new scope, that's a new commit on top: `git add <files>; gt create -m "<subject>"`.

## After submit: poll, then merge

The merge gate is `Graphite / AI Reviews`. Poll:

```bash
gh pr view <N> --json statusCheckRollup
```

`/loop 1m` or `/loop 3m` works for cadence — query `statusCheckRollup` and act when the check goes SUCCESS.

If the check hasn't appeared a few minutes after a non-draft PR, surface this before continuing to wait:

> Graphite auto-review isn't running on PR #N. Likely cause: (1) PR is still draft → `gh pr ready <N>`. (2) Graphite GitHub App not installed in the org. (3) PR exceeds size threshold (~1500+ lines, SIZE_GATED). (4) Repo opted out at app.graphite.dev. Pick one before I keep polling.

Once green, merge by one of:

1. **Graphite merge queue** (preferred for stacks) — toggle "merge when ready" on each PR at app.graphite.dev. Merges bottom-up and auto-restacks. Requires the Graphite GitHub App.
2. **Bottom-up `gh pr merge`**:

   ```bash
   gh pr merge <bottom-PR> --squash --delete-branch
   gt sync --no-interactive --force
   # repeat for the next bottom
   ```

   `--delete-branch` cascade-closes any PR stacked on top. To avoid: submit every PR with `--base $(gt trunk)` instead. To recover after cascade: `references/recovery.md`.
3. **Single PR**: `gh pr merge <N> --squash --delete-branch`.

Before `gt sync --force` after a closed PR, record any branch SHA you might still need (`git rev-parse <branch>~`) — sync deletes local tracking for closed branches.

## Quick reference

| Intent | Command |
|---|---|
| New branch + commit (selective stage) | `git add <files>; gt create -m "<subject>"` |
| Amend the current PR | `git add <files>; gt modify -a` |
| Reviewer asks for new scope (not a fix to this PR) | `git add <files>; gt create -m "<subject>"` |
| Publish whole stack as non-draft PRs | `gt submit --stack --publish --no-interactive` |
| Pull trunk and restack | `gt sync --no-interactive --force` |
| Show the stack | `gt log` |
| Trunk name (use, don't assume) | `gt trunk` |
| Track an untracked branch | `gt track --parent "$(gt trunk)"` |
| Continue after conflict resolution | `gt continue` |
| Abort an in-flight restack | `gt abort` |

Full git→gt mapping in `references/command-mapping.md`.

## When to load a reference

| Situation | Load |
|---|---|
| Setting up Graphite in a new repo | `references/setup.md` |
| PR auto-closed when you merged the one below it | `references/recovery.md` (cascade-close) |
| Retro-split a big squashed commit headlessly | `references/recovery.md` (split) |
| Conflict during `gt restack` or `gt sync` | `references/recovery.md` (conflicts) |
| `gt submit` fails with an auth error | `references/recovery.md` (auth handoff) |
| Working alongside another agent in another worktree | `references/multi-worktree.md` |
| Full git→gt translation table | `references/command-mapping.md` |
| Splitting work >400 lines and the heuristics aren't enough | `references/sizing.md` |

## When this skill is wrong

When reality contradicts this skill — failed command, wrong flag, missed recovery — flag it and propose the edit:

> Skill mismatch in `graphite-pr`. Skill says: "<quoted line>". Reality: <what happened>. Suggested edit: <change>. Apply?
