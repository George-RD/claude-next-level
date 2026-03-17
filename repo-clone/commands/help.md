---
name: help
description: "Explain the repo-clone workflow, ralph loop setup, and all stages"
allowed-tools: ["Read"]
---

# repo-clone Workflow Guide

Read and present the following information to the user.

---

## What is repo-clone?

repo-clone automates codebase porting between languages using a **ralph loop** architecture inspired by Geoffrey Huntley's Loom project. Instead of interactively guiding an AI through a port, you set up a loop that iterates autonomously through 6 stages until the port is complete.

Key principles:

- **Primary context = scheduler.** The main agent never does leaf-level work. It reads state, decides what to do, and spawns subagents for all file reading, analysis, and implementation.
- **Fresh context each iteration.** Every loop iteration starts with zero memory of previous iterations. All state persists on disk via `PORT_STATE.md` and other files in `porting/`.
- **Fitness = tests pass.** Each iteration either passes the test command and commits, or fails and reverts. No half-done work accumulates.

---

## The 6 Stages

### Stage 0: Freeze

**What it does:** Creates the baseline documentation for the port.

- Writes `BASELINE.md` (snapshot of what the source codebase does)
- Writes `OUT_OF_SCOPE.md` (what will NOT be ported and why)
- Writes `SEMANTIC_MISMATCHES.md` (language differences that affect the port: error handling, types, concurrency, module systems)
- This is the only stage where the primary context may do work directly (these are small files, no subagents needed)

**Gate to advance:** All three files exist in `porting/`.

### Stage 1: Extract Test Specs

**What it does:** Extracts behavioral specifications from every test file in the source project.

- Spawns `spec-extractor` subagents in parallel (up to 10 concurrent), one per batch of test files
- Each agent reads test files and produces structured specs describing WHAT is tested, not HOW
- Primary context collects specs, validates completeness, writes them to `porting/specs/from-tests/`
- One `.spec.md` file per test file, with citations in `[test:path/file.ext:start-end]` format

**Gate to advance:** Every test file has a corresponding spec in `porting/specs/from-tests/`.

### Stage 2: Extract Source Specs

**What it does:** Extracts behavioral specifications from every source module.

- Same pattern as Stage 1 but for source files
- Spawns `spec-extractor` subagents in parallel per source file batch
- Produces specs describing what each module DOES (behavior, contracts, invariants)
- Writes to `porting/specs/from-src/`
- Citations use `[source:path/file.ext:start-end]` format

**Gate to advance:** Every source module has a corresponding spec in `porting/specs/from-src/`.

### Stage 3: Plan

**What it does:** Synthesizes all specs into a dependency-ordered task list.

- Reads all specs from both `porting/specs/from-tests/` and `porting/specs/from-src/`
- Creates `PORT_TODO.md` with tasks ordered by dependency (foundations first, dependent modules later)
- Each task references the specs it implements
- Cross-references with `SEMANTIC_MISMATCHES.md` for language-specific considerations

**Gate to advance:** `PORT_TODO.md` exists with dependency-ordered tasks.

### Stage 4: Build

**What it does:** Implements the port, one task per iteration.

- Each iteration picks ONE task from `PORT_TODO.md` (the next undone task whose dependencies are met)
- Reads the relevant specs for that task
- Implements the code in the target language
- Runs the test command
- On pass: commits and marks task DONE in `PORT_TODO.md`
- On fail: reverts all changes (ralph loop handles this)
- This is the longest stage — it runs for as many iterations as there are tasks

**Gate to advance:** All tasks in `PORT_TODO.md` marked DONE and test command passes.

### Stage 5: Audit

**What it does:** Final parity check between source and target.

- Spawns `parity-checker` subagents in parallel, one per module
- Each agent compares the source spec against the actual target implementation
- Distinguishes intentional mismatches (documented in `SEMANTIC_MISMATCHES.md`) from gaps
- Produces `PORT_AUDIT.md` with a full parity report

**Gate to complete:** `PORT_AUDIT.md` shows no critical gaps.

