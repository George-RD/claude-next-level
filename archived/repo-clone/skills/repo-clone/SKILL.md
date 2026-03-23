---
name: repo-clone
description: >-
  Use when porting code between languages, migrating a codebase, translating
  source code, or rewriting in a new language. Trigger phrases: "port",
  "clone to", "migrate to", "translate to", "rewrite in", "convert from X to Y".
---

# Codebase Porting

Port codebases between languages using manifest-driven headless loops with citation-backed behavioral specs.

## Quick Start

1. Run `/repo-clone init <source-lang> <target-lang>` to scaffold the porting project
2. Review the generated `porting/manifest.json` — it tracks every file through each phase
3. Run the headless extraction and porting loops:
   - `while :; do cat PROMPT_extract_tests.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done`
   - `while :; do cat PROMPT_extract_src.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done`
   - `while :; do cat PROMPT_port.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done`

## How It Works

- **Init**: Scans source repo, categorizes files (test/source/config/asset/doc), builds `porting/manifest.json` with per-file tracking
- **Phase 1 (extract-tests)**: Loop extracts behavioral specs from test files with `[test:file:line-range]` citations
- **Phase 2 (extract-src)**: Loop extracts behavioral specs from source files with `[source:file:line-range]` citations, cross-referencing test specs
- **Phase 3 (plan)**: Synthesize IMPLEMENTATION_PLAN.md from all specs
- **Phase 4 (build)**: Loop ports one task per iteration, following citations to original source
- **Phase 5 (audit)**: Parity check between source and ported code

Each loop iteration reads the manifest, finds the next pending file, processes it, and marks it done. All state lives on disk -- no memory between iterations.

Full methodology: `references/methodology.md`
Prompt templates: `data/templates/PROMPT_extract_tests.md`, `PROMPT_extract_src.md`, `PROMPT_port.md`
Cross-language patterns: `references/semantic-mappings.md`
