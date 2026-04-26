# Multi-worktree: parallel stacks across subagents

Load this when you want to run **two or more stacked-PR workflows in parallel**, each in its own subagent. Single-agent sessions can ignore this file.

## The model

Each subagent owns one worktree and one stack. Subagents coordinate through trunk, never by pushing onto each other's branches. The orchestrator dispatches subagents but does not run `gt` against their stacks — each subagent runs its own.

This is Pattern B from the "Rule of the road" in `SKILL.md`. Pattern A (helper subagents on a single stack) doesn't need this file — the orchestrator just runs `gt` itself.

## Dispatch recipe

For each parallel workflow:

```bash
# 1. Create a worktree from current trunk on a fresh branch.
git worktree add ../w-<task-slug> -b <task-slug>/scaffold "$(gt trunk)"
```

2. Spawn the subagent with `cwd: ../w-<task-slug>` and a task brief that **explicitly tells it to follow the `graphite-pr` skill** for all commit and submit operations. The subagent will activate `graphite-pr` from `.graphite_repo_config` (shared across worktrees) and operate its own stack from there.

3. The subagent runs the standard 90% loop in its worktree: `gt sync` → `git add` → `gt create -m` → repeat → `gt submit --stack --publish --no-interactive`.

4. The subagent returns the Graphite stack URLs to the orchestrator. The orchestrator coordinates polling and merge.

## Cleanup after a parallel run

When all stacks have merged (or been abandoned), reap worktrees and dead branches from the orchestrator:

```bash
git worktree list                          # see what's still around
git worktree remove ../w-<task-slug>       # per stack, when its branches are merged or you no longer need them
git worktree prune                         # clean up any stale entries
```

## Rules

1. **One stack per worktree.** When an agent starts work in a worktree, it creates one stack there and grows it with `gt create`. Never interleave branches from another agent's stack.
2. **Trunk is the meeting point.** When agent A's stack merges to trunk, agent B pulls it in via `gt sync` in its worktree. Cross-agent changes travel only through trunk.
3. **`gt sync` runs per worktree.** Graphite state is worktree-local. Syncing in one worktree does not sync another. Run `gt sync` at phase / wave boundaries, not mid-commit.
4. **Never push to another agent's branch.** If agent B needs something from agent A's unmerged stack, wait for A's stack to merge, then `gt sync` to pick it up. Do not force-push or amend A's branch from B's worktree.
5. **Branch naming carries owner.** Prefix branches with a consumer-specific identifier so `gt log` is readable and accidental overwrites are obvious:
   - phase-based work: `phase-8/summariser-scaffold`
   - wave-based work: `wave-3/auth-refactor`
   - bug fixes: `bug-123/fix-deadlock`
   - solo work in a single worktree: prefix may be omitted

## Why subagents can run gt safely here (and not in Pattern A)

`gt` is worktree-aware. The shared `.graphite_repo_config` lives in the git common dir, but each worktree has its own checked-out branch and its own working tree. As long as no two actors operate the same branch at the same time, two subagents in two worktrees running `gt create` / `gt submit` in parallel is fine — Graphite's per-branch metadata stays consistent because writes are serialised per branch.

Pattern A (helper subagent on one stack) bans subagent-run `gt` because the helper subagent and the orchestrator share a worktree. Pattern B (this file) permits it because each subagent has its own.

## When stacks collide at trunk

Two agents merge overlapping work. Outcomes:

- **Whichever merges first wins.** The second agent's `gt sync` reveals the conflict.
- **Resolve in the losing agent's worktree** via `gt restack`. Never resolve by force-pushing the merged agent's work.
- **Semantic conflict** (both touched the same API in incompatible ways): pause and escalate to the human orchestrator. This is a coordination problem, not a `gt` problem.

## Worktree gotchas

From Graphite's worktree support docs and observed behaviour:

- `gt sync` or `gt get` may update the local trunk even if trunk is checked out in another worktree. The one documented cross-worktree side effect — expect it.
- `gt modify --into <branch>` refuses to operate on a branch currently checked out in another worktree. Finish the change in the owner worktree.
- `gt undo` history is per-worktree; undoing in worktree A doesn't undo in worktree B.
- Never operate the same stack from two worktrees simultaneously. If `git worktree list` shows the same branch checked out in two worktrees, reconcile by switching one to a different branch (`cd <other-worktree> && git checkout <other-branch-or-trunk>`), then resume work in the remaining worktree.
- Worktree cleanup: at session end, ensure no agent worktrees are left locked. `git worktree list` shows them; `git worktree remove --force <path>` if needed.

## Checklist before submitting a stack

Before `gt submit --stack --publish --no-interactive`:

1. `gt log` shows the expected branch sequence rooted on the configured trunk.
2. No branch in the stack is also checked out in a different worktree.
3. `gt sync` is up to date (trunk hasn't moved during the session).
4. Each branch in the stack passes its independent build/test gate.
5. No branch has a commit over the 400-line hard cap without a `chore:` exception note.
