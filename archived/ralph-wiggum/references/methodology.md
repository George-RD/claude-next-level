# Ralph Wiggum Methodology Reference

Based on Geoffrey Huntley's Ralph technique (https://ghuntley.com/ralph/) and the Ralph Playbook (https://github.com/ghuntley/how-to-ralph-wiggum).

## Core Concept

A bash loop feeds the same prompt to Claude repeatedly. Each iteration gets a fresh context window but sees its previous work in files on disk. `IMPLEMENTATION_PLAN.md` acts as shared state between isolated iterations.

```bash
while :; do cat PROMPT.md | claude -p; done
```

Failures are predictable ("deterministically bad"), enabling systematic improvement through prompt tuning.

## Three Phases

### Phase 1: Define Requirements (interactive)

- Identify Jobs to Be Done (JTBD), break into topics of concern
- Write `specs/FILENAME.md` for each topic
- **Scope test**: "Can you describe this in one sentence without 'and'?"

### Phase 2: Planning (loop with PROMPT_plan.md)

- Subagents study `specs/*` and `src/*` in parallel, compare against code
- Create/update `IMPLEMENTATION_PLAN.md` with prioritized tasks
- **Plan only -- do NOT implement.** Usually completes in 1-2 iterations.

### Phase 3: Building (loop with PROMPT_build.md)

One task per iteration: orient, read plan, select task, investigate ("don't assume not implemented"), implement, validate (1 subagent for backpressure), update plan, commit.

## Context Management

- **Main agent = scheduler** -- don't pollute with expensive work
- **Subagents = memory extension** -- Sonnet for reads/searches (up to 500 parallel), Opus for complex reasoning
- **Only 1 subagent for build/tests** -- intentional backpressure

## Steering Ralph

**Upstream (deterministic)**: Specs, PROMPT.md, AGENTS.md, and existing code patterns steer generation. If Ralph generates wrong patterns, add utilities to steer correct ones.

**Downstream (backpressure)**: Tests, typechecks, lints, builds reject invalid work. AGENTS.md specifies the actual validation commands.

## Key Files

| File | Purpose | Size target |
|------|---------|-------------|
| `specs/*.md` | Source of truth for requirements | As needed |
| `AGENTS.md` | Operational guide (loaded every iteration) | ~60 lines |
| `IMPLEMENTATION_PLAN.md` | Shared state between iterations | Varies |
| `PROMPT_plan.md` | Planning mode instructions | ~20 lines |
| `PROMPT_build.md` | Build mode instructions | ~30 lines |

## Prompt Conventions

Key phrasing from the original methodology:
- "study" (not "read"), "don't assume not implemented", "Ultrathink"
- "using parallel subagents" / "up to N subagents" / "only 1 subagent for build/tests"
- "capture the why", "resolve them or document them"

Prompt structure: Phase 0 (0a-0d) orients; Phases 1-4 are main instructions; 999... numbering marks guardrails (higher = more critical).

## The Plan is Disposable

Wrong plan? Delete it and regenerate. Cost: one planning loop iteration.
Regenerate when Ralph goes in circles, the plan is stale, or specs changed significantly.

## Work Branches (Optional)

Scope the plan per branch for parallel work streams:
1. Full planning on main
2. `git checkout -b ralph/feature-name`
3. `./loop.sh plan-work "description"` (scoped planning)
4. `./loop.sh` (build from scoped plan)
5. PR when done

Scope at plan creation (deterministic), not task selection (probabilistic).

## Safety

Ralph requires `--dangerously-skip-permissions` for autonomous operation. Run in a sandbox (Docker, Fly Sprites, E2B). Escape hatches: Ctrl+C stops the loop, `git reset --hard` reverts uncommitted changes.
