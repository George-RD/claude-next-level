# git to gt Command Mapping

Prefer `gt` for any command that affects branches or commit history in a Graphite-initialised repo. Plain git reads remain fine.

## Main substitutions

| Intent | gt command | Notes |
|---|---|---|
| New branch + first commit | `gt create -am "<subject>"` | Creates a branch, stages all unstaged changes (including untracked files — `-a`/`--all`), commits. Use `-um` instead for tracked-only semantics. Each call adds one PR to the stack. |
| Amend the current PR | `gt modify -a` | Use for review feedback on the current branch. Stages and amends in one step. |
| Add another commit on the same branch | `gt modify -c -am "<subject>"` | Keeps you on the current branch, adds a new commit. The PR gets a new commit, not a new branch. |
| Publish the full stack | `gt submit --stack --no-interactive` | `--no-interactive` skips prompts, safe in agent sessions. |
| Publish only the current branch | `gt submit --no-interactive` | Single-PR submit. |
| Pull trunk and restack | `gt sync` | Run at phase or wave boundaries, not mid-commit. |
| Navigate up the stack | `gt up` | Toward the tip. |
| Navigate down the stack | `gt down` | Toward trunk. |
| Show stack state | `gt log` | Shows every branch in the current stack with status. |
| Delete a branch | `gt delete <branch>` | Handles stack restacking cleanly. |
| Split one commit into a stack | `gt split` | Variants: `--by-commit` (per-commit, programmatic), `--by-file` (per-file, programmatic), `--by-hunk` (**interactive only; not usable in headless agent sessions**. See SKILL.md "Retro-split fallback" for the headless path). |
| Move the current branch onto a new base | `gt move --onto <target>` | For reorganising stacks. |
| Re-apply the stack on an updated base | `gt restack` | Fired automatically after `gt sync`; run manually after a conflict resolution. |
| Continue after resolving a conflict | `gt continue` | Resumes `gt restack` once you've resolved and staged the fix. |
| Abort an in-flight restack/rebase | `gt abort` | Standalone command — there is no `--abort` flag on `gt restack`. Reverts the working copy to the pre-command state. |
| Trunk name | `gt trunk` | Returns the configured trunk; never assume `main`. |

## Raw git that is always safe

- `git status`
- `git log` / `git log --oneline`
- `git diff` / `git diff --staged`
- `git show <hash>`
- `git stash` / `git stash pop` (for in-flight WIP; `gt` does not wrap this)
- `git add` / `git add -p` / `git reset` (staging operations; `gt create -am` and `gt modify -a` consume the staging area)
- `git blame`, `git grep`, `git rev-parse`, `git worktree list`

These are read-only or affect only the staging area, so they do not break `gt`'s model of the stack.

## Raw git that is a red flag

If you catch yourself running any of these in a Graphite repo, stop and use the `gt` equivalent:

| You wrote | Use instead |
|---|---|
| `git commit -m` | `gt create -am` (new branch) or `gt modify -c -am` (same branch) |
| `git commit --amend` | `gt modify -a` |
| `git push` | `gt submit` |
| `git push --force` | `gt submit` (gt handles force-push semantics per-branch; avoid raw force-push) |
| `git checkout -b` | `gt create` |
| `git rebase -i` | `gt modify` plus `gt split` |
| `git rebase <base>` | `gt sync` or `gt restack` |
| `git branch -D` | `gt delete` |
| `git merge <branch>` | Do not run `git merge` manually. Merges driven by `gt` operations (sync, restack) and the Graphite merge queue are fine. Manual local merges confuse the stack model. |

## Why `gt` instead of raw git

`gt` maintains metadata about branch-to-branch relationships in `.git/.graphite_repo_config`. Raw git commands that create or delete branches can silently break that metadata, which shows up later as restack errors or mis-ordered stacks. Every `gt` alternative above preserves the metadata.
