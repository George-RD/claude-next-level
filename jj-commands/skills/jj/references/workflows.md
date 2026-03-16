# JJ Workflow Recipes

Detailed workflow patterns for common development scenarios.

## Table of Contents

- [Stacked PRs (GitHub)](#stacked-prs-github)
- [Gerrit Integration](#gerrit-integration)
- [Colocated Repositories](#colocated-repositories)
- [Multiple Workspaces](#multiple-workspaces)
- [Handling Review Feedback](#handling-review-feedback)
- [Rebasing and Conflict Strategies](#rebasing-and-conflict-strategies)
- [Migration from Git](#migration-from-git)
- [Custom Aliases](#custom-aliases)
- [CI Integration Patterns](#ci-integration-patterns)

## Stacked PRs (GitHub)

Stacked PRs split a large feature into small, reviewable changes that depend on each other.

### Creating a stack

```bash
# Start from latest main
jj git fetch
jj new main -m "refactor: extract auth types"
# ... make changes ...
jj bookmark set stack/01-auth-types -r @

jj new -m "feat: add OAuth2 provider"
# ... make changes ...
jj bookmark set stack/02-oauth -r @

jj new -m "feat: add session management"
# ... make changes ...
jj bookmark set stack/03-sessions -r @

# Push all at once
jj git push --bookmark stack/01-auth-types --allow-new
jj git push --bookmark stack/02-oauth --allow-new
jj git push --bookmark stack/03-sessions --allow-new
```

### Creating PRs for the stack

On GitHub, create PRs with the correct base branches:
- PR for `stack/01-auth-types` → base: `main`
- PR for `stack/02-oauth` → base: `stack/01-auth-types`
- PR for `stack/03-sessions` → base: `stack/02-oauth`

### Updating a change mid-stack

```bash
jj edit <change-id-of-01>
# ... fix review feedback ...
# All descendants automatically rebase

# Move bookmarks if needed (they should auto-follow)
jj git push --bookmark stack/01-auth-types
jj git push --bookmark stack/02-oauth
jj git push --bookmark stack/03-sessions
```

### After merging bottom of stack

When `stack/01-auth-types` merges to main:

```bash
jj git fetch
# Rebase remaining stack onto main
jj rebase -s <change-id-of-02> -d main
# Update PR base branches on GitHub
# Delete merged bookmark
jj bookmark delete stack/01-auth-types
```

## Gerrit Integration

jj has first-class Gerrit support via `jj gerrit` commands.

```bash
# Send changes for review
jj gerrit upload

# The Gerrit workflow uses Change-Ids natively since jj's change IDs
# map directly to Gerrit's concept of changes
```

For Gerrit workflows, the key benefit is that jj's change-based model maps directly to Gerrit's change-based review model, making it more natural than git with Gerrit.

## Colocated Repositories

A colocated repo has both `.jj/` and `.git/` at the root. This gives you jj's workflow while keeping git compatibility for tools that need `.git/`.

### Setting up colocation

```bash
# New repo
jj git init --colocate

# Existing git repo — initialize jj alongside
cd existing-git-repo
jj git init --colocate

# Convert between modes
jj git colocation enable    # Make non-colocated repo colocated
jj git colocation disable   # Make colocated repo non-colocated
jj git colocation status    # Check current mode
```

### How colocation works

- jj automatically syncs its state with the underlying `.git/` on every command
- Git tools (IDE integrations, `git log`, etc.) see the repo normally
- Bookmarks map to git branches
- Do NOT run `git commit`, `git rebase`, etc. — always use `jj` commands
- `jj git export` / `jj git import` sync if things get out of step

### When to use colocation

- When your editor/IDE needs `.git/` for features (VS Code git lens, etc.)
- When CI/CD tools expect a git repo
- When you want to gradually adopt jj in a team that uses git

## Multiple Workspaces

Workspaces let you have multiple working copies of the same repo, each at a different change.

```bash
# Add a workspace for a different change
jj workspace add ../hotfix-workspace
cd ../hotfix-workspace
jj edit <hotfix-change>
# ... work on hotfix while main workspace stays at your feature ...

# List workspaces
jj workspace list

# Clean up
jj workspace forget ../hotfix-workspace
```

Use workspaces when you need to context-switch without disrupting your current work. They're lighter than git worktrees because they share the same repo storage.

## Handling Review Feedback

### Single PR update cycle

```bash
jj git fetch                           # Get latest remote state
jj edit <change-id>                     # Go to the change that needs fixes
# ... apply reviewer's feedback ...
jj describe -m "feat: add auth (v2)"    # Update description if needed
jj bookmark set my-pr -r @              # Ensure bookmark is here
jj git push --bookmark my-pr            # Push the update
```

### Splitting a change after review

Reviewer says "this does two things, please split":

```bash
jj edit <change-id>
jj split                # Interactive: select what stays vs. moves to new change
# Now you have two changes. Set bookmarks as needed.
```

### Addressing multiple review comments across a stack

```bash
# Fix comment on change A
jj edit <change-a-id>
# ... fix ...

# Fix comment on change C (no need to go back to top first)
jj edit <change-c-id>
# ... fix ...

# Push all affected bookmarks
jj git push --bookmark pr-a
jj git push --bookmark pr-b   # Rebased automatically, may have new content
jj git push --bookmark pr-c
```

## Rebasing and Conflict Strategies

### Keeping up with main

```bash
jj git fetch
jj rebase -d main          # Rebase working copy + descendants onto main
```

### Handling conflicts during rebase

Unlike git, jj doesn't stop on conflict. The change is marked as conflicted and descendants still rebase:

```bash
jj rebase -d main
# If conflicts arise:
jj status                   # Shows which changes have conflicts
jj log -r 'conflicts()'    # List all conflicted changes

# Fix conflicts in each change
jj edit <conflicted-change>
# Edit the files to resolve conflict markers
# Or use: jj resolve

# Move to next conflicted change
jj edit <next-conflicted>
# ... resolve ...
```

### Postponing conflict resolution

You can continue working even with conflicted changes in your history. The conflicts are recorded in the change and can be resolved later. This is safe because:
- jj tracks conflicts as first-class data
- Descendant changes can still be created and edited
- You just can't push conflicted changes

## Migration from Git

### Individual migration (team still uses git)

```bash
cd your-git-repo
jj git init --colocate
# Now use jj commands. Git tools still work.
# Your pushes look like normal git pushes to teammates.
```

### Converting git branches to bookmarks

After `jj git init --colocate`, existing git branches automatically become jj bookmarks. No manual conversion needed.

### Muscle memory translation

Instead of:
- `git add . && git commit -m "msg"` → just edit files, then `jj commit -m "msg"`
- `git stash / git stash pop` → `jj new` to move on, `jj edit <change>` to come back
- `git checkout <branch>` → `jj edit <change-id>`
- `git rebase -i` → `jj edit`, `jj squash`, `jj split` (separate commands for each operation)

## Custom Aliases

Define in `~/.jjconfig.toml`:

```toml
[aliases]
# Quick log of my work
mine = ["log", "-r", "mine() & ~immutable()"]

# Short status
s = ["status"]

# Diff of what I'm about to push
review = ["diff", "-r", "main..@"]

# Move the nearest ancestor bookmark to current change
tug = ["bookmark", "move", "--from", "heads(::@- & bookmarks())", "--to", "@"]

# Push current bookmark
ps = ["git", "push", "--bookmark"]

# Fetch and rebase onto main
sync = ["rebase", "-d", "main"]
```

## CI Integration Patterns

### GitHub Actions with jj

Since jj repos are git-compatible, CI systems just see a git repo. No special CI configuration needed when using colocated repos.

### Pre-push checks

Use `jj` in pre-push hooks or CI to verify:

```bash
# Check no conflicts in the push range
jj log -r 'conflicts() & main..@' --no-graph -T 'change_id ++ "\n"'
# If output is non-empty, there are conflicted changes

# Check all changes have descriptions
jj log -r 'main..@ & description("")' --no-graph -T 'change_id ++ "\n"'
# If output is non-empty, some changes lack descriptions
```
