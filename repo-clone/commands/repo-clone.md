---
name: repo-clone
description: "Initialize a porting project, check status, or get help"
argument-hint: "[init <source-lang> <target-lang> | status]"
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep"]
---

# /repo-clone Command

This is the **interactive** entry point for the repo-clone plugin. It is used for project setup and status checking. The actual porting work is driven by the ralph loop using the SKILL.md directly — not this command.

## Determine Mode

Parse the user's arguments to determine which mode to run:

1. If the argument starts with `init` followed by two language names: run **Init Mode**
2. If the argument is `status`: run **Status Mode**
3. If no arguments (or anything else): run **Fallback Mode**

---

## Init Mode (`/repo-clone init <source-lang> <target-lang>`)

Initialize a new porting project. Steps:

### 1. Validate Languages

Accept the source and target language names. Normalize them to lowercase.

### 2. Auto-detect Source Root

Search the working directory for common source directories in this order:

- `src/`
- `lib/`
- `app/`

If found, use it as `source_root`. If none found, ask the user.

### 3. Apply Smart Defaults

Use this table to set `target_root` and `test_command` based on the target language:

| Target Lang  | target_root  | test_command     |
|--------------|--------------|------------------|
| typescript   | ./src-ts     | npm test         |
| python       | ./src-py     | pytest           |
| go           | ./src-go     | go test ./...    |
| rust         | ./src-rs     | cargo test       |
| java         | ./src-java   | mvn test         |

If the target language is not in the table, ask the user for `target_root` and `test_command`.

### 4. Create Directory Structure

Create the `porting/` directory and its subdirectories:

```text
porting/
  specs/
    from-tests/
    from-src/
  golden-tests/
```

### 5. Write PORT_STATE.md

Write `porting/PORT_STATE.md` with the following content (substitute actual values):

```yaml
---
source_lang: "<source-lang>"
target_lang: "<target-lang>"
source_root: "<detected-or-provided>"
target_root: "<from-smart-defaults>"
test_command: "<from-smart-defaults>"
current_stage: 0
stages_completed: []
build_iterations: 0
build_failures: 0
created: "<today's date YYYY-MM-DD>"
---

# Port: <source-lang> -> <target-lang>

| Stage | Name | Status |
|-------|------|--------|
| 0 | Freeze | pending |
| 1 | Extract Tests | pending |
| 2 | Extract Source | pending |
| 3 | Plan | pending |
| 4 | Build | pending |
| 5 | Audit | pending |
```

### 6. Confirm to User

Tell the user:

- What was created
- The detected/chosen settings
- How to start the ralph loop: `while :; do cat PROMPT_port.md | claude -p ; done`
- That they can check progress anytime with `/repo-clone status`
- That `/repo-clone:help` explains the full workflow

---

## Status Mode (`/repo-clone status`)

Read `porting/PORT_STATE.md` and display a progress summary.

### 1. Read State

Read `porting/PORT_STATE.md`. Parse the YAML frontmatter to extract all fields. Parse the markdown table for stage statuses.

### 2. Display Progress Table

Show a formatted summary:

```text
PORT STATUS: <source_lang> -> <target_lang>
================================================

| Stage | Name           | Status    |
|-------|----------------|-----------|
| 0     | Freeze         | <status>  |
| 1     | Extract Tests  | <status>  |
| 2     | Extract Source | <status>  |
| 3     | Plan           | <status>  |
| 4     | Build          | <status>  |
| 5     | Audit          | <status>  |

Current Stage: <current_stage>
Build Iterations: <build_iterations>
Build Failures: <build_failures>
Created: <created>
```

### 3. Show Next Action

Based on the current stage, recommend the next action:

- **Stage 0**: "Next: Start the ralph loop to freeze baseline. Run: `while :; do cat PROMPT_port.md | claude -p ; done`"
- **Stage 1**: "Next: Ralph loop will extract test specifications automatically."
- **Stage 2**: "Next: Ralph loop will extract source specifications automatically."
- **Stage 3**: "Next: Ralph loop will synthesize PORT_TODO.md from all specs."
- **Stage 4**: "Next: Ralph loop is building. Check PORT_TODO.md for task progress. Build iterations: <n>, failures: <n>."
- **Stage 5**: "Next: Ralph loop will run parity audit. Almost done."
- **All complete**: "Porting complete. Review porting/PORT_AUDIT.md for the final parity report."

### 4. Show Quality Gate Status

For the current stage, show what's needed to advance:

- 0 -> 1: BASELINE.md, OUT_OF_SCOPE.md, and SEMANTIC_MISMATCHES.md must exist in porting/
- 1 -> 2: Every test file must have a corresponding .spec.md in porting/specs/from-tests/
- 2 -> 3: Every source module must have a corresponding .spec.md in porting/specs/from-src/
- 3 -> 4: PORT_TODO.md must exist with dependency-ordered tasks
- 4 -> 5: All tasks in PORT_TODO.md marked DONE, test_command passes
- 5 -> done: PORT_AUDIT.md shows no critical gaps

---

## Fallback Mode (no arguments, no state)

If `porting/PORT_STATE.md` exists, behave as **Status Mode**.

If it does not exist, show usage help:

```text
repo-clone: Automated codebase porting between languages

Usage:
  /repo-clone init <source-lang> <target-lang>   Initialize a porting project
  /repo-clone status                              Show current progress
  /repo-clone:help                                Explain the full workflow

Example:
  /repo-clone init rust typescript

The ralph loop drives the actual porting work. This command is for
interactive setup and status checking only.
```
