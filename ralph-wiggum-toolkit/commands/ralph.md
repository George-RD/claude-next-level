---
name: ralph
description: "Unified entry point for Ralph Wiggum Toolkit: init, plan, build, status, cancel, help"
argument-hint: "<subcommand> [options]"
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep"]
---

# /ralph Command — Unified Dispatcher

Parse the user's arguments to determine which subcommand to run. The first positional argument is the subcommand.

## Subcommand Dispatch

| Subcommand | Action |
|------------|--------|
| `init` | Initialize a project with a recipe |
| `spec` | Run Phase 1: JTBD interview and spec writing (greenfield only) |
| `plan` | Run planning loop |
| `build` | Run build loop |
| `status` | Show project state |
| `cancel` | Cancel active loop |
| `help` | Show full methodology guide |
| (none) | Show usage help |

---

## `init` — Initialize Project

Run the init script:

```!
"${CLAUDE_PLUGIN_ROOT}/core/scripts/init.sh" $ARGUMENTS
```

After the script completes, the /ralph command (the markdown instructions here) handles the interactive parts that the shell script cannot:

### For port recipe (`--recipe port`)

After `init.sh` creates the directory structure and copies PROMPT files, the `/ralph` command must complete these interactive steps:

1. **Auto-detect source root**: Search for `src/`, `lib/`, `app/` directories. If found, use as `source_root`. If not, ask the user.

2. **Apply smart defaults** based on target language:

| Lang | target_root | test_command | build_command |
|------|-------------|-------------|---------------|
| typescript | ./src-ts | npm test | npm run build |
| python | ./src-py | pytest | python -m py_compile |
| go | ./src-go | go test ./... | go build ./... |
| rust | ./src-rs | cargo test | cargo build |
| java | ./src-java | mvn test | mvn compile |

3. **Scan and categorize** all files under source root as: test, source, config, asset, doc. Use language-specific test patterns:
   - `test/`, `tests/`, `__tests__/` — directory-based
   - `_test.dart` — Dart
   - `test_*.py`, `*_test.py` — Python
   - `*_test.go` — Go
   - `*.test.ts`, `*.spec.ts` — TypeScript/JS
   - `*_test.rs` — Rust
   - `*Test.java` — Java

4. **Build manifest**: Read `recipes/port/templates/manifest-template.json`, populate with detected values, per-file tracking in extract-tests and extract-src phases. Write to `ralph/manifest.json`.

5. **Write PORT_STATE.md**: Write `ralph/PORT_STATE.md` with human-readable manifest view.

6. **Apply AGENTS.md substitutions**: Replace ALL placeholders in AGENTS.md: `{SOURCE_LANG}`, `{TARGET_LANG}`, `{SOURCE_ROOT}`, `{TARGET_ROOT}`, `{SOURCE_TEST_CMD}`, `{TARGET_TEST_CMD}`, `{TARGET_BUILD_CMD}` with the detected/chosen values. (init.sh copies the template unchanged — this step owns all substitutions.)

7. **Create SEMANTIC_MISMATCHES.md**: Read `recipes/port/references/semantic-mappings.md`, extract relevant rows for the language pair, write to `ralph/SEMANTIC_MISMATCHES.md`.

8. **Show next steps**: Display the extraction loop commands.

---

## `plan` — Run Planning Loop

Detect the active recipe, then call setup-loop with the correct prompt file:

1. Read `ralph/manifest.json` and extract the `"recipe"` field
2. If recipe is `port` (or `porting/manifest.json` exists as legacy): add `--prompt-file PROMPT_port.md`
3. If recipe is `greenfield` (or no manifest): use default mode behavior (no `--prompt-file`)

**For greenfield** (default):

```!
"${CLAUDE_PLUGIN_ROOT}/core/scripts/setup-loop.sh" --mode plan $ARGUMENTS
```

**For port** (only run this one instead if recipe is port):

