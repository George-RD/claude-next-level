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
| (none) | Smart entry point: detect state, route to init/status/resume |

---

## Recipe / State Detection (v2)

All subcommands that need to know the active recipe use the following detection order:

1. **v2 state machine:** `ralph/state.json` exists — read `"recipe"` and `"phase"` fields. This is the authoritative source for v2 projects.
2. **v1 manifest:** `ralph/manifest.json` exists — read `"recipe"` field. Used for v1 projects or as fallback.
3. **Legacy repo-clone:** `porting/manifest.json` exists — treat as port recipe.
4. **Uninitialized greenfield:** No manifest but `PROMPT_plan.md`/`PROMPT_build.md` exist.
5. **Nothing:** No project found.

When `ralph/state.json` exists, the project is a v2 project and all v2 behaviors apply.

---

## `init` — Initialize Project

Run the init script:

```bash
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

### Init Exit Recommendation

After init.sh completes and all interactive steps are done, display:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Init Complete

What was done:
  Scaffolded {recipe} project with {language} configuration
  Quality gates: {tier 1 cmd}, {tier 2 cmd}, {tier 3 cmd}

What to watch for:
  Verify gate commands in ralph/state.json match your toolchain
  (e.g., test runner, linter, type checker)

Recommended next action:
  {For greenfield: Run `/ralph spec` to define JTBD requirements}
  {For port: Run `/ralph plan` to create the implementation plan}
  {For retrospective: Run `/ralph retro` to begin the analysis}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Read ralph/state.json for gate commands and recipe type.

---

## `plan` — Run Planning Loop

Detect the active recipe (see Recipe / State Detection above), then call setup-loop with the correct prompt file:

1. Read `ralph/state.json` (v2) or `ralph/manifest.json` (v1) and extract the `"recipe"` field
2. If recipe is `port` (or `porting/manifest.json` exists as legacy): add `--prompt-file PROMPT_port.md`
3. If recipe is `greenfield` (or no manifest): use default mode behavior (no `--prompt-file`)

**For greenfield** (default):

```bash
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

**Dual output requirement (v2):**

The planning agent must output BOTH artifacts:

1. **IMPLEMENTATION_PLAN.md** — Human-readable plan structured with `### T001` blocks for each task. Each block should include the task description, acceptance criteria, file paths, and dependency notes.
2. **ralph/tasks.json** — Machine-readable JSON array of task objects. Each task object must have:
   - `id` (string): Task ID matching `T\d+` pattern (e.g., `"T001"`, `"T002"`)
   - `description` (string): What the task accomplishes
   - `spec` (string): Path to the spec file this task implements (e.g., `"specs/auth.md"`)
   - `acceptance` (string): Concrete completion criteria (must be verifiable)
   - `dependencies` (array of strings): Task IDs that must be completed first (e.g., `["T001", "T003"]`). Use `[]` for tasks with no dependencies.

The `### T001` blocks in IMPLEMENTATION_PLAN.md must correspond 1:1 with entries in ralph/tasks.json — same IDs, same count.

**Post-plan validation (v2):**

After the planning agent completes, run plan-to-state.sh to validate tasks.json and merge into state.json:

```bash
"${CLAUDE_PLUGIN_ROOT}/core/scripts/plan-to-state.sh"
```

This script:

- Validates that ralph/tasks.json is well-formed (correct types, no duplicate IDs, T\d+ pattern)
- Cross-checks task count against IMPLEMENTATION_PLAN.md
- Merges tasks into ralph/state.json with default status fields
- Sets `awaitingApproval: true` so the user must review before building

If validation fails, report the errors to the user and ask them to fix tasks.json or re-run planning.

**When done:** The stop hook feeds the same prompt back. When the plan looks solid, output `<promise>PLAN COMPLETE</promise>` if a completion promise was set.

CRITICAL: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE.

### Plan Exit Recommendation

When plan-to-state.sh completes successfully, display:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plan Complete

What was done:
  {n} tasks planned across {dependency levels} dependency tiers
  Estimated effort: {distribution of task complexity}

What to watch for:
  {Flag tasks with >5 behaviors — suggest splitting}
  {Flag tasks with external dependencies}
  Verify gate commands in ralph/state.json match your toolchain

Recommended next action:
  Review IMPLEMENTATION_PLAN.md, then run `/ralph build`.
  The build loop enforces quality gates at 3 tiers (compile, test, strict).
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Read ralph/tasks.json to extract the stats. This is generated by the `/ralph` command agent after plan-to-state.sh exits, not by the shell script itself.

---

## `build` — Run Build Loop

Same recipe detection as `plan`. Run ONE of these based on detected recipe:

### Pre-build approval gate (v2)

Before starting the build loop, check for the v2 approval gate:

