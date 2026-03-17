---
name: repo-clone
description: >-
  Use when porting code between languages, migrating a codebase, translating
  source code, or rewriting in a new language. Trigger phrases: "port",
  "clone to", "migrate to", "translate to", "rewrite in", "convert from X to Y".
---

# Codebase Porting

Port codebases between languages using Ralph loops with citation-backed behavioral specs.

## Quick Start

1. Run `/repo-clone init <source-lang> <target-lang>` to scaffold the porting project
2. Review and customize the generated specs, PROMPT files, and AGENTS.md
3. Run the Ralph loops:
   - `./loop.sh plan` — gap analysis between specs and code
   - `./loop.sh build` — implement one task per iteration

## How It Works

- **Phase 1**: Extract behavioral specs from source tests and code (with citations)
- **Phase 2**: Plan porting backlog from specs (IMPLEMENTATION_PLAN.md)
- **Phase 3**: Port one task per loop iteration, following citations to original source

Full methodology: `references/methodology.md`
Prompt templates: `references/templates/PROMPT_extract.md`, `PROMPT_port.md`
Cross-language patterns: `references/semantic-mappings.md`
