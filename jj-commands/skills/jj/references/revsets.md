# Revset Language Reference

Revsets are jj's expression language for selecting sets of changes. They appear after `-r` flags and in configuration.

## Table of Contents

- [Symbols](#symbols)
- [Operators](#operators)
- [Functions](#functions)
- [Patterns and Examples](#patterns-and-examples)

## Symbols

| Symbol | Meaning |
|--------|---------|
| `@` | The working-copy change |
| `@-` | Parent of @ |
| `@--` | Grandparent of @ |
| `root()` | The root (empty) change |
| `<bookmark-name>` | Change pointed to by a bookmark |
| `<name>@<remote>` | Remote bookmark (e.g. `main@origin`) |
| `<change-id>` | A specific change by its ID |

## Operators

### Ancestry

| Operator | Meaning | Example |
|----------|---------|---------|
| `x-` | Parents of x | `@-` (parent of working copy) |
| `x+` | Children of x | `main+` (children of main) |
| `::x` | x and all ancestors | `::@` (all ancestors of working copy) |
| `x::` | x and all descendants | `main::` (main and everything after) |
| `x::y` | DAG range from x to y | `main::@` (main to working copy, inclusive) |
| `x..y` | Range: ancestors of y minus ancestors of x | `main..@` (changes after main, up to @) |

### Set operations

| Operator | Meaning | Example |
|----------|---------|---------|
| `x \| y` | Union | `bookmarks() \| tags()` |
| `x & y` | Intersection | `mine() & main..@` |
| `~x` | Complement (everything except) | `~main::` |
| `x ~ y` | Difference (x minus y) | `all() ~ main::` |

### Precedence (highest to lowest)

1. `x-`, `x+` (postfix)
2. `::x`, `x::` (prefix)
3. `x::y`, `x..y` (infix range)
4. `~x` (prefix negation)
5. `x & y` (intersection)
6. `x \| y` (union)
7. `x ~ y` (difference)

Use parentheses to override: `(x \| y) & z`

## Functions

### Identity and authorship

| Function | Description |
|----------|-------------|
| `mine()` | Changes authored by the current user |
| `author(pattern)` | Changes where author matches pattern |
| `committer(pattern)` | Changes where committer matches pattern |
| `description(pattern)` | Changes whose description matches |
| `empty()` | Changes with no diff |

### Structure

| Function | Description |
|----------|-------------|
| `root()` | The root change |
| `trunk()` | The main development bookmark (main, master, etc.) |
| `heads(x)` | Changes in x with no descendants in x |
| `roots(x)` | Changes in x with no ancestors in x |
| `parents(x)` | Parents of changes in x |
| `children(x)` | Children of changes in x |
| `ancestors(x)` | Same as `::x` |
| `descendants(x)` | Same as `x::` |
| `connected(x)` | Transitive closure of x (fill in gaps) |

### Bookmarks and remotes

| Function | Description |
|----------|-------------|
| `bookmarks()` | All local bookmarks |
| `bookmarks(pattern)` | Bookmarks matching glob pattern |
| `remote_bookmarks()` | All remote bookmarks |
| `remote_bookmarks(bookmark, remote)` | Specific remote bookmark |
| `tags()` | All tags |
| `tags(pattern)` | Tags matching glob pattern |
| `tracked_remote_bookmarks()` | Tracked remote bookmarks |

### Content

| Function | Description |
|----------|-------------|
| `files(expression)` | Changes that modified paths matching the fileset expression |
| `conflicts()` | Changes with unresolved conflicts |
| `diff_lines(text, [files])` | Changes whose diff contains matching lines |

### State

| Function | Description |
|----------|-------------|
| `present(x)` | x if it exists, empty set otherwise (no error) |
| `coalesce(x, y)` | x if non-empty, else y |
| `visible_heads()` | All visible heads |
| `all()` | All visible changes |
| `mutable()` | Non-immutable changes |
| `immutable()` | Immutable changes (trunk, tags, etc.) |
| `working_copies()` | Changes that are working copies in any workspace |

## Patterns and Examples

### Common queries

```bash
# What have I been working on?
jj log -r 'mine() & ~immutable()'

# Show all changes on my feature branch
jj log -r 'main..@'

# Find changes that touched a specific file
jj log -r 'files("src/auth.rs")'

# Show conflicted changes
jj log -r 'conflicts()'

# Show all bookmarks and where they point
jj log -r 'bookmarks()'

# Changes by a specific author
jj log -r 'author("alice")'

# Changes with "fix" in the description
jj log -r 'description("fix")'

# All mutable (rewritable) changes
jj log -r 'mutable()'

# Changes between two bookmarks
jj log -r 'feature-a::feature-b'

# Heads of my work (tips of all my branches)
jj log -r 'heads(mine() & ~immutable())'
```

### Complex queries

```bash
# My changes that have conflicts
jj log -r 'mine() & conflicts()'

# Non-empty changes after main
jj log -r 'main..@ & ~empty()'

# Changes that modified tests
jj log -r 'files("tests/")'

# Bookmarks not yet merged to main
jj log -r 'bookmarks() ~ ::main'

# Find who changed a file recently
jj log -r 'files("src/main.rs") & ~immutable()'
```

### Using revsets with commands

```bash
# Rebase everything after main onto updated main
jj rebase -s 'roots(main..@)' -d main

# Abandon all empty changes
jj abandon 'empty() & mine() & ~immutable()'

# Show diff for all changes in a stack
jj diff -r 'main..@'

# Duplicate a range of changes
jj duplicate 'main..@'
```