1. Read `ralph/state.json`
2. If `awaitingApproval` is `true`:
   - Display the current state: phase, task count, first task ID and description
   - Use AskUserQuestion with options:
     - "I've reviewed the plan — start building" — Set `awaitingApproval: false` in state.json, then proceed to start the build loop
     - "Show me the plan first" — Display IMPLEMENTATION_PLAN.md and ralph/tasks.json summary, then ask again
     - "Cancel" — Do not start the build loop
   - Only proceed to the build loop after `awaitingApproval` has been set to `false`
3. If `awaitingApproval` is `false` (or no state.json exists): proceed directly to the build loop

### Build loop dispatch

**For greenfield** (default):

```bash
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

### Build Exit Recommendation

When the build loop completes (all tasks done, Tier 3 passed), the `/ralph` command agent reads ralph/state.json and displays:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Build Complete

What was done:
  {completed} of {total} tasks completed, {fix_tasks} fix tasks
  {commits} commits made ({uncommitted_tasks} tasks without commits — WARNING if > 0)
  Quality gates: Tier 3 passed

What to watch for:
  {Scan for todo!()/TODO/FIXME stubs in implementation — warn if found}
  {Flag any tasks that were omnibus (>5 behaviors)}

Recommended next action:
  Run `/ralph retro` to audit spec-vs-implementation alignment
  and identify gaps before shipping.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Read ralph/state.json to extract task stats. Count commits with `git log --oneline | wc -l` (or jj equivalent). Scan for stubs with `grep -r 'todo!\|TODO\|FIXME\|unimplemented!' {impl_root}`.

---

## `status` — Show Project State

Detect the active recipe and render status accordingly.

### Recipe Detection Order

1. `ralph/state.json` exists → v2 project, read `"recipe"` and `"phase"` fields
2. `ralph/manifest.json` exists → v1 project, read `"recipe"` field
3. `porting/manifest.json` exists → treat as port (legacy repo-clone)
   - Offer migration: "Found porting/manifest.json from repo-clone v2. Migrate to ralph/manifest.json? [y/N]"
   - Migration: add `"recipe": "port"` and `"version": "3.0.0"`, move to ralph/manifest.json
4. No manifest but `PROMPT_plan.md`/`PROMPT_build.md` exist → treat as uninitialized greenfield
5. Nothing → "No Ralph project found. Run `/ralph init` to get started."

### v2 Status (when ralph/state.json exists)

When `ralph/state.json` is detected, display the v2-specific status dashboard:

```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ralph v2 — Project Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Recipe:     {recipe}
Phase:      {phase}
Iteration:  {iteration}

Current Task: {currentTaskId} — {task description}
Task Progress: {completed}/{total} tasks

Gate History (last 5):
  #{N}  {gate_name}  {pass/fail}  {timestamp or iteration}
  #{N-1} ...

Awaiting Approval: {yes/no}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Read all fields from `ralph/state.json`:

- `recipe`, `phase`, `iteration`, `currentTaskId`, `awaitingApproval`
- `tasks` array: count total, count those with `status: "done"` for progress
- `currentTaskId`: look up the matching task in `tasks` array to get its description
- `gateHistory` array (if present): show the last 5 entries with gate name, result, and iteration

After the v2 status dashboard, also show the standard status information (specs count, AGENTS.md presence, IMPLEMENTATION_PLAN.md status, recent git commits) as supplementary context.

### Greenfield Status

Show: specs count, AGENTS.md presence, IMPLEMENTATION_PLAN.md status, active loop info, recent git tags/commits.

### Port Status

Read manifest and show per-phase progress table with file counts. Regenerate `ralph/PORT_STATE.md`.

### Interactive Next Steps

After displaying status, analyze the project state and present the user with actionable options using AskUserQuestion. Tailor the options to the detected situation:

**If v2 project with `awaitingApproval: true`:**

Use AskUserQuestion with:

- "Review and approve the plan" — Display IMPLEMENTATION_PLAN.md and tasks.json, then run the build approval flow
- "Show v2 state details" — Display the full ralph/state.json contents
- "I'll take it from here" — Just show the status, don't take any action

**If v2 project in build phase with tasks remaining:**

Use AskUserQuestion with:

- "Continue building" — Run `/ralph build` to resume implementing from the current task
- "Show the current task details" — Display the current task from state.json and its context
- "Show me the plan" — Display IMPLEMENTATION_PLAN.md
- "I'll take it from here" — Just show the status, don't take any action

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

Valid phase names: `codegap`, `implgap`, `plugingap`, `synthesis`, `explanations`, `opsaudit`, `todo`, `handover`

### Init Completion (first run)

If `retro/retro_state.md` does not exist, complete the retrospective init before running phases:

1. **Detect source recipe:**
   - Read `ralph/state.json` → use `"recipe"` field (v2)
   - If not found, read `ralph/manifest.json` → use `"recipe"` field (greenfield or port)
   - If not found, check `porting/manifest.json` → treat as port (legacy)
   - If neither exists but `IMPLEMENTATION_PLAN.md` exists → treat as uninitialized greenfield
   - If nothing found → error: "No Ralph project found. Run `/ralph init` first."

