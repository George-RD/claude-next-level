# Git to JJ Command Mapping

A comprehensive translation table for moving from Git workflows to Jujutsu.

## Table of Contents

- [Repository Setup](#repository-setup)
- [Daily Commands](#daily-commands)
- [Branching and Bookmarks](#branching-and-bookmarks)
- [History Editing](#history-editing)
- [Remote Operations](#remote-operations)
- [Viewing and Inspection](#viewing-and-inspection)
- [Undoing and Recovery](#undoing-and-recovery)
- [File Operations](#file-operations)
- [Advanced](#advanced)

## Repository Setup

| Git | JJ | Notes |
|-----|-----|-------|
| `git init` | `jj git init --colocate` | Creates jj repo alongside .git |
| `git clone <url>` | `jj git clone <url>` | Note the `git` before `clone` |
| — | `jj git init` | Pure jj repo (non-colocated) |

## Daily Commands

| Git | JJ | Notes |
|-----|-----|-------|
| `git status` | `jj status` / `jj st` | Working copy is always a commit |
| `git add . && git commit -m "msg"` | `jj commit -m "msg"` | No staging area needed |
| `git add . && git commit --amend` | *(automatic)* | Changes auto-amend @ on next jj command |
| `git commit --amend -m "new msg"` | `jj describe -m "new msg"` | Updates description of @ |
| `git diff` | `jj diff` | Shows changes in @ |
| `git diff --staged` | *(N/A)* | No staging area in jj |
| `git stash` | *(N/A)* | Not needed — working copy is always a commit |
| `git stash pop` | *(N/A)* | Just `jj edit <change>` to go back |

## Branching and Bookmarks

| Git | JJ | Notes |
|-----|-----|-------|
| `git branch <name>` | `jj bookmark create <name>` | Creates at @ |
| `git checkout -b <name>` | `jj new && jj bookmark set <name> -r @` | Or `jj new -m "msg"` then set bookmark |
| `git switch <branch>` | `jj edit <change-id>` | Navigate by change ID, not branch name |
| `git branch -d <name>` | `jj bookmark delete <name>` | |
| `git branch -a` | `jj bookmark list --all-remotes` | |
| `git merge <branch>` | `jj new <change1> <change2>` | Creates merge change with multiple parents |

## History Editing

| Git | JJ | Notes |
|-----|-----|-------|
| `git commit --amend` | *(automatic)* | Just edit files, jj amends @ |
| `git rebase -i` | `jj squash`, `jj split`, `jj edit` | Individual operations replace interactive rebase |
| `git rebase <target>` | `jj rebase -d <target>` | |
| `git rebase --onto` | `jj rebase -s <source> -d <dest>` | |
| `git cherry-pick <commit>` | `jj duplicate <change>` | Creates copy of the change |
| `git reset --soft HEAD~1` | `jj squash` | Folds @ into parent |
| `git reset --hard HEAD~1` | `jj abandon @` | Discards current change |

## Remote Operations

| Git | JJ | Notes |
|-----|-----|-------|
| `git fetch` | `jj git fetch` | |
| `git pull` | `jj git fetch && jj rebase -d main` | Fetch + rebase is the jj pattern |
| `git push` | `jj git push --bookmark <name>` | Must specify bookmark |
| `git push -u origin <branch>` | `jj git push --bookmark <name> --allow-new` | First push of a new bookmark |
| `git push --force-with-lease` | *(automatic)* | jj handles this safely by default |
| `git remote add <name> <url>` | `jj git remote add <name> <url>` | |
| `git remote -v` | `jj git remote list` | |

## Viewing and Inspection

| Git | JJ | Notes |
|-----|-----|-------|
| `git log` | `jj log` | Shows change IDs + commit graph |
| `git log --oneline` | `jj log -r ::@` | Revset controls what's shown |
| `git show <commit>` | `jj show <change>` | |
| `git blame <file>` | `jj file annotate <file>` | |
| `git diff <a>..<b>` | `jj diff --from <a> --to <b>` | |
| `git log -- <file>` | `jj log -r 'file("path")'` | Uses revset file() function |

## Undoing and Recovery

| Git | JJ | Notes |
|-----|-----|-------|
| `git reflog` | `jj op log` | Operation log is more comprehensive |
| `git reset --hard <commit>` | `jj op restore <op-id>` | Restore entire repo state |
| *(limited)* | `jj undo` | Reverses last operation cleanly |
| *(limited)* | `jj redo` | Re-applies after undo |
| `git checkout -- <file>` | `jj restore <file>` | Restore file from parent |
| `git checkout <rev> -- <file>` | `jj restore --from <rev> <file>` | |

## File Operations

| Git | JJ | Notes |
|-----|-----|-------|
| `git ls-files` | `jj file list` | |
| `git show <rev>:<file>` | `jj file show <file> -r <rev>` | |
| `git rm --cached <file>` | `jj file untrack <file>` | |
| `git add <file>` | *(automatic)* | New files auto-tracked (unless in .gitignore) |

## Advanced

| Git | JJ | Notes |
|-----|-----|-------|
| `git bisect` | `jj bisect run '<cmd>'` | Automated binary search |
| `git worktree add` | `jj workspace add <path>` | Multiple working copies |
| *(no equivalent)* | `jj parallelize <revset>` | Convert linear stack to siblings |
| *(no equivalent)* | `jj absorb` | Auto-distribute fixes to ancestors |
| *(no equivalent)* | `jj evolog` | See how a change evolved over time |
| *(no equivalent)* | `jj interdiff --from <a> --to <b>` | Compare diffs of two changes |