```text
"${CLAUDE_PLUGIN_ROOT}/core/scripts/setup-loop.sh" --mode plan --prompt-file PROMPT_port.md $ARGUMENTS
```

After setup, you are in PLANNING mode. Follow the prompt that was loaded.

**Rules:**

- Plan only. Do NOT implement anything.
- Don't assume functionality is missing — confirm with code search first.
- Use parallel subagents to study specs and source code simultaneously.
- Search for TODOs, minimal implementations, placeholders, skipped/flaky tests.

**When done:** The stop hook feeds the same prompt back. When the plan looks solid, output `<promise>PLAN COMPLETE</promise>` if a completion promise was set.

CRITICAL: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE.

---

## `build` — Run Build Loop

Same recipe detection as `plan`. Run ONE of these based on detected recipe:

**For greenfield** (default):

```!
"${CLAUDE_PLUGIN_ROOT}/core/scripts/setup-loop.sh" --mode build $ARGUMENTS
```

**For port** (only run this one instead if recipe is port):

```text
"${CLAUDE_PLUGIN_ROOT}/core/scripts/setup-loop.sh" --mode build --prompt-file PROMPT_port.md $ARGUMENTS
```

After setup, you are in BUILDING mode. Follow the prompt that was loaded.

**Each iteration:**

1. Orient — Study specs
2. Read plan — Study IMPLEMENTATION_PLAN.md
3. Select — Pick the most important unfinished task
4. Investigate — Search codebase before changing anything
5. Implement — Use parallel subagents for file operations
6. Validate — Run tests
7. Update plan — Mark task done, note discoveries
8. Update AGENTS.md — If you learned something operational
9. Commit — git add + git commit with descriptive message

CRITICAL: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE.

---

## `status` — Show Project State

Detect the active recipe and render status accordingly.

### Recipe Detection Order

1. `ralph/manifest.json` exists → read `"recipe"` field
2. `porting/manifest.json` exists → treat as port (legacy repo-clone)
   - Offer migration: "Found porting/manifest.json from repo-clone v2. Migrate to ralph/manifest.json? [y/N]"
   - Migration: add `"recipe": "port"` and `"version": "3.0.0"`, move to ralph/manifest.json
3. No manifest but `PROMPT_plan.md`/`PROMPT_build.md` exist → treat as uninitialized greenfield
4. Nothing → "No Ralph project found. Run `/ralph init` to get started."

### Greenfield Status

Show: specs count, AGENTS.md presence, IMPLEMENTATION_PLAN.md status, active loop info, recent git tags/commits.

### Port Status

Read manifest and show per-phase progress table with file counts. Regenerate `ralph/PORT_STATE.md`.

---

## `cancel` — Cancel Active Loop

Check if `.claude/ralph-wiggum.local.md` exists.

- If missing: "No active Ralph loop found."
- If present: Read mode and iteration, remove file, report "Cancelled Ralph [MODE] loop at iteration N."

---

## `help` — Show Full Guide

Display the combined help from both methodologies. Defer to commands/help.md.

---

## Fallback (no subcommand)

```text
Ralph Wiggum Toolkit — Recipe-based autonomous dev loops

Usage:
  /ralph init [--recipe <name>] [args]   Initialize project with recipe
  /ralph spec [topic]                    Phase 1: JTBD interview (greenfield)
  /ralph plan [--max-iterations N]       Run planning loop
  /ralph build [--max-iterations N]      Run build loop
  /ralph status                          Show project state
  /ralph cancel                          Cancel active loop
  /ralph help                            Full methodology guide

Recipes:
  greenfield (default)   Spec → Plan → Build for new features
  port                   Extract behavioral specs → Port to target language

Examples:
  /ralph init                                    # Greenfield (default)
  /ralph init --recipe port dart typescript       # Port recipe
  /ralph plan --max-iterations 3                  # Plan with limit
  /ralph build --completion-promise "all tests pass"  # Build with stop condition
```
