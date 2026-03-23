---
description: "Explain Ralph Wiggum methodology and available commands"
---

# Ralph Wiggum Plugin Help

Explain the following to the user:

## What is Ralph Wiggum?

Ralph Wiggum implements Geoffrey Huntley's spec-driven autonomous development methodology. A bash loop feeds the same prompt to Claude repeatedly -- each iteration gets a fresh context window but sees its previous work through files on disk.

```bash
while :; do cat PROMPT.md | claude -p; done
```

## Three Phases

| Phase | Command | What happens |
|-------|---------|-------------|
| 1. Define | `/ralph-wiggum:spec` | Interactive JTBD analysis, write `specs/*.md` |
| 2. Plan | `/ralph-wiggum:plan` | Gap analysis between specs and code, create `IMPLEMENTATION_PLAN.md` |
| 3. Build | `/ralph-wiggum:build` | Implement one task per iteration: investigate, build, test, commit |

## All Commands

| Command | Description |
|---------|-------------|
| `/ralph-wiggum:init` | Set up project structure (specs/, AGENTS.md, prompts, loop.sh) |
| `/ralph-wiggum:spec` | Phase 1: Define JTBD requirements and write specs |
| `/ralph-wiggum:plan` | Phase 2: Planning loop (gap analysis, create implementation plan) |
| `/ralph-wiggum:build` | Phase 3: Build loop (implement, test, commit) |
| `/ralph-wiggum:status` | Show current Ralph project state |
| `/ralph-wiggum:cancel` | Cancel an active loop |
| `/ralph-wiggum:help` | This help message |

## In-Session vs External Loop

**In-session** (commands above): Runs within your current Claude Code session using stop hooks. Good for interactive development where you want to observe and steer.

**External** (`loop.sh`): Runs `claude -p` in a bash while-true loop. Fully autonomous, fire-and-forget. Requires `--dangerously-skip-permissions` and should run in a sandbox.

```bash
./loop.sh              # Build mode, unlimited
./loop.sh 20           # Build mode, max 20 iterations
./loop.sh plan         # Plan mode
./loop.sh plan 5       # Plan mode, max 5 iterations
```

## Key Files

| File | Purpose |
|------|---------|
| `specs/*.md` | Source of truth for requirements (one per topic) |
| `AGENTS.md` | Operational guide: build/test/lint commands (~60 lines) |
| `IMPLEMENTATION_PLAN.md` | Prioritized task list (shared state between iterations) |
| `PROMPT_plan.md` | Planning mode instructions |
| `PROMPT_build.md` | Build mode instructions |
| `loop.sh` | External autonomous loop runner |

## Expectations

- **Best for greenfield projects.** Existing codebases with legacy patterns are harder to steer.
- **Expect ~90% completion.** Plan for human review and polish on the final stretch.

## Learn More

For detailed methodology, steering techniques, and prompt patterns, see the methodology reference (loaded automatically during loops).

- Original technique: https://ghuntley.com/ralph/
- Playbook reference: https://github.com/ghuntley/how-to-ralph-wiggum
