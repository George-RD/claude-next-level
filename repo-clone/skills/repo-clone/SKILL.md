---
name: repo-clone
description: "Use when porting code between languages, running ralph loops for codebase migration, extracting behavioral specs, or building PORT_TODO task lists. Core methodology for the repo-clone plugin."
---

# Porting Methodology

## 1. Philosophy & Overview

### The Ralph Wiggum Loop

Porting is driven by a simple single-objective bash loop:

```bash
while :; do cat PROMPT_port.md | claude -p ; done
```

Each iteration runs `claude -p` (piped mode). This means:

- **Fresh context every iteration.** Zero memory of previous runs.
- **Disk is your only memory.** PORT_STATE.md, specs/, PORT_TODO.md are the complete record.
- **One objective per iteration.** Read state, do one thing, update state, exit.
- **Fitness = tests pass.** Commit on green, hard-revert on red.

### You Are a Scheduler, Not a Worker

The primary context window (you) is a SCHEDULER. This is the cardinal rule.

**Do directly:** Read PORT_STATE.md, parse frontmatter, decide what stage to run, write state updates, run git commands, run the test command.

**Delegate to subagents:** Reading source files, reading test files, extracting behavioral specs, checking parity between spec and implementation. Always spawn with `run_in_background: true`. Collect results when they return.

Subagents are WORKERS within a single iteration. They are not sub-loops. They read files, extract structured information, and return it to you. You write the output to disk.

### State Machine

State lives in `/porting/PORT_STATE.md` with YAML frontmatter. The `current_stage` field drives behavior. The six stages form a linear pipeline:

| Stage | Name | What Happens |
|-------|------|--------------|
| 0 | Freeze | Snapshot baseline: commit hash, test results, scope exclusions, mismatch catalog |
| 1 | Extract Tests | Subagents read test files, produce behavioral specs in specs/from-tests/ |
| 2 | Extract Source | Subagents read source files, produce behavioral specs in specs/from-src/ |
| 3 | Plan | Synthesize all specs into dependency-ordered PORT_TODO.md |
| 4 | Build | One task per iteration: implement, test, commit or revert |
| 5 | Audit | Subagents check every module for spec parity, produce PORT_AUDIT.md |

Each stage has a quality gate. The gate must pass before `current_stage` increments. If the gate fails, retry the current stage next iteration.

### Disk Layout

```
/porting/
  PORT_STATE.md              # YAML frontmatter state machine
  BASELINE.md                # Source commit hash, test results at freeze time
  OUT_OF_SCOPE.md            # Files/patterns excluded from porting
  SEMANTIC_MISMATCHES.md     # Language-pair-specific translation patterns
  specs/
    from-tests/              # {module}.spec.md per test file
    from-src/                # {module}.spec.md per source module
  PORT_TODO.md               # Dependency-ordered build tasks
  PORT_AUDIT.md              # Final parity report
  golden-tests/              # Reference test outputs
```

---

## 2. Behavioral Spec Format

Specs describe WHAT code does, not HOW. Every spec file follows this structure:

```markdown
# Module: {module_name}
> Source: {path/to/file.ext}

## Behavior: {behavior_name}

**Description:** One-sentence summary of what this behavior does.

**Inputs:**
- `param_name: Type` — description

**Outputs:**
- `ReturnType` — description

**Side effects:**
- File I/O, network calls, state mutations, etc.

**Error cases:**
- Condition → outcome (e.g., "empty input → returns Err(InvalidInput)")

**Citations:**
- [source:src/parser.rs:45-82]
- [test:tests/parser_test.rs:10-35]
- [see-also:specs/from-tests/parser.spec.md]
```

### Citation Conventions

- `[source:path:start-end]` — references source code lines
- `[test:path:start-end]` — references test code lines
- `[see-also:specs/from-tests/module.spec.md]` — cross-references another spec
- Line ranges are inclusive. Use the path relative to the repository root.

### Extraction Rules

- One spec file per source module or test file.
- Group related behaviors under the same module spec.
- If a test file tests multiple modules, cite the relevant source specs with `[see-also:]`.
- Omit implementation details (algorithms, data structures, internal helpers) unless they define externally observable behavior.

---

## 3. Semantic Mismatch Quick Reference

When porting between languages, these patterns require deliberate translation decisions, not mechanical line-by-line copying. Record project-specific decisions in `/porting/SEMANTIC_MISMATCHES.md`.

### Error Handling

