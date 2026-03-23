---
name: help
description: "Explain the repo-clone workflow, manifest-driven execution, and PROMPT file architecture"
allowed-tools: ["Read"]
---

# repo-clone Workflow Guide

Read and present the following information to the user.

---

## What is repo-clone?

repo-clone automates codebase porting between languages using **manifest-driven headless loops** -- autonomous iteration loops where each cycle gets fresh context and all continuity lives on disk. Instead of interactively guiding an AI through a port, you set up prompt files and a manifest that drive extraction and porting in a stateless loop.

Key ideas:

- **Fresh context every iteration.** Each loop cycle starts a new Claude session with no memory of previous runs. State persists through files: `porting/manifest.json`, `IMPLEMENTATION_PLAN.md`, specs, and git history.
- **Citations are the key innovation.** Every behavioral claim in a spec cites the original source code (`[source:path/file:line-range]`). During porting, the agent follows citations back to the original to verify behavior -- preventing hallucinated implementations.
- **Manifest tracks every file.** `porting/manifest.json` lists every test and source file with its processing status. Each loop iteration picks the next pending file, processes it, and marks it done.
- **Haiku for throughput.** Empirical testing shows Haiku captures 100% of test-observable behaviors at a fraction of the cost. Use `--model haiku` for extraction loops.

---

## The Manifest (porting/manifest.json)

The manifest is the central coordination mechanism. It tracks:

- **Project metadata**: source/target languages, roots, commands
- **Phase status**: each phase (extract-tests, extract-src, plan, build, audit) has an overall status
- **Per-file tracking**: within extract phases, every file has its own status (pending/done)

Each loop iteration reads the manifest, finds the next pending file, processes it, and updates the manifest. This enables stateless loops -- no memory between iterations, all state on disk.

---

## The PROMPT File Architecture

`/repo-clone init` scaffolds these files into the project root:

### PROMPT_extract_tests.md

Drives the **test spec extraction loop**. Each iteration:

1. Reads the manifest to find the next pending test file
2. Extracts behavioral specifications from the test file
3. Writes specs to `specs/tests/{basename}_spec.md` with `[test:file:line-range]` citations
4. Marks the file as done in the manifest
5. Commits and pushes

Run: `while :; do cat PROMPT_extract_tests.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done`

### PROMPT_extract_src.md

Drives the **source spec extraction loop**. Each iteration:

1. Reads the manifest to find the next pending source file
2. Extracts behavioral specifications from the source file
3. Writes specs to `specs/src/{basename}_spec.md` with `[source:file:line-range]` citations
4. Cross-references test specifications where behaviors overlap
5. Marks the file as done in the manifest
6. Commits and pushes

Run: `while :; do cat PROMPT_extract_src.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done`

### PROMPT_port.md

Drives the **porting loop**. Each iteration:

1. Reads all specs and the implementation plan
2. Picks the most important unfinished task from `IMPLEMENTATION_PLAN.md`
3. Follows citations to read original source before implementing
4. Implements idiomatically in the target language (no transliteration)
5. Runs tests; updates the plan with findings
6. Commits and pushes on success

Run: `while :; do cat PROMPT_port.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done`

> **Safety:** `--dangerously-skip-permissions` bypasses all tool approval. Run only in sandboxed environments (Docker, Fly, E2B) or trusted repos.

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

### porting/manifest.json

The central tracking file. Contains per-file status for each phase:

```json
{
  "phases": {
    "extract-tests": {
      "status": "in-progress",
      "files": {
        "src/tests/auth_test.rs": {"status": "done"},
        "src/tests/config_test.rs": {"status": "pending"}
      }
    }
  }
}
```

Each loop iteration reads this, finds the next `"pending"` file, processes it, and updates the status to `"done"`.

### porting/SEMANTIC_MISMATCHES.md

Created during init with known divergences for the language pair (error handling, type systems, concurrency, module systems). Agents consult this before implementing to avoid naive translations.

### specs/tests/

Behavioral specifications extracted from test files. Each spec describes WHAT a module does (not HOW) with citations to the original test code (`[test:path/file:line-range]`).

### specs/src/

Behavioral specifications extracted from source modules. Each spec captures module behavior with citations to the original source. Together with `specs/tests/`, these are the single source of truth for porting -- agents read specs, follow citations, and implement.

### porting/PORT_STATE.md

Human-readable view of the manifest state. Regenerated by `/repo-clone status` from `porting/manifest.json`. Used for quick visual progress checks.

---

## Running the Loops

### Headless bash loops (recommended)

```bash
# Phase 1: Extract test specs
while :; do cat PROMPT_extract_tests.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done

# Phase 2: Extract source specs
while :; do cat PROMPT_extract_src.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done

# Phase 3: Port using specs
while :; do cat PROMPT_port.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done
```

Each iteration reads the manifest, finds the next pending file, processes it, and marks it done. The loop naturally terminates when all files are processed (the agent finds no pending work).

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

- **Check progress:** `/repo-clone status` or read `porting/manifest.json`
- **Review specs:** Browse `specs/tests/` and `specs/src/`
- **Check the plan:** Read `IMPLEMENTATION_PLAN.md`
- **Resume:** Restart the loop. Fresh context picks up from disk state.
- **Manual override:** Edit `porting/manifest.json`, `IMPLEMENTATION_PLAN.md`, or `PORT_STATE.md` to reprioritize or skip tasks.

---

## Interactive Commands

| Command | Purpose |
|---------|---------|
| `/repo-clone init <source> <target>` | Scaffold porting project with manifest, PROMPT files, and AGENTS.md |
| `/repo-clone status` | Show progress from manifest, next action, quality gate status |
| `/repo-clone:help` | This guide |

Full methodology: `references/methodology.md`
Cross-language patterns: `references/semantic-mappings.md`
