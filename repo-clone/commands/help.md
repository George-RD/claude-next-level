---
name: help
description: "Explain the repo-clone workflow, Ralph loop setup, and PROMPT file architecture"
allowed-tools: ["Read"]
---

# repo-clone Workflow Guide

Read and present the following information to the user.

---

## What is repo-clone?

repo-clone automates codebase porting between languages using **Ralph loops** -- autonomous iteration loops where each cycle gets fresh context and all continuity lives on disk. Instead of interactively guiding an AI through a port, you set up prompt files that drive extraction and porting in a stateless loop.

Key ideas:

- **Fresh context every iteration.** Each loop cycle starts a new Claude session with no memory of previous runs. State persists through files: `IMPLEMENTATION_PLAN.md`, specs, and git history.
- **Citations are the key innovation.** Every behavioral claim in a spec cites the original source code (`[source:path/file:line-range]`). During porting, the agent follows citations back to the original to verify behavior -- preventing hallucinated implementations.
- **Two phases, two loops.** Spec extraction and porting run as separate loops with separate PROMPT files.

---

## The PROMPT File Architecture

`/repo-clone init` scaffolds these files into the project root:

### PROMPT_extract.md

Drives the **spec extraction loop**. Each iteration:

1. Reads source code at the configured source root
2. Checks which modules already have specs
3. Extracts behavioral specifications for unprocessed modules
4. Writes specs to `specs/tests/` (from test files) and `specs/src/` (from source modules) with `[source:file:line-range]` citations
5. Updates `IMPLEMENTATION_PLAN.md` with extraction progress
6. Commits and pushes

Run: `while :; do cat PROMPT_extract.md | claude -p --dangerously-skip-permissions ; done`

> **Safety:** `--dangerously-skip-permissions` bypasses all tool approval. Run only in sandboxed environments (Docker, Fly, E2B) or trusted repos.

### PROMPT_port.md

Drives the **porting loop**. Each iteration:

1. Reads all specs and the implementation plan
2. Picks the most important unfinished task from `IMPLEMENTATION_PLAN.md`
3. Follows citations to read original source before implementing
4. Implements idiomatically in the target language (no transliteration)
5. Runs tests; updates the plan with findings
6. Commits and pushes on success

Run: `while :; do cat PROMPT_port.md | claude -p --dangerously-skip-permissions ; done`

### AGENTS.md

The **operational guide** for both loops. Contains:

- Source and target language, root paths, test/build/lint commands
- Porting conventions (idiomatic code, follow citations, check mismatches)
- Operational notes section that accumulates learnings across iterations
- Codebase patterns section for discovered conventions

Both PROMPT files reference `@AGENTS.md` so the agent knows how to build, test, and validate.

### IMPLEMENTATION_PLAN.md

**Shared state between iterations.** Starts empty, then accumulates:

- During extraction: summary of extracted specs, gaps found, untested code paths
- During porting: task backlog, progress tracking, learnings, blockers

This is the primary coordination mechanism between loop iterations.

---

## Supporting Files

### porting/SEMANTIC_MISMATCHES.md

Created during init with known divergences for the language pair (error handling, type systems, concurrency, module systems). Agents consult this before implementing to avoid naive translations.

### specs/tests/

Behavioral specifications extracted from test files. Each spec describes WHAT a module does (not HOW) with citations to the original test code (`[source:path/file:line-range]`).

### specs/src/

Behavioral specifications extracted from source modules. Each spec captures module behavior with citations to the original source. Together with `specs/tests/`, these are the single source of truth for porting -- agents read specs, follow citations, and implement.

### porting/PORT_STATE.md

Tracks overall porting progress across 6 stages (Freeze, Extract Tests, Extract Source, Plan, Build, Audit). Used by `/repo-clone status` to report progress.

---

## Running the Loops

### Option A: Using ralph-wiggum's loop.sh

If the project has ralph-wiggum configured:

```bash
./loop.sh plan     # Run planning/extraction
./loop.sh build    # Run porting
```

### Option B: Bare bash loops

```bash
# Phase 1: Extract specs from source
while :; do cat PROMPT_extract.md | claude -p --dangerously-skip-permissions ; done

# Phase 2: Port using specs
while :; do cat PROMPT_port.md | claude -p --dangerously-skip-permissions ; done
```

Stop anytime with Ctrl+C. The loop picks up where it left off because all state is on disk.

---

## Why Citations Matter

The citation format `[source:path/file.ext:start-end]` is what makes this approach work:

1. **Extraction** reads source code and writes specs with citations
2. **Porting** reads specs, then follows each citation back to the original source
3. The agent sees the actual implementation before writing the port
4. This prevents "spec drift" where the agent invents behavior not in the source

Without citations, the agent would implement from spec descriptions alone -- which degrades with each layer of abstraction. Citations keep it grounded.

---

## Observing and Controlling

- **Check progress:** `/repo-clone status` or read `porting/PORT_STATE.md`
- **Review specs:** Browse `specs/tests/` and `specs/src/`
- **Check the plan:** Read `IMPLEMENTATION_PLAN.md`
- **Resume:** Restart the loop. Fresh context picks up from disk state.
- **Manual override:** Edit `IMPLEMENTATION_PLAN.md` or `PORT_STATE.md` to reprioritize or skip tasks.

---

## Interactive Commands

| Command | Purpose |
|---------|---------|
| `/repo-clone init <source> <target>` | Scaffold porting project with PROMPT files and AGENTS.md |
| `/repo-clone status` | Show progress, next action, quality gate status |
| `/repo-clone:help` | This guide |

Full methodology: `references/methodology.md`
Cross-language patterns: `references/semantic-mappings.md`
