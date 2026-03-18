---
name: ralph
description: >-
  Use for spec-driven development loops, porting code between languages,
  migrating codebases, or autonomous build loops. Trigger phrases: "ralph loop",
  "spec-driven", "build feature", "port", "clone to", "migrate to",
  "translate to", "rewrite in", "convert from X to Y", "autonomous loop",
  "implementation plan", "JTBD".
---

# Ralph Wiggum Toolkit

Recipe-based autonomous development loops with spec-driven methodology.

## Quick Start

### Greenfield (new features)

1. Run `/ralph init` to scaffold the project
2. Write specs: `/ralph spec`
3. Plan: `/ralph plan`
4. Build: `/ralph build`

### Port (codebase migration)

1. Run `/ralph init --recipe port <source-lang> <target-lang>` to scaffold
2. Run headless extraction loops for test and source specs
3. Plan: `/ralph plan`
4. Build: `/ralph build`

## How It Works

- **Recipes** define what gets scaffolded, which prompts exist, and how many phases
- **Loop infrastructure** (loop.sh, stop-hook.sh, setup-loop.sh) is shared across all recipes
- **Manifest** (`ralph/manifest.json`) tracks progress across iterations
- Each iteration gets fresh context; continuity lives in files on disk

## Available Recipes

- **greenfield**: User-written specs → plan → build. For new features.
- **port**: Extract behavioral specs → port to target language. For codebase migration.

Full guide: `/ralph help`
