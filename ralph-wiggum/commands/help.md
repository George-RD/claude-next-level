---
description: "Explain Ralph Wiggum methodology and available commands"
---

# Ralph Wiggum Plugin Help

Explain the following to the user:

## What is Ralph Wiggum?

Ralph Wiggum implements Geoffrey Huntley's spec-driven autonomous development methodology. It's a structured approach to building software through iterative AI loops, where each iteration gets a fresh context window but sees its previous work through files on disk.

The core insight: a dumb bash loop that keeps restarting Claude, combined with a shared plan file on disk, creates a surprisingly effective autonomous development system.

```bash
while :; do cat PROMPT.md | claude -p; done
```

## Three Phases

### Phase 1: Define Requirements (`/ralph-wiggum:spec`)

Interactive conversation to identify Jobs to Be Done (JTBD) and write specs:
- Discuss project ideas with the user
- Break JTBDs into topics of concern (use "one sentence without and" test)
- Write `specs/FILENAME.md` for each topic
- Include acceptance criteria (what success looks like, not how to build it)

### Phase 2: Plan (`/ralph-wiggum:plan`)

Run the planning loop - gap analysis between specs and existing code:
- Subagents study `specs/*` and `src/*` in parallel
- Compare specs against code to find what's missing
- Create/update `IMPLEMENTATION_PLAN.md` with prioritized tasks
- **Plan only - no implementation**
- Usually completes in 1-2 iterations

### Phase 3: Build (`/ralph-wiggum:build`)

Run the build loop - implement one task per iteration:
1. Orient (study specs)
2. Read plan (pick most important task)
3. Investigate (search codebase - "don't assume not implemented")
4. Implement (parallel subagents)
5. Validate (run tests - 1 subagent only, for backpressure)
6. Update plan and AGENTS.md
7. Commit and push

## Available Commands

| Command | Description |
|---------|-------------|
| `/ralph-wiggum:init` | Set up project structure (specs/, AGENTS.md, prompts, loop.sh) |
| `/ralph-wiggum:spec` | Phase 1: Define JTBD requirements and write specs |
| `/ralph-wiggum:plan` | Phase 2: Planning loop (gap analysis → implementation plan) |
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
| `IMPLEMENTATION_PLAN.md` | Prioritized task list (generated/updated by Ralph) |
| `PROMPT_plan.md` | Planning mode instructions |
| `PROMPT_build.md` | Build mode instructions |
| `loop.sh` | External autonomous loop runner |

## Key Principles

1. **Context is everything** - Use the main agent as scheduler, subagents as memory extension
2. **Steer with backpressure** - Tests, types, lints create gates that reject bad work
3. **Let Ralph Ralph** - Trust the self-correction loop, don't over-prescribe
4. **Move outside the loop** - Observe, tune prompts, add signs - don't sit in the loop
5. **The plan is disposable** - Wrong plan? Regenerate it. One planning loop is cheap.

## Expectations

- **Best for greenfield projects.** Ralph works best when building from scratch with clear specs. Existing codebases with legacy patterns and implicit conventions are much harder to steer.
- **Expect ~90% completion.** Ralph gets you most of the way there, not to production-ready. Plan for human review and polish on the final stretch.

## Learn More

- Original technique: https://ghuntley.com/ralph/
- Playbook reference: https://github.com/ghuntley/how-to-ralph-wiggum
