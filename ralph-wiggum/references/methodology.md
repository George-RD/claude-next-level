# Ralph Wiggum Methodology Reference

Based on Geoffrey Huntley's Ralph technique (https://ghuntley.com/ralph/) and the Ralph Playbook (https://github.com/ghuntley/how-to-ralph-wiggum).

## Core Concept

Ralph is a spec-driven autonomous development methodology. A dumb bash loop feeds the same prompt to Claude repeatedly. Each iteration gets a fresh context window but sees its previous work in files on disk. The shared `IMPLEMENTATION_PLAN.md` acts as state between otherwise isolated iterations.

```bash
while :; do cat PROMPT.md | claude -p; done
```

"Deterministically bad in an undeterministic world" - failures are predictable, enabling systematic improvement through prompt tuning.

## Three Phases, Two Prompts, One Loop

### Phase 1: Define Requirements (interactive)

- Discuss project ideas with the user
- Identify Jobs to Be Done (JTBD)
- Break JTBDs into topics of concern
- Write `specs/FILENAME.md` for each topic

**Topic scope test**: "Can you describe this in one sentence without 'and'?"

### Phase 2: Planning (loop with PROMPT_plan.md)

Gap analysis between specs and existing code:
1. Subagents study `specs/*` and `src/*` in parallel
2. Compare specs against code
3. Create/update `IMPLEMENTATION_PLAN.md` with prioritized tasks
4. **Plan only - do NOT implement**

Usually completes in 1-2 iterations.

### Phase 3: Building (loop with PROMPT_build.md)

Implement one task per iteration:
1. Orient - study specs
2. Read plan - study IMPLEMENTATION_PLAN.md
3. Select - pick most important task
4. Investigate - search codebase ("don't assume not implemented")
5. Implement - parallel subagents for file operations
6. Validate - 1 subagent for build/tests (backpressure)
7. Update IMPLEMENTATION_PLAN.md - mark done, note discoveries
8. Update AGENTS.md - if operational learnings
9. Commit and push

## Context Management

Context is everything. ~176K usable tokens with 40-60% "smart zone" utilization.

- **Main agent = scheduler** - Don't pollute with expensive work
- **Subagents = memory extension** - Each gets ~156KB, garbage collected
- **Sonnet subagents** for reads/searches (up to 500 parallel)
- **Opus subagents** for complex reasoning (debugging, architecture)
- **Only 1 subagent for build/tests** - This is intentional backpressure

## Steering Ralph

### Upstream (deterministic setup)
- First ~5,000 tokens for specs
- Every iteration loads same files: PROMPT.md + AGENTS.md
- Existing code patterns steer what gets generated
- If Ralph generates wrong patterns, add utilities to steer correct ones

### Downstream (backpressure)
- Tests, typechecks, lints, builds reject invalid work
- AGENTS.md specifies actual validation commands
- Prompt says "run tests" generically; AGENTS.md makes it project-specific

## Key Files

| File | Purpose | Size target |
|------|---------|-------------|
| `specs/*.md` | Source of truth for requirements | As needed |
| `AGENTS.md` | Operational guide (loaded every iteration) | ~60 lines |
| `IMPLEMENTATION_PLAN.md` | Shared state between iterations | Varies |
| `PROMPT_plan.md` | Planning mode instructions | ~20 lines |
| `PROMPT_build.md` | Build mode instructions | ~30 lines |

## Prompt Language Patterns

Geoff's specific phrasing that matters:
- "study" (not "read" or "look at")
- "don't assume not implemented" (critical guardrail)
- "using parallel subagents" / "up to N subagents"
- "only 1 subagent for build/tests" (backpressure)
- "Ultrathink" (deep reasoning)
- "capture the why"
- "keep it up to date"
- "resolve them or document them"

## Prompt Structure

| Section | Purpose |
|---------|---------|
| Phase 0 (0a-0d) | Orient: study specs, source, current plan |
| Phase 1-4 | Main instructions: task, validation, commit |
| 999... numbering | Guardrails/invariants (higher number = more critical) |

## The Plan is Disposable

- Wrong plan? Delete it, switch to planning mode, regenerate
- Cost: one planning loop iteration (cheap)
- Regenerate when: Ralph goes in circles, plan is stale, specs changed significantly

## Work Branches (Optional)

For parallel work streams, scope the plan per branch:
1. Full planning on main
2. Create work branch: `git checkout -b ralph/feature-name`
3. Scoped planning: `./loop.sh plan-work "description"`
4. Build from scoped plan: `./loop.sh`
5. PR when done

Scope at plan creation (deterministic), not task selection (probabilistic).

## Expectations

- **Best for greenfield.** The original author explicitly warns against using Ralph on existing codebases — legacy patterns and implicit conventions are hard to steer. Ralph shines when building from scratch with clear specs.
- **~90% completion.** Expect Ralph to get you most of the way, not to production-ready. The last 10% needs human review, polish, and judgement.

## Safety

Ralph requires `--dangerously-skip-permissions` for autonomous operation. Run in a sandbox:
- Docker containers (local)
- Fly Sprites, E2B (remote)
- Minimum viable access: only needed API keys, no private data beyond requirements
- Escape hatches: Ctrl+C stops loop, `git reset --hard` reverts uncommitted changes
