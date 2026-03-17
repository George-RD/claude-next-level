# Ralph Technique — Reference Guide

Compiled from Geoffrey Huntley's original writing, Clayton Farr's ralph-playbook (canonical reference), Anthropic's official plugins, and key community implementations.

## Origin

**Creator:** Geoffrey Huntley
**Named after:** Ralph Wiggum (The Simpsons) — "deterministically bad in an undeterministic world"
**Canonical playbook:** [ClaytonFarr/ralph-playbook](https://github.com/ClaytonFarr/ralph-playbook)
**Original form:** `while :; do cat PROMPT.md | claude -p --dangerously-skip-permissions ; done`

## Core Philosophy

1. **"The Loop is the Hero"** — Persistence and iteration outperform genius
2. **"Let Ralph Ralph"** — Set constraints, then get out of his way. Ralph should do ALL the work
3. **"Dumb Things Work Surprisingly Well"** — A bash loop and persistent files. That's it.
4. **"Sit on the loop, not in it"** — Human oversight and control, not passive observation
5. **"The Plan is Disposable"** — Plans are cheap; regenerate rather than force failing approaches
6. **"Disk is State, Git is Memory"** — Progress persists in files and git history, not context
7. **"Eventual Consistency"** — Trust iteration. Overnight failures demand judgment, not panic
8. **"Tune Reactively, Not Prescriptively"** — When Ralph fails a specific way, add a sign to help next time

## The Formula: 3 Phases, 2 Prompts, 1 Loop

### Phase 1: Define Requirements (Human + LLM Conversation)

Not a loop. Interactive conversation to produce specs:

1. Discuss project → identify **Jobs to Be Done (JTBD)**
2. Break each JTBD into **Topics of Concern**
3. Write `specs/FILENAME.md` for each topic (one file per topic)
4. Establish **acceptance criteria** (behavioral outcomes, not implementation)

**Topic Scope Test:** "One Sentence Without 'And'" — if you need "and", it's multiple topics.

### Phase 2: Planning (Ralph Loop — PROMPT_plan.md)

Gap analysis between specs and existing code:

1. Subagents study `specs/*` and `src/*` in parallel
2. Opus subagent analyzes findings, identifies gaps
3. Creates/updates `IMPLEMENTATION_PLAN.md` (prioritized bullet list)
4. **NO implementation. NO commits. Plan only.**
5. Usually 1-2 iterations

### Phase 3: Building (Ralph Loop — PROMPT_build.md)

One task per iteration:

1. Read specs and IMPLEMENTATION_PLAN.md
2. Pick the most important remaining task
3. **Search codebase before implementing** (don't assume missing!)
4. Implement → run tests (backpressure) → commit on green
5. Update IMPLEMENTATION_PLAN.md
6. Exit. Fresh context next iteration.

## Official Terminology

| Term | Definition |
|------|-----------|
| **JTBD (Jobs to Be Done)** | High-level user need or outcome |
| **Topic of Concern** | A distinct aspect within a JTBD; becomes one spec file |
| **Activity** | Verb in a user journey ("upload photo", "extract colors") |
| **Spec** | Requirements doc for one topic (`specs/FILENAME.md`) |
| **Task** | Unit of work derived from comparing specs to code |
| **Acceptance Criteria** | Behavioral outcomes (observable, verifiable, WHAT not HOW) |
| **Backpressure** | Tests/builds/lints that reject invalid work and force iteration |
| **The Stack** | Consistent context allocation: specs + plan + AGENTS.md each iteration |
| **SLC Release** | Simple + Lovable + Complete (narrow but fully accomplishes a job) |
| **Implementation Plan** | Prioritized bullet-point task list; the shared state file |
| **Completion Promise** | `<promise>TEXT</promise>` — honest signal that work is done |

## The Loop Mechanism (Fresh Context)

```bash
while :; do
  cat PROMPT_build.md | claude -p --dangerously-skip-permissions --model opus
done
```

Each iteration:

1. Fresh bash loop starts (zero context from previous runs)
2. PROMPT piped to Claude → Claude reads IMPLEMENTATION_PLAN.md from disk
3. Claude picks one task, implements it, runs tests
4. Commits on green, updates plan, exits
5. Context garbage collected
6. Loop restarts → fresh Claude reads updated plan → picks next task

**Key insight:** `IMPLEMENTATION_PLAN.md` persists on disk and acts as shared state between isolated executions. No sophisticated orchestration needed.

## Prompt Templates

Loop prompts are **condensed** (20-40 lines). NOT methodology documentation.

### PROMPT_plan.md

```
0a. Study `specs/*` with up to 250 parallel Sonnet subagents
    to learn the application specifications.
0b. Study @IMPLEMENTATION_PLAN.md (if present) to understand
    the plan so far.
0c. Study `src/lib/*` with up to 250 parallel Sonnet subagents
    to understand shared utilities & components.
0d. For reference, the application source code is in `src/*`.

1. Study @IMPLEMENTATION_PLAN.md (if present; it may be incorrect)
   and use up to 500 Sonnet subagents to study existing source code
   in `src/*` and compare it against `specs/*`. Use an Opus subagent
   to analyze findings, prioritize tasks, and create/update
   @IMPLEMENTATION_PLAN.md as a bullet point list sorted in priority
   of items yet to be implemented. Ultrathink. Consider searching for
   TODO, minimal implementations, placeholders, skipped/flaky tests,
   and inconsistent patterns.

IMPORTANT: Plan only. Do NOT implement anything. Do NOT assume
functionality is missing; confirm with code search first.
```

### PROMPT_build.md

```
0a. Study `specs/*` with up to 500 parallel Sonnet subagents
    to learn the application specifications.
0b. Study @IMPLEMENTATION_PLAN.md.
0c. For reference, the application source code is in `src/*`.

1. Your task is to implement functionality per the specifications
   using parallel subagents. Follow @IMPLEMENTATION_PLAN.md and
   choose the most important item to address. Before making changes,
   search the codebase (don't assume not implemented) using Sonnet
   subagents. You may use up to 500 parallel Sonnet subagents for
   searches/reads and only 1 Sonnet subagent for build/tests. Use
   Opus subagents when complex reasoning is needed.
2. After implementing, run the tests for that unit. Ultrathink.
3. When you discover issues, immediately update @IMPLEMENTATION_PLAN.md.
4. When tests pass, update @IMPLEMENTATION_PLAN.md, then
   `git add -A` then `git commit`, then `git push`.

99999.  Capture the why in docs and tests.
999999. Single sources of truth, no migrations/adapters.
9999999. Keep @IMPLEMENTATION_PLAN.md current with learnings.
99999999. Keep @AGENTS.md operational only — no status updates.
```

### Key Language Patterns

- **"study"** (not "read" or "look at")
- **"don't assume not implemented"** (the Achilles' heel)
- **"using parallel subagents"** / **"up to N subagents"**
- **"only 1 subagent for build/tests"** (backpressure)
- **"Ultrathink"** (deep reasoning)
- **"capture the why"**

## Subagent Strategy

Main agent = **scheduler**. Never does expensive work in main context.

| Mode | Sonnet (parallel reads) | Opus (reasoning) | Build/Test |
|------|------------------------|-------------------|-----------|
| Planning | Up to 500 | 1 (analysis) | None |
| Building | Up to 500 | 1 (debugging) | 1 Sonnet only |

**Context math:** ~176K usable from 200K budget. Each subagent gets ~156KB (garbage collected after).

## Backpressure (The Critical Concept)

Huntley: "If you aren't capturing your backpressure then you are failing as a software engineer."

**Two steering directions:**

1. **Upstream (deterministic setup):** Specs loaded every iteration. Existing code shapes generation. Shared utilities guide patterns.
2. **Downstream (backpressure):** Tests reject broken work. Typecheck/lint enforce patterns. Build failures force fixes.

**AGENTS.md specifies the actual commands:**

```markdown
## Validation
- Tests: `npm test`
- Typecheck: `npx tsc --noEmit`
- Lint: `npm run lint`
```

The PROMPT says "run tests" generically. AGENTS.md provides the specifics.

## State Files

| File | Purpose | Created by | Format |
|------|---------|-----------|--------|
| `specs/*.md` | Requirements (source of truth) | Phase 1 | Behavioral outcomes, no code |
| `IMPLEMENTATION_PLAN.md` | Prioritized task list (shared state) | Phase 2 | Bullet-point list |
| `AGENTS.md` | Operational guide (~60 lines) | Init | Build/test commands + learnings |
| `PROMPT_plan.md` | Planning loop prompt | Init | ~20 lines |
| `PROMPT_build.md` | Building loop prompt | Init | ~30 lines |

### AGENTS.md (~60 lines, operational only)

```markdown
## Build & Run
Production: `npm run build`
Development: `npm run dev`

## Validation
- Tests: `npm test`
- Typecheck: `npx tsc --noEmit`
- Lint: `npm run lint`

## Operational Notes
Shared utilities in src/lib/utils.ts — use these.
Database migrations: `npm run migrate` before tests.

## Codebase Patterns
async/await consistently. No mixed callbacks.
All API responses use standardized error structure.
```

**Rules:** Keep brief. NOT a changelog. NOT progress tracking. Only HOW to build/run.

### Spec Format (one per Topic of Concern)

```markdown
# [Topic Name]

## Scope
In scope: [what this handles]
Out of scope: [boundaries]

## Acceptance Criteria
- [Observable behavioral outcome]
- [Verifiable result]
- [Edge case handling]

## Data Contracts
Input: [parameters, types, constraints]
Output: [results, structures, error cases]

## Behaviors
[What happens in execution order]
[State transitions]
```

**Critical:** Behavioral outcomes only (WHAT to verify). No code blocks. No variable names. No framework references.

## Guardrail Numbering Convention

Higher number = lower priority (more 9s = less critical):

```
99999.   Capture the why in docs and tests
999999.  Single sources of truth, no migrations/adapters
9999999. Keep IMPLEMENTATION_PLAN.md current with learnings
99999999. Keep AGENTS.md operational only
```

## Loop Script (loop.sh)

```bash
./loop.sh                    # Build mode, unlimited
./loop.sh 20                 # Build mode, max 20 iterations
./loop.sh plan               # Plan mode, unlimited
./loop.sh plan 5             # Plan mode, max 5 iterations
./loop.sh specs              # Specs audit mode
```

**Claude CLI flags:**

```bash
claude -p \
  --dangerously-skip-permissions \
  --output-format=stream-json \
  --model opus \
  --verbose
```

## Safety

> "It's not if it gets popped, it's when. And what is the blast radius?"

- **Sandbox required** — Docker, Fly Sprites, E2B
- `--dangerously-skip-permissions` bypasses Claude's guards entirely
- Escape hatches: Ctrl+C, `git reset --hard`, regenerate plan
- Each task = one commit = easy to revert

## Three Loop Architectures (Comparison)

| Model | Context | Mechanism | Canonical? |
|-------|---------|-----------|-----------|
| **Bash loop** (`claude -p`) | Fresh per iteration | External bash while loop | YES (Huntley's original, ralph-playbook) |
| **Stop hook** (Anthropic plugins) | Same session, compacts | Hook blocks exit, re-injects prompt | Official but different philosophy |
| **Agent spawn** (in-session) | Fresh per spawn | Orchestrator skill spawns Agent tool | Hybrid — fresh context within interactive session |

## Economics

- Sonnet on bash loop: ~$10.42/hour (Huntley)
- One $50K contract completed for $297 in API costs
- 50-iteration cycle on large codebase: $50-100+ in credits

## Sources

- [ghuntley.com/ralph](https://ghuntley.com/ralph/) — Original technique
- [ghuntley.com/loop](https://ghuntley.com/loop/) — "Everything is a Ralph Loop"
- [ghuntley.com/pressure](https://ghuntley.com/pressure/) — Backpressure philosophy
- [ClaytonFarr/ralph-playbook](https://github.com/ClaytonFarr/ralph-playbook) — Canonical playbook
- [anthropics/claude-code/plugins/ralph-wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) — Official Stop hook plugin
- [anthropics/claude-plugins-official/plugins/ralph-loop](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-loop) — Official minimal variant
- [snarktank/ralph](https://github.com/snarktank/ralph) — PRD-driven implementation (13K stars)
- [mikeyobrien/ralph-orchestrator](https://github.com/mikeyobrien/ralph-orchestrator) — Rust multi-agent orchestration (2.2K stars)
- [snwfdhmp/awesome-ralph](https://github.com/snwfdhmp/awesome-ralph) — Curated resource list