| Pattern | Rust | TypeScript | Python | Go |
|---------|------|------------|--------|----|
| Recoverable error | `Result<T, E>` | throw/catch or `Result` type | raise/except | `(val, err)` tuple |
| Absence | `Option<T>` | `T \| undefined` | `Optional[T]` or `None` | zero value + ok bool |
| Error propagation | `?` operator | try/catch or `.map()` | try/except chains | `if err != nil` |
| Panic/unrecoverable | `panic!()` | `throw` (uncaught) | `raise` (uncaught) | `panic()` |

**Decision required:** Map Result/Option to exceptions? To a Result monad library? To union types? Document the choice per project.

### Type Systems

| Pattern | Rust | TypeScript | Python | Go |
|---------|------|------------|--------|----|
| Sum types / ADTs | `enum` with data | discriminated unions | `@dataclass` + `Union` | interface + type switch |
| Traits / interfaces | `trait` | `interface` | `Protocol` / ABC | `interface` |
| Generics | `<T: Bound>` | `<T extends X>` | `Generic[T]` | `[T Constraint]` |
| Newtype wrapper | `struct Foo(Bar)` | branded types | `NewType` | `type Foo Bar` |

### Concurrency

| Pattern | Rust | TypeScript | Python | Go |
|---------|------|------------|--------|----|
| Async function | `async fn` → `Future` | `async` → `Promise` | `async def` → coroutine | goroutine |
| Await | `.await` | `await` | `await` | channels / `sync.WaitGroup` |
| Parallelism | `tokio::spawn` | `Promise.all` | `asyncio.gather` | `go func()` |
| Mutex | `Mutex<T>` | N/A (single-threaded) | `asyncio.Lock` | `sync.Mutex` |

### Module Systems

| Pattern | Rust | TypeScript | Python | Go |
|---------|------|------------|--------|----|
| Visibility | `pub` / `pub(crate)` | `export` | `_` prefix convention | capitalization |
| Module boundary | `mod` + file | file = module | file = module | directory = package |
| Re-export | `pub use` | `export { } from` | `__all__` | N/A |

### Testing Frameworks

| Rust | TypeScript | Python | Go |
|------|------------|--------|----|
| `#[test]` | `it()/test()` (jest/vitest) | `def test_*` (pytest) | `func Test*` |
| `#[should_panic]` | `expect().toThrow()` | `pytest.raises()` | `t.Fatal()` pattern |
| `assert_eq!` | `expect().toBe()` | `assert ==` | `if got != want` |

### Anti-Patterns

- **Do not** port line-by-line. Port behavior-by-behavior using the specs.
- **Do not** port macros mechanically. Understand what the macro expands to and use the target idiom.
- **Do not** port build configs (Cargo.toml, Makefile). Create target-native build setup.
- **Do not** port internal helper functions unless they serve externally observable behavior.
- **Do not** preserve source file structure if the target language has different conventions.
- **Do** use target-language idioms. A Rust port to Go should look like Go, not Rust-in-Go.

---

## 4. Ralph Loop Iteration Protocol

You are running a porting iteration. You have ZERO context from previous iterations.
Everything you need is on disk or discoverable via subagents.

### Your Role: Scheduler

You are the primary context window. Act as a SCHEDULER:

- NEVER read source or test files directly. Spawn spec-extractor subagents.
- NEVER implement code without first reading the relevant specs from disk.
- ONE task per iteration in the build stage.
- ALWAYS update PORT_STATE.md before exiting.

### Step 1: Orient

Read `/porting/PORT_STATE.md`. Parse the YAML frontmatter to extract:

- `source_lang`, `target_lang` — the language pair
- `source_root`, `target_root` — directory paths
- `test_command` — fitness function
- `current_stage` — determines what you do this iteration
- `stages_completed` — which stages have passed their quality gates
- `build_iterations`, `build_failures` — build stage counters

If PORT_STATE.md does not exist, output an error message telling the user to run `/repo-clone init <source> <target>` first, then exit.

### Step 2: Execute Stage

Based on `current_stage`, execute exactly one of the following stage protocols.

#### Stage 0 -- Freeze

Create the baseline snapshot. This is small enough to do directly (no subagents).

1. Run `git log --oneline -1` to capture the current commit hash.
2. Run the `test_command` and capture the output (pass/fail, number of tests).
3. Write `/porting/BASELINE.md`:

   ```
   # Baseline
   - Commit: {hash}
   - Date: {today}
   - Source: {source_lang}
   - Test command: {test_command}
   - Test result: {pass/fail, count}
   ```

4. Write `/porting/OUT_OF_SCOPE.md` with sensible defaults:

   ```
   # Out of Scope
   These files/patterns are excluded from porting:
   - Build configs (Cargo.toml, package.json, go.mod, etc.)
   - CI/CD pipelines (.github/, .gitlab-ci.yml, etc.)
   - IDE configs (.vscode/, .idea/, etc.)
   - Lock files (Cargo.lock, package-lock.json, etc.)
   - Documentation (README.md, docs/, etc.)
   - Static assets (images, fonts, etc.)
   ```

