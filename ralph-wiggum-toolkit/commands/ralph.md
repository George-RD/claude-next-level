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
| `retro` | Run retrospective pipeline (all phases or specific phase) |
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

### Interactive Next Steps

After displaying status, analyze the project state and present the user with actionable options using AskUserQuestion. Tailor the options to the detected situation:

**If WIP changes exist AND IMPLEMENTATION_PLAN.md has TODO tasks:**

Use AskUserQuestion with these options:

- "Reconcile WIP against the plan (recommended)" — Audit uncommitted changes against IMPLEMENTATION_PLAN.md, mark completed tasks as DONE, describe completed work with a VCS commit, then continue building
- "Continue building from the plan" — Skip reconciliation, pick the next TODO task and start implementing
- "Show me the plan first" — Display IMPLEMENTATION_PLAN.md so I can review before deciding
- "I'll take it from here" — Just show the status, don't take any action

**If all specs are done but no plan exists:**

Use AskUserQuestion with:

- "Create the implementation plan" — Run `/ralph plan` to synthesize a plan from specs
- "I'll take it from here" — Just show the status

**If plan exists with TODO tasks and no WIP:**

Use AskUserQuestion with:

- "Start building" — Run `/ralph build` to begin implementing from the plan
- "Review the plan first" — Display IMPLEMENTATION_PLAN.md
- "I'll take it from here" — Just show the status

**If extraction phases are incomplete (port recipe):**

Use AskUserQuestion with:

- "Show me the extraction loop commands" — Display the headless loop commands to run
- "I'll take it from here" — Just show the status

Always include "I'll take it from here" as the last option so the user can opt out of any action.

---

## `retro` — Run Retrospective Pipeline

Run a post-project retrospective analysis across multiple phases.

### Arguments

- `/ralph retro` — Run all pending phases in order
- `/ralph retro --phase codegap` — Run only one specific phase
- `/ralph retro --from-phase implgap` — Run from a specific phase forward

Valid phase names: `codegap`, `implgap`, `plugingap`, `synthesis`, `explanations`, `todo`

### Init Completion (first run)

If `retro/retro_state.md` does not exist, complete the retrospective init before running phases:

1. **Detect source recipe:**
   - Read `ralph/manifest.json` → use `"recipe"` field (greenfield or port)
   - If not found, check `porting/manifest.json` → treat as port (legacy)
   - If neither exists but `IMPLEMENTATION_PLAN.md` exists → treat as uninitialized greenfield
   - If nothing found → error: "No Ralph project found. Run `/ralph init` first."

2. **Detect project directory:** Use the absolute path of the current working directory.

3. **Encode session JSONL path:** Take the absolute project path, replace all `/` with `-`, prepend `~/.claude/projects/` to form the session directory path.

4. **For port recipe:** Extract `source_lang`, `target_lang`, `target_root` from `ralph/manifest.json` (or `porting/manifest.json` for legacy).

5. **For greenfield recipe:** Detect `src_dir` from `ralph/manifest.json` (default: `src`).

6. **Detect spec_root and impl_root:**
   - Port: `spec_root` = `specs/`, `impl_root` = value of `target_root` from manifest
   - Greenfield: `spec_root` = `specs/`, `impl_root` = value of `src_dir` from manifest

7. **Write `retro/retro_state.md`:** Read the template from `recipes/retrospective/templates/retro_state_template.md`, substitute all placeholders (`{PROJECT_NAME}` (directory basename), `{PROJECT_DIR}`, `{DATE}` (today), `{SOURCE_RECIPE}`, `{SESSION_PATH}`, `{SPEC_ROOT}`, `{IMPL_ROOT}`, `{SOURCE_LANG}`, `{TARGET_LANG}`), write to `retro/retro_state.md`.

8. **Copy cross-reference standard:** Copy `recipes/retrospective/references/cross-ref-standard.md` to `retro/CROSS_REF_STANDARD.md`.

9. **Apply AGENTS.md substitutions:** Replace placeholders in `AGENTS.md` with detected values (same pattern as port recipe init — substitute `{SOURCE_RECIPE}`, `{SPEC_ROOT}`, `{IMPL_ROOT}`, and any language-specific placeholders).

### Phase Dispatch

After init is complete (or was already complete):

1. **Read phase status:** Parse `retro/retro_state.md` for the status of each phase (pending, running, done).

2. **Determine phases to run:**
   - No flags: run all phases with status `pending`, in order
   - `--phase <name>`: run only that one phase (even if already done — re-run it)
   - `--from-phase <name>`: run that phase and all subsequent phases

3. **For each phase to run:**
   - Read `recipes/retrospective/recipe.json` and look up the phase in `phase_models` to get the model name
   - Update phase status to `running` in `retro/retro_state.md`
   - Execute the phase prompt:

     ```
     claude -p --dangerously-skip-permissions --model {phase_model} --output-format stream-json < PROMPT_{phase}.md
     ```

   - On completion, update phase status to `done` in `retro/retro_state.md`

4. **Completion:** When all phases are done, display a summary:

   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Retrospective complete!

   Outputs:
     retro/codegap.md      — Code-spec gap analysis
     retro/implgap.md      — Implementation gap analysis
     retro/plugingap.md    — Plugin gap analysis
     retro/synthesis.md    — Cross-cutting synthesis
     retro/explanations.md — Session explanations
     retro/todo.md         — Improvement TODO list

   Next: Review retro/todo.md for actionable improvements.
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

### Status Integration

When `/ralph status` is called and a `retro/` directory exists, append a retrospective status section:

```
Retrospective:
  codegap       ✅ done
  implgap       ✅ done
  plugingap     ⏳ pending
  synthesis     ⏳ pending
  explanations  ⏳ pending
  todo          ⏳ pending
```

Read phase statuses from `retro/retro_state.md`. Use `✅ done` for completed phases, `🔄 running` for in-progress, and `⏳ pending` for not-yet-started.

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
  /ralph retro                           Run retrospective pipeline
  /ralph status                          Show project state
  /ralph cancel                          Cancel active loop
  /ralph help                            Full methodology guide

Recipes:
  greenfield (default)   Spec → Plan → Build for new features
  port                   Extract behavioral specs → Port to target language
  retrospective          Post-project analysis → Improvement TODO

Examples:
  /ralph init                                    # Greenfield (default)
  /ralph init --recipe port dart typescript       # Port recipe
  /ralph plan --max-iterations 3                  # Plan with limit
  /ralph build --completion-promise "all tests pass"  # Build with stop condition
```
