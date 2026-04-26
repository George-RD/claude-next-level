# Recovery: cascade-close, retro-split, conflicts, force-push denied

Load this when something has already gone wrong with a stack. Each section is independent — jump to the one that matches your symptom.

## Cascade-close: a stacked PR auto-closed when you merged the one below it

**Symptom.** You merged the bottom PR with `gh pr merge --delete-branch`. The PR stacked on top of it now shows `state: CLOSED, mergeable: CONFLICTING`. `gh pr reopen <N>` fails with `GraphQL: Could not open the pull request.` `gt submit` aborts because the branch was deleted.

**Root cause.** GitHub auto-closes a PR when its base branch is deleted. The base branch was the bottom PR, which `--delete-branch` removed.

**Recovery.** Rebuild on top of fresh trunk and open a "Supersedes #N" PR.

```bash
# 1. Find the dead branch's old base SHA, if you didn't record it before
#    `gt sync --force` reaped tracking. Reflog shows recent HEADs.
git reflog show <dead-branch-name>

# 2. If the local branch still exists, check it out and fork from there.
git checkout <dead-branch-name>
git checkout -b <fresh-branch-name>

# 3. Tell Graphite this branch sits on trunk.
gt track --parent "$(gt trunk)"

# 4. Rebase its commits off the (deleted) old base onto current trunk.
git rebase --onto "$(gt trunk)" <old-base-sha> HEAD

# 5. Submit as a fresh non-draft PR. Mention "Supersedes #N" in the body.
gt submit --publish --no-interactive
```

**Prevention.** For multi-PR stacks under the `gh pr merge` path, either:

- Submit every PR with `--base main` (parallel, not stacked), or
- Use the Graphite merge queue (preferred — handles cascade automatically).

## `gt sync --force` reaped a branch you needed

**Symptom.** A PR closed (merged or auto-closed). You ran `gt sync --no-interactive --force`. Now the local branch is gone and you needed it.

**Recovery.** The commits are still on disk if you saved the SHA before sync.

```bash
git reflog                                # find the lost HEAD
git checkout -b <fresh-branch> <sha>
gt track --parent "$(gt trunk)"
```

**Prevention.** Before `gt sync --force` in any merge session, record the base SHA of every still-relevant upstream branch:

```bash
git rev-parse <branch>~  # save somewhere
```

## Retro-split: a squashed commit needs to become a stack (headless)

**Symptom.** You're on a branch with one large commit that should have been multiple. You're an agent — no interactive staging.

**Why not `gt split`.** `--by-hunk` is interactive only, unusable headlessly. `--by-file` typically over-splits (a phase-sized commit spans `src/`, tests, specs, fixtures).

**Recovery.** Soft-reset to trunk merge-base, then commit each unit selectively.

```bash
# 1. Reset to trunk merge-base. All changes become staged.
git reset --soft "$(git merge-base HEAD "$(gt trunk)")"

# 2. Unstage everything; working tree is untouched.
git reset HEAD

# 3. For each logical unit, stage its files and commit with `gt create -m`.
#    Use -m, NOT -am. -a re-stages everything and collapses the split back
#    into one commit.
git add <files-for-unit-1>
gt create -m "<type>(<scope>): <subject for unit 1>"

git add <files-for-unit-2>
gt create -m "<type>(<scope>): <subject for unit 2>"
# ...continue per logical unit
```

This mirrors the forward path (commit atomically as units land) rather than rescuing a squashed commit mechanically.

## Conflict during `gt restack` or `gt sync`

**Auto-resolve without asking** when the conflict is:

- Whitespace-only or formatter drift
- Non-overlapping additions in the same file (both sides added different hunks at different locations)
- Reordered or added imports **in languages where import order is semantically inert** (JS, TS, Go, most Rust). Skip auto-resolve for Python (`__init__` side effects), Ruby (`require` side effects), or any language with load-time import behaviour.

After any auto-resolve, run the build/test gate before continuing. If it fails, revert and escalate.

**Escalate before acting** on:

- **Same region, different edits** — both sides modified lines N..M in incompatible ways
- **Delete vs modify** — one side deleted a file or block, the other modified it
- **Semantic conflicts** — function signature changed on one side, new caller added on the other using the old signature
- **Test expectation divergence** — both sides changed expected output of the same test
- **Lockfile conflicts** — regenerate the lockfile rather than line-merging it; note chosen versions in PR body

**Recovery commands:**

| Situation | Command |
|---|---|
| Trunk moved; apply stack on new trunk | `gt sync --no-interactive --force` |
| Re-apply stack after any base change | `gt restack` |
| Conflict during restack; resolve then continue | resolve, `git add` the fix, `gt continue` |
| Abort an in-flight restack | `gt abort` (standalone command, not a flag) |

After resolution, run the test suite before submitting. Update the affected PR's description to note the conflict was resolved and what was chosen. If the resolution changed behaviour, add a separate commit via `gt create -m "fix: reconcile conflict from <other-branch>"` rather than hiding the change inside the restack.

## `git push --force-with-lease` denied by the permission layer

**Symptom.** `Permission to use Bash with command "...git push --force-with-lease..." has been denied`, even with `dangerouslyDisableSandbox: true`. Repeats on retry.

**Recovery.** Don't fight the denial. Push to a new branch with a regular non-force push:

```bash
gt create -m "<subject>"               # creates a new branch from current HEAD
gt submit --publish --no-interactive   # regular push, opens a fresh PR
```

If you need the same PR number / URL preserved, you can't — open a new PR and reference the old one ("Supersedes #N").

## `gt submit` complains about no auth

**Symptom.** `gt submit` fails with an auth error. You're an agent — you can't complete browser OAuth.

**Recovery.** Hand off to the user with the exact instruction:

> Graphite isn't authenticated in this environment. Run `gt auth` once (browser OAuth), then I'll continue. If the browser flow fails, `gt auth --reset && gt auth`.

Don't attempt `gt config set github_token` as a workaround — plaintext PATs leak via backups, cloud sync, and shell history.

## Graphite AI review never appears on a non-draft PR

Covered inline in `SKILL.md` under "After submit: poll, then merge" — surface the four likely causes to the user and stop polling rather than waiting forever.