5. Write `/porting/SEMANTIC_MISMATCHES.md` by examining the language pair and listing the relevant patterns from Section 3 above, plus any project-specific patterns you can detect (e.g., heavy macro usage, async patterns, error handling strategy).
6. Create `/porting/golden-tests/` directory if it does not exist.
7. **Quality gate:** All three files (BASELINE.md, OUT_OF_SCOPE.md, SEMANTIC_MISMATCHES.md) exist. If yes, set `current_stage: 1`, add `0` to `stages_completed`, update the status table row for stage 0 to `done`. Commit all files.

#### Stage 1 -- Extract Test Specs

Spawn subagents to extract behavioral specs from every test file.

1. Use Glob to find all test files under `source_root`. Use language-appropriate patterns:
   - Rust: `**/*test*.rs`, `**/tests/**/*.rs`
   - TypeScript: `**/*.test.ts`, `**/*.spec.ts`, `**/__tests__/**`
   - Python: `**/test_*.py`, `**/*_test.py`
   - Go: `**/*_test.go`
2. Group test files into batches of 3-5 files each.
3. For each batch, spawn a spec-extractor subagent with `run_in_background: true`:
   - Pass: mode=test, file paths, citation format reference
   - The agent reads the files, extracts behavioral specs, returns structured markdown
4. Collect all results. For each test file, write the spec to `/porting/specs/from-tests/{module_name}.spec.md`.
5. **Quality gate:** Every test file found in step 1 has a corresponding spec in specs/from-tests/. If yes, set `current_stage: 2`, add `1` to `stages_completed`, update status table. Commit all spec files.

If some files were missed, do NOT advance. The next iteration will pick up remaining files.

#### Stage 2 -- Extract Source Specs

Spawn subagents to extract behavioral specs from every source file (excluding tests).

1. Use Glob to find all source files under `source_root`, excluding test files and files listed in OUT_OF_SCOPE.md.
2. Group into batches of 3-5 files.
3. For each batch, spawn a spec-extractor subagent with `run_in_background: true`:
   - Pass: mode=source, file paths, citation format, paths to any related test specs in specs/from-tests/ for cross-referencing
4. Collect results. Write each to `/porting/specs/from-src/{module_name}.spec.md`.
5. **Quality gate:** Every source module has a spec. If yes, set `current_stage: 3`, add `2` to `stages_completed`, update status table. Commit all spec files.

#### Stage 3 -- Plan

Synthesize all specs into a dependency-ordered task list. This iteration reads a lot, so use subagents if the spec set is large (>10 files), otherwise read directly.

1. Read all specs from `/porting/specs/from-tests/` and `/porting/specs/from-src/`.
2. Read `/porting/OUT_OF_SCOPE.md` and `/porting/SEMANTIC_MISMATCHES.md`.
3. Analyze module dependencies: which modules import/call which others.
4. Create `/porting/PORT_TODO.md` with dependency-ordered tasks. Leaf modules (no dependencies) come first. Each task follows the format in Section 6 below.
5. Ensure every behavior from every spec is covered by at least one task.
6. **Quality gate:** PORT_TODO.md exists and contains at least one task. If yes, set `current_stage: 4`, add `3` to `stages_completed`, update status table. Commit PORT_TODO.md.

#### Stage 4 -- Build (ONE task per iteration)

This is the core ralph loop stage. Each iteration implements exactly one task.

1. Read `/porting/PORT_TODO.md`. Find the first task whose Status is `TODO` and whose dependencies are all `DONE`.
2. If no eligible task exists and all tasks are `DONE`: set `current_stage: 5`, add `4` to `stages_completed`, update status table, commit, exit.
3. If no eligible task exists but some are not `DONE` (dependency deadlock): report the deadlock in PORT_STATE.md, suggest breaking tasks into subtasks, exit.
4. Mark the chosen task `IN_PROGRESS` in PORT_TODO.md.
5. Read the specs referenced by this task (from specs/from-src/ and specs/from-tests/). If the specs are large, spawn subagents to summarize the relevant sections.
6. Read `/porting/SEMANTIC_MISMATCHES.md` for patterns relevant to this task.
7. Implement the code in `target_root` using idiomatic target-language patterns. Write tests if the target framework expects them alongside source.
8. Run `test_command`.
9. **If tests PASS:**
   - Mark task `DONE` in PORT_TODO.md
   - `git add` the target files and PORT_TODO.md
   - `git commit -m "port: Task N - {task_name}"`
   - Increment `build_iterations` in PORT_STATE.md
