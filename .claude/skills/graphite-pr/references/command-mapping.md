# git → gt command mapping

Load this when you want to do something with `git` that affects branches or commit history and you're not sure of the `gt` equivalent. Plain `git` reads (status, log, diff, show, blame, grep) remain fine.

## Main substitutions

| Intent | gt command | Notes |
|---|---|---|
| New branch + first commit (selective stage) | `git add <files>; gt create -m "<subject>"` | Default daily pattern. Avoids sweeping unrelated tracked changes. |
| New branch + first commit (sweep all tracked) | `gt create -am "<subject>"` | Convenient but a foot-gun — pulls in `.claude/`, `graphify-out/`, lockfiles. Audit `git status` first. |
| Amend the current PR | `git add <files>; gt modify -a` | For review feedback on the current branch. |
| Add another commit on the same branch | `gt modify -c -am "<subject>"` | Rare — usually you want a new branch via `gt create` instead. |
| Publish whole stack as non-draft PRs | `gt submit --stack --publish --no-interactive` | `--publish` is mandatory for auto-review. |
| Publish only the current branch | `gt submit --publish --no-interactive` | |
| Pull trunk and restack | `gt sync --no-interactive --force` | Run at phase/wave boundaries, not mid-commit. |
| Show the stack | `gt log` | Branch sequence with status. |
| Navigate up/down the stack | `gt up` / `gt down` | Toward tip / toward trunk. |
| Delete a branch | `gt delete <branch>` | Handles stack restacking cleanly. |
| Move a branch onto a new base | `gt move --onto <target>` | Reorganise stacks. |
| Re-apply stack on updated base | `gt restack` | Auto-fires after `gt sync`; run manually after conflict resolution. |
| Continue after resolving a conflict | `gt continue` | Resumes `gt restack` once you've staged the fix. |
| Abort an in-flight restack/rebase | `gt abort` | Standalone command — there is no `--abort` flag on `gt restack`. |
| Trunk name | `gt trunk` | Returns configured trunk; never assume `main`. |
| Track an untracked branch | `gt track --parent <trunk-or-parent>` | For branches created outside `gt`. |
| Split one commit into a stack | `gt split` | `--by-commit` (programmatic), `--by-file` (programmatic, often over-splits), `--by-hunk` (**interactive only — unusable headlessly**; see `recovery.md` for the soft-reset fallback). |

## Raw git that is always safe

- `git status`
- `git log` / `git log --oneline`
- `git diff` / `git diff --staged`
- `git show <hash>`
- `git stash` / `git stash pop` (gt does not wrap WIP stash)
- `git add` / `git add -p` / `git reset` (staging — `gt create -am` and `gt modify -a` consume the staging area)
- `git blame`, `git grep`, `git rev-parse`, `git worktree list`, `git reflog`

These are read-only or affect only the staging area, so they don't break gt's stack model.

## Raw git that is a red flag

If you catch yourself running these in a Graphite repo, stop and use the gt equivalent:

| You wrote | Use instead |
|---|---|
| `git commit -m` | `gt create -m` (new branch) or `gt modify -c -am` (same branch) |
| `git commit --amend` | `gt modify -a` |
| `git push` | `gt submit` |
| `git push --force` / `--force-with-lease` | `gt submit` (gt manages force-push semantics per-branch). If the permission layer denies it anyway, push to a new branch instead — see `recovery.md`. |
| `git checkout -b` | `gt create` |
| `git rebase -i` | `gt modify` plus `gt split` |
| `git rebase <base>` | `gt sync` or `gt restack` |
| `git branch -D` | `gt delete` |
| `git merge <branch>` | Don't run `git merge` manually. Let `gt sync` / `gt restack` / the merge queue handle it. Manual merges confuse gt's metadata. |

## Why gt instead of raw git

`gt` maintains branch-to-branch metadata in `.graphite_repo_config`. Raw git commands that create or delete branches can silently break that metadata, which surfaces later as restack errors or mis-ordered stacks. Every gt alternative above preserves the metadata.