2. **Detect project directory:** Use the absolute path of the current working directory.

3. **Encode session JSONL path:** Take the absolute project path, replace all `/` with `-`, prepend `~/.claude/projects/` to form the session directory path.

4. **For port recipe:** Extract `source_lang`, `target_lang`, `target_root` from `ralph/state.json` or `ralph/manifest.json` (or `porting/manifest.json` for legacy).

5. **For greenfield recipe:** Detect `src_dir` from `ralph/state.json` or `ralph/manifest.json` (default: `src`).

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

4. **Completion:** When all phases are done, read the output files to extract stats, then display:

   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Retrospective complete!

   What was done:
     {n} code gaps, {m} implementation gaps, {p} plugin gaps
     {q} themes synthesized, {r} session explanations
     {o} operational findings
     {s} improvement items ({P0 count} P0, {P1 count} P1, {P2 count} P2)

   What to watch for:
     Top theme: {EVR-001 title} ({n} gaps)
     {m} items are plugin-track (fix in plugin repo)
     {o} operational issues found (commit discipline, workflow compliance, etc.)

   Outputs:
     retro/codegap.md            — Code-spec gap analysis
     retro/implgap.md            — Implementation gap analysis
     retro/plugingap.md          — Plugin gap analysis
     retro/synthesis.md          — Cross-cutting synthesis
     retro/explanations.md       — Session explanations
     retro/opsaudit.md           — Operational audit
     retro/todo.md               — Improvement TODO list
     retro/HANDOVER_PROJECT.md   — Project handover (start here)
     retro/HANDOVER_PLUGIN.md    — Plugin handover (for plugin repo)

   Recommended next action:
     Review retro/HANDOVER_PROJECT.md for prioritized workstreams.
     For plugin fixes, take retro/HANDOVER_PLUGIN.md to the plugin repo.
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

### Status Integration

When `/ralph status` is called and a `retro/` directory exists, append a retrospective status section:

```
Retrospective:
  codegap       done
  implgap       done
  plugingap     pending
  synthesis     pending
  explanations  pending
  opsaudit      pending
  todo          pending
  handover      pending
```

Read phase statuses from `retro/retro_state.md`. Use `done` for completed phases, `running` for in-progress, and `pending` for not-yet-started.

---

## `cancel` — Cancel Active Loop

Check if `.claude/ralph-wiggum.local.md` exists.

- If missing: "No active Ralph loop found."
- If present: Read mode and iteration, remove file, report "Cancelled Ralph [MODE] loop at iteration N."

---

## `help` — Show Full Guide

Display the combined help from both methodologies. Defer to commands/help.md.

---

## Phase Gates (v2)

When `ralph/state.json` exists, phase transitions are gated mechanically:

| Transition | Gate | Mechanism |
|-----------|------|-----------|
| spec -> plan | User confirms specs are complete | `awaitingApproval: true` in state.json. User must review specs and confirm before planning begins. |
| plan -> build | User reviews plan + tasks.json | `awaitingApproval: true` set by plan-to-state.sh after tasks are merged. User must review plan and approve before building. |
| build -> done | Tier 3 quality gate passes | Mechanical — the build loop's quality gate determines completion. No human approval needed. |

The `awaitingApproval` field in state.json is the single source of truth for whether a phase transition is blocked. Subcommands must check this field before proceeding.

---

## Fallback (no subcommand) — Smart Entry Point

When `/ralph` is invoked with no subcommand, act as an intelligent router. Detect the current project state and guide the user to the right next action.

### Detection sequence

1. **Check for active loop:** If `.claude/ralph-wiggum.local.md` exists AND its `session_id` matches the current session, an in-session loop is active. Read the `mode` and `iteration` fields. Tell the user:
   - "You have an active Ralph [MODE] loop at iteration N."
   - Use AskUserQuestion with options:
     - "Continue the loop" — Re-read the prompt file and continue working
     - "Cancel the loop" — Run the `cancel` logic (remove state file)
     - "Show status" — Fall through to status display

2. **Check for v2 state:** If `ralph/state.json` exists, this is a v2 project. Run the full `status` subcommand logic with v2 status dashboard and v2-aware interactive next steps.

3. **Check for existing project:** Follow the remaining recipe detection order (ralph/manifest.json -> porting/manifest.json -> PROMPT files -> nothing).

4. **If project found:** Run the full `status` subcommand logic (display status + interactive next steps). This is identical to what `/ralph status` does.

5. **If no project found:** Welcome the user and help them get started. Use AskUserQuestion with:
   - "Start a new feature (greenfield)" — Run `/ralph init`
   - "Port an existing codebase" — Ask for source and target languages, then run `/ralph init --recipe port <source> <target>`
   - "Run a retrospective on a completed project" — Run `/ralph init --recipe retrospective`
   - "Show help" — Display the full help guide
