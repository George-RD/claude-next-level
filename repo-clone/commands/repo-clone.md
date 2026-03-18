---
name: repo-clone
description: "Initialize a porting project, check status, or get help"
argument-hint: "[init <source-lang> <target-lang> | status]"
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep"]
---

# /repo-clone Command

This is the **interactive** entry point for the repo-clone plugin. It is used for project setup and status checking. The actual porting work is driven by headless `claude -p --model haiku` loops using the PROMPT files -- not this command.

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

| Lang         | target_root  | test_command     | build_command        |
|--------------|--------------|------------------|----------------------|
| typescript   | ./src-ts     | npm test         | npm run build        |
| python       | ./src-py     | pytest           | python -m py_compile |
| go           | ./src-go     | go test ./...    | go build ./...       |
| rust         | ./src-rs     | cargo test       | cargo build          |
| java         | ./src-java   | mvn test         | mvn compile          |

Use this table for both source (auto-detect) and target (from user choice) languages. If a language is not in the table, ask the user for the commands.

### 4. Scan and Categorize

Scan the source repo for all files under the detected source root. Categorize each file as one of: **test**, **source**, **config**, **asset**, **doc**.

Use language-specific patterns to identify test files:

| Pattern | Language |
|---------|----------|
| `test/`, `tests/`, `__tests__/` | Directory-based (any) |
| `_test.dart` | Dart |
| `test_*.py`, `*_test.py` | Python |
| `*_test.go` | Go |
| `*_spec.rb`, `*_test.rb` | Ruby |
| `*.test.ts`, `*.spec.ts`, `*.test.js`, `*.spec.js` | TypeScript/JavaScript |
| `*_test.rs`, `tests/` | Rust |
| `*Test.java`, `*Tests.java` | Java |
| `*_test.swift`, `*Tests.swift` | Swift |

Config files: `*.json`, `*.yaml`, `*.yml`, `*.toml`, `*.ini`, `*.cfg`, `Makefile`, `Dockerfile`, `*.lock`
Asset files: images, fonts, binaries, generated files
Doc files: `*.md`, `*.txt`, `*.rst`, `LICENSE`, `README*`

Show the user a summary:

```text
Scan Results:
  Test files:   N
  Source files:  M
  Config files:  K
  Assets (skip): J
  Docs (skip):   L
```

Recommend phases: if tests found, recommend extract-tests + extract-src. If no tests found, recommend extract-src only.

### 5. Create Directory Structure

Create the directory structure:

```text
specs/
  tests/
  src/
porting/
```

### 6. Build manifest.json

Read the manifest template from the plugin's `data/templates/manifest-template.json`. Populate it with detected values:

- Set `source_lang`, `target_lang`, `source_root`, `target_root`, `test_command`, `build_command`, `created`
- Populate `phases.extract-tests.files` with every detected test file, each as `"<filepath>": {"status": "pending"}`
- Populate `phases.extract-src.files` with every detected source file, each as `"<filepath>": {"status": "pending"}`
- If no test files were found, set `phases.extract-tests.status` to `"skipped"`

Write the result to `porting/manifest.json`.

### 7. Write PORT_STATE.md

Write `porting/PORT_STATE.md` as a human-readable view of the manifest state (substitute actual values):

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

### 8. Scaffold PROMPT Files and AGENTS.md

Copy templates from the plugin's `data/templates/` directory into the project root, substituting detected values.

#### 8a. Copy PROMPT_extract_tests.md

Read `data/templates/PROMPT_extract_tests.md` from the plugin directory. Write the result to `PROMPT_extract_tests.md` in the project root.

#### 8b. Copy PROMPT_extract_src.md

Read `data/templates/PROMPT_extract_src.md` from the plugin directory. Write the result to `PROMPT_extract_src.md` in the project root.

#### 8c. Copy PROMPT_port.md

Read `data/templates/PROMPT_port.md` from the plugin directory. Write the result to `PROMPT_port.md` in the project root.

#### 8d. Copy AGENTS.md

Read `data/templates/AGENTS_port.md` from the plugin directory. Replace the following placeholders using detected values and the smart defaults table:

| Placeholder | Value |
|-------------|-------|
| `{SOURCE_LANG}` | source language name |
| `{TARGET_LANG}` | target language name |
| `{SOURCE_ROOT}` | detected source root |
| `{TARGET_ROOT}` | smart-defaults target root |
| `{SOURCE_TEST_CMD}` | smart-defaults test command for source language |
| `{TARGET_TEST_CMD}` | smart-defaults test command for target language |
| `{TARGET_BUILD_CMD}` | smart-defaults build command for target language |

