---
name: jj-vcs-comprehensive
description: Complete Jujutsu (jj) version control system for Git replacement. Use when migrating from Git, setting up colocated workspaces, managing commits without staging, working with bookmarks/branches, syncing with GitHub/remotes, resolving conflicts, or any jj command operations.
---

# Jujutsu (JJ) Version Control

Complete Git replacement with automatic commit tracking and simplified workflows.

## When to Apply

- Migrating from Git to jj while maintaining GitHub sync
- Setting up colocated Git/jj workspaces for tool compatibility
- Managing commits without staging area complexity
- Working with bookmarks (branches) and remote synchronization
- Resolving merge conflicts as first-class objects

## Critical Rules

**Colocated Workspaces**: Always use `--colocate` for Git tool compatibility

```bash
# WRONG - Creates separate .jj directory
jj git init myproject

# RIGHT - Shared working copy with Git
jj git init --colocate myproject
jj git clone --colocate https://github.com/user/repo
```

**Working Copy as Commit**: Changes automatically tracked without staging

```bash
# WRONG - No staging area exists
git add file.rs
git commit -m "message"

# RIGHT - Describe current commit, changes auto-tracked
echo "code" > file.rs
jj describe -m "Add feature"
jj new  # Finalize and start new commit
```

**Bookmarks vs Branches**: Use `bookmark` commands for Git branch equivalents

```bash
# WRONG - No branch command
jj branch create feature

# RIGHT - Bookmarks are jj's branch concept
jj bookmark create feature-auth
jj bookmark track main --remote origin
```

## Key Patterns

### Repository Setup

```bash
# Clone with GitHub sync capability
jj git clone --colocate https://github.com/user/repo
cd repo

# Convert existing Git repo
cd existing-git-repo
jj git init --colocate

# Check colocation status
jj git colocation status
```

### Daily Workflow

```bash
# Check status (no staging area)
jj status
jj diff

# Set commit message for current work
jj describe -m "Implement authentication"

# View history with graph
jj log
jj log -r 'main::@'  # Between main and working copy

# Finalize current work, start new commit
jj new

# Create commits on specific revisions
jj new main
jj new -r "trunk()"
```

### Bookmark Management

```bash
# Create and track bookmarks
jj bookmark create feature-branch
jj bookmark create ui-update -r <commit-id>
jj bookmark track main --remote origin

# List and manage
jj bookmark list --all-remotes
jj bookmark move feature-branch --to @
jj bookmark delete old-feature
jj bookmark rename old-name new-name
```

### Remote Synchronization

```bash
# Add remotes
jj git remote add origin https://github.com/user/repo.git
jj git remote list

# Fetch and push
jj git fetch
jj git fetch --remote upstream
jj git push --bookmark feature-branch --allow-new
jj git push --all

# Sync workflow (no direct pull equivalent)
jj git fetch
jj rebase -b my-feature -d main@origin
jj git push --bookmark my-feature
```

### Conflict Resolution

```bash
# Conflicts are first-class objects
jj new main feature-branch  # May create conflict

# View conflicted files
jj status
jj log -r 'conflict()'

# Resolve interactively
jj resolve
jj resolve src/file.rs

# Manual resolution workflow
jj new conflicted-commit  # Work on top of conflict
# Edit files manually
jj squash  # Move resolution into conflicted commit
```

### Advanced Operations

```bash
# Rebase operations
jj rebase -s source-commit -d destination-commit
jj rebase -b bookmark-name -d main

# Split and squash (replaces Git staging)
jj split file1.rs file2.rs  # Interactive split
jj squash file3.rs  # Move to parent commit
jj squash -i  # Interactive selection

# Edit historical commits
jj edit <commit-id>  # Change working copy to that commit

# Complex history queries
jj log -r 'author("alice") & committer_date(after:"2024-01")'
jj log -r 'description(glob:"fix*") ~ author("bot")'
jj log -r 'mutable() & empty()'
```

### Git Compatibility

```bash
# Use Git commands in colocated workspace
git status  # Works alongside jj
git log     # Git view of history
jj log      # jj view (more powerful)

# Import/export when needed
jj git import  # Import Git refs
jj git export  # Export to Git

# Disable/enable colocation
jj git colocation disable  # Separate .jj directory
jj git colocation enable   # Shared working copy
```

## Common Mistakes

- **Using Git staging concepts**: jj has no staging area - changes are automatically tracked in working copy commit
- **Forgetting to track remote bookmarks**: Use `jj bookmark track <name> --remote origin` for push/pull workflows  
- **Not using `--colocate`**: Required for Git tool compatibility and GitHub workflows
- **Expecting `git pull` equivalent**: Use `jj git fetch` followed by `jj rebase -b branch -d main@origin`
- **Creating commits without descriptions**: Use `jj describe -m "message"` to set commit messages
- **Mixing `new` and `commit`**: `jj new` starts a new empty change on top; `jj commit` is shorthand for `jj describe` + `jj new` — it finalizes the current change with a message and starts a new one. Neither is a Git-sync command; use `jj git fetch`/`jj git push` for that.
