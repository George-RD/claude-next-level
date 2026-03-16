---
name: jj
description: >-
  Version control operations using Jujutsu (jj) — replaces git commit/push/PR
  workflows when a .jj/ directory exists. Use when the user says "commit", "push",
  "create a PR", "describe", "bookmark", or any VC action in a JJ repo. Also use
  for jj-specific operations: revsets, stacked changes, conflict resolution, undo.
  If the repo has .jj/, this skill takes priority over git workflows.
---

# JJ Version Control

In JJ, the working copy is always a live commit (`@`). There is no staging area and no explicit commit step — every file change automatically amends `@` on the next `jj` command. The only actions needed are **describe** (label your work) and **push** (send to remote).

## Detect JJ repo

Before any VC operation, verify you're in a JJ workspace with:
`jj root >/dev/null 2>&1`. If that succeeds, use only `jj` commands — never bare `git`.

## Action: Describe (when user says "commit" or "save")

In JJ, "committing" means describing the current change and moving on:

1. Gather context: `jj status`, `jj diff`, `jj log --limit 10`
1. Draft a message matching the repo's commit style
1. Run: `jj describe -m "<message>" && jj new`

That's it. No `git add`, no staging. The `jj new` creates a fresh change on top so future edits don't amend the described work.

## Action: Push

1. Check: `jj bookmark list` and `jj log -r '@-'`
1. If no bookmark on the target change: `jj bookmark set <name> -r @-`
1. Push: `jj git push --bookmark <name> --allow-new`
   - The `--allow-new` flag is **required** the first time a bookmark is pushed. Omitting it causes the push to fail. Subsequent pushes don't need it.
1. Verify: `jj log --limit 5` to confirm the push landed

## Action: Push + PR

1. If `@` has changes: `jj describe -m "<message>" && jj new`
1. Set bookmark: `jj bookmark set <name> -r @-`
1. Push: `jj git push --bookmark <name> --allow-new`
1. Analyze ALL changes in the PR range with `jj log -r 'trunk()..@-'`
1. Create PR: `gh pr create --head "<name>" --title "<title>" --body "<summary + test plan>"`

## Action: Conflict resolution

Conflicts in JJ don't block work — you can keep working elsewhere and resolve later. To resolve:

1. Find conflicts: `jj log -r 'conflicts()'`
1. Navigate: `jj edit <change-id>`
1. Resolve: edit markers manually, or `jj resolve`, or `jj resolve --tool=:ours`
1. Descendants auto-rebase after resolution

Safety: `jj undo` reverses any operation. `jj op restore <id>` jumps to any past state.

## JJ-specific gotchas

- Never use bare `git` commands in a JJ repo — only `jj git ...` subcommands
- `--allow-new` is required on first push of any bookmark
- Use change IDs (stable) not commit hashes (change on amend)
- Bookmarks are only needed for pushing — local work is purely change-based
- `jj commit -m "msg"` is shorthand for `jj describe -m "msg" && jj new`

## Reference files (read ONLY when needed for edge cases)

The actions above cover the common workflows. Only read these for specific questions:

- **`references/git-to-jj.md`** — ONLY when user asks "what's the jj equivalent of git X?"
- **`references/revsets.md`** — ONLY when building complex revset queries beyond the basics above
- **`references/workflows.md`** — ONLY for stacked PRs with per-change bookmarks, Gerrit, workspaces, or colocated repo setup