Write the result to `AGENTS.md` in the project root.

#### 8e. Create SEMANTIC_MISMATCHES.md

Create `porting/SEMANTIC_MISMATCHES.md` with known divergences for the source/target language pair. Read `references/semantic-mappings.md` from the plugin directory and extract the relevant rows for the two languages. Include sections for: Error Handling, Type Systems, Concurrency, Module Systems, and Common Gotchas.

#### 8f. Create IMPLEMENTATION_PLAN.md

Create an empty `IMPLEMENTATION_PLAN.md` in the project root:

```markdown
<!-- Generated by repo-clone init - will be populated during spec extraction and planning -->
```

### 9. Confirm to User

Tell the user:

- What was created (directory structure, manifest.json, PORT_STATE.md, PROMPT files, AGENTS.md, SEMANTIC_MISMATCHES.md, IMPLEMENTATION_PLAN.md)
- The detected/chosen settings (languages, roots, test commands)
- The scan results (N test files, M source files tracked in manifest)
- How to run the porting loops:
  - **Extract test specs:** `while :; do cat PROMPT_extract_tests.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done`
  - **Extract source specs:** `while :; do cat PROMPT_extract_src.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done`
  - **Port implementation:** `while :; do cat PROMPT_port.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done`
  - Each iteration will read the manifest, find the next pending file, extract its spec, and mark it done. The loop terminates when all files are processed.
- **Safety:** `--dangerously-skip-permissions` bypasses all tool approval. Run only in sandboxed environments (Docker, Fly, E2B) or trusted repos.
- That they can check progress anytime with `/repo-clone status`
- That `/repo-clone:help` explains the full workflow

---

## Status Mode (`/repo-clone status`)

Read from `porting/manifest.json` and display a progress summary.

### 1. Read State

Read `porting/manifest.json`. Parse the JSON to extract all fields including per-file status within each phase.

### 2. Display Progress Table

Show a formatted summary with per-file progress:

```text
PORT STATUS: <source_lang> -> <target_lang>
================================================

| Phase          | Status    | Progress        |
|----------------|-----------|-----------------|
| Extract Tests  | <status>  | N/M files done  |
| Extract Source | <status>  | N/M files done  |
| Plan           | <status>  |                 |
| Build          | <status>  |                 |
| Audit          | <status>  |                 |

Model: <default_model>
Created: <created>
```

Count files with `"status": "done"` vs total files in each phase to compute progress.

### 3. Show Next Action

Based on the phase statuses, recommend the next action:

- **extract-tests pending**: "Next: Run the extract-tests loop to extract behavioral specs from test files."
- **extract-src pending** (after tests done): "Next: Run the extract-src loop to extract behavioral specs from source files."
- **plan pending**: "Next: Synthesize IMPLEMENTATION_PLAN.md from all specs."
- **build pending**: "Next: Run the porting loop to implement tasks from the plan."
- **audit pending**: "Next: Run parity audit. Almost done."
- **All complete**: "Porting complete. Review porting/PORT_AUDIT.md for the final parity report."

### 4. Show Quality Gate Status

For the current phase, show what's needed to advance:

- extract-tests -> extract-src: Every test file in the manifest must have a corresponding spec in `specs/tests/`
- extract-src -> plan: Every source file in the manifest must have a corresponding spec in `specs/src/`
- plan -> build: `IMPLEMENTATION_PLAN.md` must contain dependency-ordered tasks (not just the empty init placeholder)
- build -> audit: All tasks in `IMPLEMENTATION_PLAN.md` marked DONE, test_command passes
- audit -> done: PORT_AUDIT.md shows no critical gaps

### 5. Regenerate PORT_STATE.md

After reading the manifest, regenerate `porting/PORT_STATE.md` from the manifest state so the human-readable view stays in sync.

---

## Fallback Mode (no arguments, no state)

If `porting/manifest.json` exists, behave as **Status Mode**.

If it does not exist, show usage help:

```text
repo-clone: Automated codebase porting between languages

Usage:
  /repo-clone init <source-lang> <target-lang>   Initialize a porting project
  /repo-clone status                              Show current progress
  /repo-clone:help                                Explain the full workflow

Example:
  /repo-clone init rust typescript

The headless loop drives the actual porting work. This command is for
interactive setup and status checking only.
```

$ARGUMENTS
