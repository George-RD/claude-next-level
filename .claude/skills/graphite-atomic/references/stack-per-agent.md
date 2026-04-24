# Stack Per Agent: Multi-Worktree Collaboration

## The model

Each agent operates in its own git worktree and owns its own stack. Agents coordinate through trunk, never by pushing onto each other's branches.

## Rules

1. **One stack per worktree.** When an agent starts work in a worktree, it creates one stack there and grows it with `gt create -am`. It never interleaves branches from another agent's stack into its own.
2. **Trunk is the meeting point.** When agent A's stack merges to trunk, agent B pulls it in via `gt sync` in its worktree. Cross-agent changes travel only through trunk.
3. **`gt sync` runs per worktree.** Graphite state is worktree-local. Syncing in one worktree does not sync another. Run `gt sync` at phase or wave boundaries, not mid-commit.
4. **Never push to another agent's branch.** If agent B needs something from agent A's unmerged stack, wait for A's stack to merge, then `gt sync` to pick it up. Do not force-push or amend A's branch from B's worktree.
5. **Branch naming carries owner.** Prefix branches with a consumer-specific identifier to prevent accidental overwrites and make `gt log` readable. Examples by consumer:
   - cflx phases use the phase slug: `phase-8/summariser-scaffold`
   - sauron waves use the wave slug: `wave-3/auth-refactor`
   - freeform work uses a task identifier: `bug-123/fix-deadlock`
   - solo single-worktree work may omit the prefix: `summariser-scaffold`

## When stacks collide at trunk

Two agents merge overlapping work. Possible outcomes:

- **Whichever merges first wins.** The second agent's `gt sync` reveals the conflict.
- **Resolve in the losing agent's worktree** via `gt restack`. Never resolve by force-pushing the merged agent's work.
- **Semantic conflict** (both touched the same API in incompatible ways): pause and escalate to the human orchestrator. This is not a `gt` problem; it is a coordination problem.

## Worktree gotchas

These come from Graphite's own worktree support documentation.

- `gt sync` or `gt get` may update the local trunk even if trunk is checked out in another worktree. This is the one documented cross-worktree side effect. Expect it rather than fighting it.
- `gt modify --into <branch>` refuses to operate on a branch currently checked out in another worktree. Finish the change in the owner worktree.
- `gt undo` history is per-worktree; undoing in worktree A does not undo in worktree B.
- Never operate the same stack from two worktrees simultaneously. If `git worktree list` shows the same branch checked out in two worktrees, reconcile by switching one worktree to a different branch (`cd <other-worktree> && git checkout <other-branch-or-trunk>`), then resume work in the remaining worktree. Do not continue committing until only one worktree holds the target branch.

## Single-agent today, ready for multi-agent tomorrow

This skill treats single-agent work as the one-worktree case of the multi-agent model. No rule here creates overhead when there is only one agent. When a second agent joins, the protocol is already in place. No redesign required.

## Checklist before submitting a stack

Before running `gt submit --stack --no-interactive`:

1. `gt log` shows the expected branch sequence rooted on the correct trunk.
2. No branch in the stack is also checked out in a different worktree.
3. `gt sync` is up to date (trunk has not moved under you during the session).
4. Each branch in the stack passes its independent build or test gate.
5. No branch has a commit over the 400-line hard cap without a `chore:` exception note.
