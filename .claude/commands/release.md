---
description: "Release plugins with changelog from conventional commits"
argument-hint: "[plugin-name] [--dry-run]"
---

# Release Workflow

You are automating a release for the **claude-next-level** plugin marketplace. This repo contains 7 plugins, each with its own directory and `plugin.json`, plus a central registry at `.claude-plugin/marketplace.json`.

Parse the argument `$ARGUMENTS` for:

- An optional **plugin name** to release only that plugin (e.g., `next-level`, `cycle`). If omitted, release all plugins with changes.
- An optional **`--dry-run`** flag. If present, show what would happen but make no changes.
- An optional **ref** via `--since=<ref>` to compare against. Defaults to the latest git tag, or the initial commit if no tags exist.

## Step 1: Determine the base ref

Run `git tag --list --sort=-creatordate` to find the latest tag. If no tags exist, use the very first commit (`git rev-list --max-parents=0 HEAD`). If `--since=<ref>` was provided, use that instead.

## Step 2: Find changed plugins

The plugins and their directories are:

| Plugin | Directory | plugin.json path |
|--------|-----------|-----------------|
| next-level | `next-level/` | `next-level/plugin.json` |
| grandslam-offer | `grandslam-offer/` | `grandslam-offer/plugin.json` |
| hundred-million-leads | `hundred-million-leads/` | `hundred-million-leads/plugin.json` |
| cycle | `cycle/` | `cycle/plugin.json` |
| ralph-wiggum | `ralph-wiggum/` | `ralph-wiggum/plugin.json` |
| nest-test | `nest-test/` | `nest-test/.claude-plugin/plugin.json` |
| jj-commands | `jj-commands/` | `jj-commands/plugin.json` |

Run `git diff --name-only <base-ref>..HEAD` to get all changed files. Map each changed file to its plugin by matching the directory prefix. Ignore files outside plugin directories (e.g., root-level files, `.claude/`, `docs/`).

If a specific plugin name was given as an argument, filter to only that plugin.

If no plugins have changes, report "No plugin changes detected since `<base-ref>`" and stop.

## Step 3: Analyze commits and determine version bumps

For each changed plugin, run:

```bash
git log <base-ref>..HEAD --format='%H%x1f%s%x1f%b%x1e' -- <plugin-directory>/
```

This format emits hash, subject, and body separated by unit separators, enabling detection of `BREAKING CHANGE` footers in commit bodies.

Classify each commit using conventional commit prefixes (inspect both subject and body):

- `feat(...)` or `feat:` -> **minor** bump
- `fix(...)` or `fix:` -> **patch** bump
- `refactor(...)`, `docs(...)`, `chore(...)`, `test(...)`, `style(...)`, `ci(...)`, `perf(...)` -> **patch** bump
- Any commit with `BREAKING CHANGE` in its body or `!` after the type (e.g., `feat!:`) -> **major** bump

The highest-priority bump wins: major > minor > patch.

Read the current version from the plugin's `plugin.json`. Bump it accordingly using semver rules.

## Step 4: Display the release plan

Before making changes, display a summary table:

```text
Release Plan:
| Plugin | Current | New | Bump | Commits |
|--------|---------|-----|------|---------|
| next-level | 0.3.0 | 0.4.0 | minor | 3 |
| cycle | 2.0.0 | 2.0.1 | patch | 1 |
```

If `--dry-run` was specified, stop here. Print the changelog (Step 5) but make no file changes, no commits, no tags.

## Step 5: Generate changelog

Build a changelog grouped by plugin. For each plugin, group commits by type:

```markdown
## <plugin-name> v<new-version>

### Features
- <commit summary> (<short-hash>)

### Fixes
- <commit summary> (<short-hash>)

### Other Changes
- <commit summary> (<short-hash>)
```

Use the actual commit messages, cleaned up (remove the conventional commit prefix for readability). Include the short hash for each entry.

## Step 6: Update version files

For each plugin being released:

1. **Update `<plugin>/plugin.json`** (or `<plugin>/.claude-plugin/plugin.json` for nest-test): change the `"version"` field to the new version.
2. **Update `.claude-plugin/marketplace.json`**: find the matching plugin entry by name and update its `"version"` field.

Use the Edit tool for precise replacements. Do not rewrite entire files.

## Step 7: Commit and tag

Create a single commit with all version bumps:

```text
chore(release): bump <plugin1> v<new1>, <plugin2> v<new2>, ...
```

List all released plugins and their new versions in the commit message.

Create a git tag. Use the format:

- If releasing a single plugin: `<plugin-name>/v<version>` (e.g., `next-level/v0.4.0`)
- If releasing multiple plugins: `release/v<date>-<short-sha>` using today's date as YYYY-MM-DD and the short commit SHA (e.g., `release/v2026-03-16-a1b2c3d`) to avoid same-day tag collisions

## Step 8: GitHub release (optional)

Ask the user if they want to create a GitHub release. If yes:

Use `gh release create <tag>` with the changelog from Step 5 as the release body. Use `--title` with a descriptive name like "Release: next-level v0.4.0, cycle v2.0.1".

If the user declines, remind them they can push the tag manually with `git push origin <tag>`.

## Important Notes

- Always read files before editing them.
- Use conventional commits for the version bump commit.
- Do not modify any files other than `plugin.json` files and `marketplace.json`.
- If a plugin has no conventional commits (e.g., only merge commits), default to a **patch** bump.
- Report clearly at each step so the user can follow along.