10. **If tests FAIL:**
    - `git checkout -- {target_root}` to revert implementation changes
    - Do NOT mark the task as DONE
    - Increment both `build_iterations` and `build_failures` in PORT_STATE.md
    - Add a brief failure note to PORT_STATE.md body (what went wrong)
    - If this task has failed 3+ times (check failure notes): mark it `SKIPPED` with a reason, move on
11. Update PORT_STATE.md with current counters. Commit state.

#### Stage 5 -- Audit

Spawn subagents to verify parity between specs and target implementation.

1. Read all specs from `/porting/specs/from-src/` and `/porting/specs/from-tests/`.
2. Use Glob to find all implemented files in `target_root`.
3. Map each spec to its corresponding target module.
4. For each (spec, target) pair, spawn a parity-checker subagent with `run_in_background: true`:
   - Pass: source spec, test spec (if exists), target file path, SEMANTIC_MISMATCHES.md
   - The agent reads the target file, catalogs every behavior from the spec, checks each against the implementation, returns a parity report
5. Collect all reports. Write `/porting/PORT_AUDIT.md` with a summary table and detailed findings.
6. **If gaps found:** Create remediation tasks in PORT_TODO.md, set `current_stage: 4`, exit. The loop will re-enter build stage.
7. **If full parity:** Mark stage 5 `done` in status table, add `5` to `stages_completed`. Commit PORT_AUDIT.md. Output a completion message.

### Step 3: Update State

After executing the stage protocol:

1. Update PORT_STATE.md YAML frontmatter: `current_stage`, `stages_completed`, `build_iterations`, `build_failures`.
2. Update the status table in the PORT_STATE.md body (set current stage row to `done` if the quality gate passed, `in_progress` otherwise).
3. Commit the state file: `git add /porting/PORT_STATE.md && git commit -m "port-state: stage {N} update"`.

### Step 4: Exit

Exit cleanly. Do not loop. Do not attempt the next stage. The outer bash loop will invoke the next iteration, which will read the updated PORT_STATE.md and continue.

---

## 5. Agent Dispatch Reference

### spec-extractor

**When:** Stages 1 and 2 (test and source spec extraction).
**Dispatch:** Spawn with `run_in_background: true` for each batch of 3-5 files.
**Pass to agent:**

- Mode: `test` or `source`
- List of absolute file paths to read
- Citation format: `[source:path:start-end]` or `[test:path:start-end]`
- For source mode: paths to related test specs for cross-referencing
**Expected output:** Structured markdown following the Behavioral Spec Format (Section 2). One spec per file, with behaviors, inputs, outputs, side effects, error cases, and citations.

### parity-checker

**When:** Stage 5 (audit).
**Dispatch:** Spawn with `run_in_background: true` for each (spec, target) pair.
**Pass to agent:**

- Source behavioral spec (from specs/from-src/)
- Test behavioral spec (from specs/from-tests/, if exists)
- Target implementation file path
- SEMANTIC_MISMATCHES.md content (for distinguishing intentional mismatches from gaps)
**Expected output:** Per-behavior parity verdict (MATCH, INTENTIONAL_MISMATCH, GAP, EXTRA) with citations into the target code.

### Parallelism Rules

- **Spec extraction and parity checking:** Spawn all subagents in parallel. Up to 10 concurrent.
- **Build and test:** Single-threaded. Only one `test_command` execution per iteration. Never run builds in parallel.
- **File writes:** Only the primary context (you) writes to disk. Subagents return data; you write files.

---

## 6. PORT_TODO.md Task Format

Each task in PORT_TODO.md follows this exact structure:

```markdown
## Task {N}: {Module/Component Name}

**Status:** TODO | IN_PROGRESS | DONE | SKIPPED
**Priority:** {1-5, where 1 is highest}
**Dependencies:** [Task X, Task Y]
**Failure count:** 0

### What to implement
{Description of what to build in the target language. Reference specific behaviors.}

### Specs to satisfy
- [see-also:specs/from-src/module.spec.md]
- [see-also:specs/from-tests/module.spec.md]

### Acceptance criteria
- [ ] {specific test or behavior that must pass}
- [ ] {another criterion}

### Semantic mismatches
- {relevant mismatch pattern and the chosen resolution for this task}
```

### Ordering Rules

- Tasks are numbered sequentially starting at 1.
- Leaf modules (no dependencies on other ported modules) come first.
- A task cannot start until all tasks listed in its Dependencies are `DONE`.
- Priority breaks ties when multiple tasks are eligible. Lower number = higher priority.
- If a task is `SKIPPED`, dependents should still be attempted (the skipped behavior may not block them).
