# Conflict Resolution Policy

## Auto-resolve without asking

Apply a mechanical resolution and continue when the conflict is:

- Reordered or added imports **in languages where import order is semantically inert** (JavaScript, TypeScript, Go, most Rust). Skip auto-resolve for Python (`__init__` side effects), Ruby (`require` side effects), or any language where imports carry load-time behaviour.
- Whitespace-only differences
- Non-overlapping additions in the same file (both sides added different hunks at different locations)
- Formatting changes (reformat on save, auto-formatter drift)

After any auto-resolve, run the build or test gate before proceeding. If the gate fails, revert the auto-resolve and escalate.

## Escalate before acting

Pause and ask the orchestrator (or the user) before resolving any of:

- **Same region, different edits.** Both sides modified lines N..M in incompatible ways.
- **Delete vs modify.** One side deleted a file or block, the other modified it.
- **Semantic conflicts.** Both sides edited different files, but the combination breaks an invariant. E.g., one side changed a function signature, the other added a new caller using the old signature.
- **Test expectation divergence.** Both sides changed the expected output of the same test.
- **Lockfile conflicts.** Regenerate the lockfile rather than line-merging it, and note which dependency versions were chosen in the PR body.

## Recovery commands

| Situation | Command |
|---|---|
| Trunk moved; apply stack on new trunk | `gt sync` |
| Re-apply stack after any base change | `gt restack` |
| Conflict during restack; resolve then continue | resolve, `git add` the fix, `gt continue` |
| Abort an in-flight restack | `gt abort` |

## After resolution

- Run the test suite before submitting.
- Update the affected PR's description to note the conflict was resolved and what was chosen, so reviewers see the decision context.
- If the resolution changed behaviour, add a separate commit via `gt create -am "fix: reconcile conflict from <other-branch>"` rather than hiding the change inside the restack.

## What to avoid

- **Force-pushing to clear a conflict.** Use `gt` operations; they handle force-push semantics per-branch where needed.
- **Silently dropping one side.** If you cannot represent both intents, escalate. Do not guess.
- **Merging locally to skip the stack.** `git merge` of another branch into your stack confuses `gt`'s metadata. Use `gt sync` or `gt restack`.