---

## How to Run the Ralph Loop

### Setup

1. Initialize the project interactively:

   ```text
   /repo-clone init rust typescript
   ```

   This creates `porting/PORT_STATE.md` and the directory structure.

2. Create your loop prompt file `PROMPT_port.md` in the repo root. The SKILL.md provides the template — it instructs the agent to read `PORT_STATE.md`, determine the current stage, and execute the appropriate protocol.

3. Start the loop:

   ```bash
   while :; do cat PROMPT_port.md | claude -p ; done
   ```

   Or use `loop.sh` if your project has one configured for porting.

### How It Works

Each iteration of the loop:

1. Starts a **fresh Claude context** (no memory of previous iterations)
2. Reads `PROMPT_port.md` as the prompt
3. The SKILL.md is loaded (plugin skill), giving the agent the full methodology
4. Agent reads `porting/PORT_STATE.md` to determine current stage
5. Agent acts as **scheduler**: spawns subagents for actual work
6. Agent updates state, commits on success
7. Process exits, loop restarts with fresh context

**Important:** Each iteration gets FRESH CONTEXT. The agent has no memory of what happened in previous iterations. All continuity comes from files on disk — `PORT_STATE.md`, spec files, `PORT_TODO.md`, etc. This is by design: it prevents context window pollution and ensures each iteration operates from clean, validated state.

---

## Observing and Controlling the Loop

You can stop the loop at any time (Ctrl+C) and inspect the state:

- **Check progress:** `/repo-clone status` or read `porting/PORT_STATE.md` directly
- **Review specs:** Browse `porting/specs/from-tests/` and `porting/specs/from-src/`
- **Check the plan:** Read `porting/PORT_TODO.md`
- **Review the audit:** Read `porting/PORT_AUDIT.md`
- **Resume:** Just restart the loop. The agent will pick up from wherever it left off.

You can also manually edit `PORT_STATE.md` to:

- Skip a stage (set `current_stage` to a higher number)
- Replay a stage (set it back and remove it from `stages_completed`)
- Adjust configuration (change `test_command`, roots, etc.)

---

## Citation Format

All specs and reports use consistent citation format:

- `[source:path/file.ext:start-end]` — reference to source code
- `[test:path/file.ext:start-end]` — reference to test file
- `[see-also:specs/from-tests/module.spec.md]` — cross-reference to another spec

---

## The Scheduler/Subagent Pattern

The primary context (the agent running in the ralph loop) is a **scheduler**, not a worker:

- It **never** reads source or test files directly. It spawns `spec-extractor` subagents for that.
- It **never** checks parity directly. It spawns `parity-checker` subagents for that.
- It **decides** what to work on, when to advance stages, and what to commit.
- It **dispatches** parallel subagents (up to 10) for read/analysis work.
- It **serializes** build/test work (exactly 1 subagent at a time for backpressure).

This keeps the primary context window clean and focused on coordination.

---

## Interactive Commands

| Command | Purpose |
|---------|---------|
| `/repo-clone init <source> <target>` | Initialize a new porting project |
| `/repo-clone status` | Show progress, next action, quality gate status |
| `/repo-clone:help` | This help page |

These commands are for **interactive** use — setup, inspection, and manual control. The ralph loop uses the SKILL.md directly and does not invoke these commands.

---

## Output Directory Structure

```text
porting/
  PORT_STATE.md              # Single source of truth for loop state
  BASELINE.md                # What the source codebase does (Stage 0)
  OUT_OF_SCOPE.md            # What will not be ported (Stage 0)
  SEMANTIC_MISMATCHES.md     # Language differences affecting the port (Stage 0)
  specs/
    from-tests/              # One .spec.md per test file (Stage 1)
    from-src/                # One .spec.md per source module (Stage 2)
  PORT_TODO.md               # Dependency-ordered task list (Stage 3)
  PORT_AUDIT.md              # Final parity report (Stage 5)
  golden-tests/              # Reference test outputs
```
