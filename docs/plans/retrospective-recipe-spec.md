# Retrospective Recipe — Specification

**Status:** Draft
**Date:** 2026-03-19
**Plugin:** ralph-wiggum-toolkit v1.1.0
**Depends on:** [Cross-Reference Standard](retrospective-audit-crossref-spec.md)

---

## Overview

The **retrospective** recipe is a post-mortem audit workflow for completed (or in-progress) Ralph projects. It produces a chain of six gap analysis documents that trace behavioral gaps from code through planning through plugin workflow, correlate them with session history, and generate an actionable improvement TODO.

It uses the same agent-swarm pattern as the port recipe: Sonnet workers for atomic parallel comparisons, Opus for cross-cutting synthesis. Each phase is a single-pass headless run (not a loop), keeping individual phases simple while the chain provides depth.

### The Document Chain

```
Phase 1: codegap.md              — What's missing between spec and code?
    ↓
Phase 2: implementation_gap.md   — Was it planned? Planned wrong? Never planned?
    ↓
Phase 3: plugin_gap.md           — Should the plugin workflow have caught it?
    ↓
Phase 4: expected-vs-reality_gap.md  — Thematic synthesis (Opus)
    ↓
Phase 5: E-V-R_explanations.md   — WHY did it happen? (session history mining)
    ↓
Phase 6: improvement_todo.md     — What to fix (Track A: project, Track B: plugin)
```

### Design Principles

1. **Each phase answers one question.** Collapsing phases loses the causal chain.
2. **Behavioral comparison, not line-by-line diffs.** "Does the implementation deliver the behavior the spec promised?" — not "Does function X exist?"
3. **Session history comes after synthesis (Phase 5 after Phase 4).** You need themes first so you know what to look for in conversation logs. Scanning raw history without a hypothesis produces anecdotes, not explanations.
4. **Stable IDs, not heading slugs.** Cross-references use immutable IDs (`CG-001`, `IG-003`) that survive heading edits. See [cross-ref standard](retrospective-audit-crossref-spec.md).
5. **Non-destructive.** Reads the project, writes to `retro/`, commits nothing by default.
6. **Works for port and greenfield recipes.** Auto-detects source recipe from manifest.

---

## Recipe Definition

### `recipes/retrospective/recipe.json`

```json
{
  "name": "retrospective",
  "description": "Post-mortem audit of a completed Ralph project. Chains: codegap → implementation gap → plugin gap → synthesis → session explanations → improvement TODO.",
  "version": "1.0.0",
  "phases": ["codegap", "implgap", "plugingap", "synthesis", "explanations", "todo"],
  "loop_phases": [],
  "headless_phases": ["codegap", "implgap", "plugingap", "synthesis", "explanations", "todo"],
  "init_args": [
    {
      "name": "project-dir",
      "flag": "--project-dir",
      "description": "Path to the Ralph project being retrospected. Defaults to cwd.",
      "required": false,
      "default": "."
    },
    {
      "name": "source-recipe",
      "flag": "--source-recipe",
      "description": "Recipe the project used: port or greenfield. Auto-detected from ralph/manifest.json if omitted.",
      "required": false
    }
  ],
  "default_model": "sonnet",
  "phase_models": {
    "codegap": "sonnet",
    "implgap": "sonnet",
    "plugingap": "sonnet",
    "synthesis": "opus",
    "explanations": "sonnet",
    "todo": "opus"
  },
  "prompt_map": {
    "codegap":      "PROMPT_codegap.md",
    "implgap":      "PROMPT_implgap.md",
    "plugingap":    "PROMPT_plugingap.md",
    "synthesis":    "PROMPT_synthesis.md",
    "explanations": "PROMPT_explanations.md",
    "todo":         "PROMPT_todo.md"
  },
  "manifest_template": null
}
```

**Key decisions:**

- `loop_phases: []` — all phases are single-pass, no stop-hook loop needed
- `phase_models` — new field (extension to recipe.json schema): per-phase model override. Phases 1-3, 5 use Sonnet for atomic comparison. Phases 4, 6 use Opus for synthesis.
- No `manifest_template` — retro uses `retro/retro_state.md` instead of a JSON manifest

---

## File Structure

```
recipes/retrospective/
├── recipe.json
├── templates/
│   ├── PROMPT_codegap.md
│   ├── PROMPT_implgap.md
│   ├── PROMPT_plugingap.md
│   ├── PROMPT_synthesis.md
│   ├── PROMPT_explanations.md
│   ├── PROMPT_todo.md
│   ├── AGENTS.md                    # Retro operational context
│   └── retro_state_template.md      # State file template
├── agents/
│   ├── gap-worker.md                # Sonnet: per-module behavioral comparison
│   ├── session-historian.md         # Sonnet: per-JSONL session analysis
│   └── retro-synthesizer.md         # Opus: cross-cutting synthesis
└── references/
    ├── methodology.md               # Why six phases, design rationale
    ├── cross-ref-standard.md        # Authoritative [gap:file#ID] specification
    └── session-jsonl-schema.md      # Claude Code JSONL parsing reference
```

### Output (written to target project)

```
{project}/retro/
├── retro_state.md                   # Phase tracking + project metadata
├── CROSS_REF_STANDARD.md            # Copy of cross-ref standard for agents
├── codegap.md                       # Phase 1 output
├── implementation_gap.md            # Phase 2 output
├── plugin_gap.md                    # Phase 3 output
├── expected-vs-reality_gap.md       # Phase 4 output
├── E-V-R_explanations.md            # Phase 5 output
└── improvement_todo.md              # Phase 6 output
```

---

## Cross-Reference Standard (Summary)

Full specification: [retrospective-audit-crossref-spec.md](retrospective-audit-crossref-spec.md)

### Stable IDs

| Document | Prefix | Example |
|----------|--------|---------|
| codegap.md | `CG-` | `CG-001` |
| implementation_gap.md | `IG-` | `IG-001` |
| plugin_gap.md | `PG-` | `PG-001` |
| expected-vs-reality_gap.md | `EVR-` | `EVR-001` |
| E-V-R_explanations.md | `EXP-` | `EXP-001` |
| improvement_todo.md | `TODO-` | `TODO-001` |

### Citation Syntax

```
[gap:filename.md#STABLE-ID]
```

Examples:

- `[gap:codegap.md#CG-001]` — reference a specific code gap
- `[gap:codegap.md#CG-001] -> [gap:implementation_gap.md#IG-002]` — chain trace

Coexists with existing citations: `[source:path:lines]`, `[test:path:lines]`, `[see-also:path]`.

### Validation Rules

1. Every `[gap:...]` ref must resolve to a heading in the target file
2. Every item in doc N (except codegap.md) must have an upstream ref
3. No orphan IDs — every ID in doc N-1 referenced by at least one item in doc N (or marked `no-action-needed`)
4. Chain continuity — TODO items trace back through every intermediate doc to a CG item

### Deletions → Tombstones

Never delete gap items. Mark retracted items with `[RETRACTED]` to prevent dangling refs:

```markdown
### CG-003: ~~Rate limiter edge case~~ [RETRACTED]

**Status:** retracted
**Reason:** False positive — destination handles this correctly
```

---

## Agent Definitions

### gap-worker (Sonnet)

**Role:** Atomic behavioral comparison worker. One instance per module, spawned in parallel.

**Inputs:** Spec file(s), implementation file(s), module name.

**Process:**

1. Read all spec files. Catalog every named behavior.
2. Read all implementation files. For each behavior: PRESENT, PARTIAL, or MISSING.
3. PRESENT = clearly implemented and would work correctly.
4. PARTIAL = exists but incomplete, edge cases missing, or incorrectly scoped.
5. MISSING = no evidence of implementation.

**Output:** Markdown fragment following codegap.md format with `CG-NNN` IDs. Aggregated by the orchestrating phase prompt.

**Quality standards:**

- Check every behavior. Do not skip because it "looks fine."
- "Error handling is incomplete" is useless. "The `parse_config` function does not handle missing config files (CG-007, HIGH)" is actionable.
- Do not flag semantic differences (language idioms) unless they cause functional gaps.

### session-historian (Sonnet)

**Role:** JSONL session analysis worker. One instance per session file, spawned in parallel.

**Inputs:** Session JSONL path, EVR themes to match against.

**Process:**

1. Read the JSONL file. Each line is a JSON object.
2. Filter for `type == "user"` (text content, not tool_results) and `type == "assistant"` (text content blocks).
3. Scan for gap signals:
   - User repeating an ignored instruction
   - User corrections: "no", "wait", "that's not what I meant", "you missed"
   - Agent claiming completion when work is incomplete
   - Agent skipping steps
   - User course-corrections (user text message following an assistant message)
4. Match each signal to the closest EVR theme.

**JSONL Parsing Reference:**

- User text: `msg.type == "user"` AND `typeof msg.message.content === "string"`
- Assistant text: `msg.type == "assistant"`, extract `msg.message.content[].text` where `type == "text"`
- Tool calls: `msg.message.content[].type == "tool_use"` → `.name`, `.input`
- Course corrections: user text messages with non-null `parentUuid` (has a parent assistant message)
- Timestamps: ISO 8601 UTC

**Output:** Markdown fragments following E-V-R_explanations.md format with `EXP-NNN` IDs.

### retro-synthesizer (Opus)

**Role:** Cross-cutting synthesis. Used in Phases 4 (synthesis) and 6 (TODO). Single instance, not parallelized.

**Instructions:**

- Use ultrathink on every synthesis task.
- Find themes, not lists. A theme explains multiple gaps.
- Cross-link exhaustively using `[gap:...]` syntax.
- Be direct about root causes. Don't hedge.
- Prioritize signal over coverage. 4 strong insights beat 12 weak ones.
- Output must be readable standalone without the source documents.

---

## Phase Specifications

### Phase 1: Code Gap Analysis

**Prompt:** `PROMPT_codegap.md`
**Model:** Sonnet
**Output:** `retro/codegap.md`
**Agent swarm:** Up to 50 gap-worker instances (one per module)

**Workflow:**

1. Read `retro/retro_state.md` for project metadata (source recipe, paths)
2. Read `AGENTS.md` for operational context
3. Inventory modules by scanning `specs/` and implementation directories
4. Spawn one gap-worker per module in parallel
5. Aggregate results into `retro/codegap.md` with summary table
6. Assign sequential `CG-NNN` IDs to each gap

**Port project inputs:** `specs/src/*.md`, `specs/tests/*.md` vs `{target_root}/`
**Greenfield project inputs:** `specs/*.md` vs `{src_dir}/`

**Output format:**

```markdown
# Behavioral Gap Analysis

**Project:** {name}
**Date:** {today}
**Source recipe:** port | greenfield
**Spec root:** specs/
**Implementation root:** {path}

## Summary

| Module | Behaviors | Pass | Partial | Missing | Status |
|--------|-----------|------|---------|---------|--------|

**Overall: {n} of {total} behaviors present ({pct}%)**

## Gaps

### CG-001: {Description}

**Severity:** critical | high | medium | low
**Module:** {module-name}
**Category:** missing-feature | wrong-behavior | missing-error-handling | missing-test | drift
**Expected:** {what the spec says}
**Actual:** {what exists, or "Not implemented"}
**Evidence:** [source:{spec-path}:{lines}]
**Suggested Fix:** {concrete action}
```

### Phase 2: Implementation Gap Analysis

**Prompt:** `PROMPT_implgap.md`
**Model:** Sonnet
**Output:** `retro/implementation_gap.md`
**Prerequisite:** `retro/codegap.md` exists
**Agent swarm:** One Sonnet worker per module section in codegap.md

**Workflow:**

1. Read `retro/codegap.md` — the code-level gaps
2. Read `IMPLEMENTATION_PLAN.md` — the plan that guided the build
3. For each CG item, classify:
   - **PLANNED-NOT-BUILT** — in the plan, never implemented
   - **PLANNED-WRONG** — in the plan with wrong scope/approach
   - **NEVER-PLANNED** — genuine planning miss
   - **PLAN-DIVERGED** — plan changed mid-stream, this gap resulted

**Output format:**

```markdown
### IG-001: {Description}

**Upstream:** [gap:codegap.md#CG-NNN]
**Classification:** PLANNED-NOT-BUILT | NEVER-PLANNED | PLAN-DIVERGED | PLANNED-WRONG
**Plan ref:** TASK-NNN in IMPLEMENTATION_PLAN.md, or "Not in plan"
**Analysis:** {2-3 sentences on why this gap exists from a planning perspective}
```

### Phase 3: Plugin Gap Analysis

**Prompt:** `PROMPT_plugingap.md`
**Model:** Sonnet
**Output:** `retro/plugin_gap.md`
**Prerequisite:** `retro/implementation_gap.md` exists
**Agent swarm:** One Sonnet worker per module section in implementation_gap.md

**Workflow:**

1. Read `retro/implementation_gap.md`
2. Read `retro/retro_state.md` for which recipe was used
3. For each IG item, assess which recipe phase should have caught it:
   - **spec-writing** — the spec extraction phase missed this behavior
   - **planning** — the planning phase should have included this task
   - **building** — the build loop should have implemented this
   - **audit** — the parity checker should have flagged this
   - **none** — outside plugin scope (e.g., user error, tool limitation)

**Output format:**

```markdown
### PG-001: {Description}

**Upstream:** [gap:implementation_gap.md#IG-NNN]
**Codegap origin:** [gap:codegap.md#CG-NNN]
**Plugin phase:** spec-writing | planning | building | audit | none
**What should have happened:** {specific enforcement or guidance that was missing}
**What actually happened:** {what the plugin's prompt/workflow did or failed to do}
**Improvement opportunity:** {concrete change to recipe, PROMPT, or agent}
```

### Phase 4: Expected-vs-Reality Synthesis

**Prompt:** `PROMPT_synthesis.md`
**Model:** Opus (ultrathink)
**Output:** `retro/expected-vs-reality_gap.md`
**Prerequisite:** All three prior gap files exist
**Agent:** Single retro-synthesizer instance

**Workflow:**

1. Read all three gap documents in full
2. Identify 3-7 highest-signal themes that explain the gap pattern across the project
3. Structure by theme, not by module
4. Cross-link exhaustively to all three source documents

**Output format:**

```markdown
### EVR-001: {Theme title}

**Summary:** {one sentence}
**Pattern:** {what kept happening}
**Origin chain:** [gap:codegap.md#CG-NNN] -> [gap:implementation_gap.md#IG-NNN] -> [gap:plugin_gap.md#PG-NNN]

#### Evidence
- Code: [gap:codegap.md#CG-NNN] — {summary}
- Plan: [gap:implementation_gap.md#IG-NNN] — {summary}
- Plugin: [gap:plugin_gap.md#PG-NNN] — {summary}

#### Root Cause
{2-4 sentences explaining WHY this theme exists}
```

### Phase 5: Explanation Mining

**Prompt:** `PROMPT_explanations.md`
**Model:** Sonnet (workers) + Opus (final synthesis)
**Output:** `retro/E-V-R_explanations.md`
**Prerequisite:** `retro/expected-vs-reality_gap.md` exists
**Agent swarm:** One session-historian per JSONL file, then one retro-synthesizer to aggregate

**Session discovery:**

1. Read `retro/retro_state.md` for project directory
2. Encode path: `/Users/george/repos/myproject` → `-Users-george-repos-myproject`
3. List `~/.claude/projects/{encoded}/` — each `.jsonl` is a session
4. If no session files found, write output noting unavailability

**JSONL parsing approach:**

- Each file is 300-1600 lines, 1.5-2.5 MB — safely loadable whole
- Filter for user text messages and assistant text responses
- Detect course corrections: user text message following assistant message (non-tool-result content with non-null parentUuid)
- Match signals to EVR themes

**Output format:**

```markdown
### EXP-001: {Why this gap occurred}

**Gap ref:** [gap:expected-vs-reality_gap.md#EVR-NNN]
**Origin chain:** [gap:codegap.md#CG-NNN] -> ... -> [gap:expected-vs-reality_gap.md#EVR-NNN]
**Session evidence:** {session filename, timestamp}
**Root cause category:** context-loss | misunderstanding | tool-limitation | scope-creep | oversight
**User said:** "{exact quote}"
**Agent did:** "{summary}"
**Explanation:** {2-3 sentences on why this gap formed}
```

### Phase 6: Improvement TODO

**Prompt:** `PROMPT_todo.md`
**Model:** Opus (ultrathink)
**Output:** `retro/improvement_todo.md`
**Prerequisite:** All 5 prior retro documents
**Agent:** Single retro-synthesizer instance

**Two tracks:**

- **Track A: Project Improvements** — codebase/implementation fixes
- **Track B: Plugin Improvements** — changes to ralph-wiggum-toolkit recipes, PROMPTs, agents, methodology

**Output format:**

```markdown
### TODO-001: {Actionable task description}

**Priority:** P0 | P1 | P2
**Track:** project | plugin
**Explanation ref:** [gap:E-V-R_explanations.md#EXP-NNN]
**Full chain:** [gap:codegap.md#CG-NNN] -> [gap:implementation_gap.md#IG-NNN] -> [gap:plugin_gap.md#PG-NNN] -> [gap:expected-vs-reality_gap.md#EVR-NNN] -> [gap:E-V-R_explanations.md#EXP-NNN]
**Acceptance criteria:** {how to verify this is done}
**Effort:** XS | S | M | L | XL
**Action:** {concrete, specific: file to change, behavior to add, test to write}
```

---

## Integration Points

### `/ralph retro` Command

Add to the subcommand dispatch table in `commands/ralph.md`:

```
| `retro` | Run retrospective pipeline (all phases or specific phase) |
```

**Subcommand behavior:**

```
/ralph retro                      # Run all pending phases in order
/ralph retro --phase codegap      # Run only Phase 1
/ralph retro --from-phase implgap # Run from Phase 2 forward
```

**Phase dispatch logic:**

1. Check if `retro/retro_state.md` exists. If not, offer inline init.
2. Read `retro/retro_state.md` for phase status.
3. For each pending phase (in order, respecting `--phase`/`--from-phase`):

   ```bash
   claude -p --dangerously-skip-permissions \
     --model {phase_model} \
     --output-format stream-json \
     < PROMPT_{phase}.md
   ```

4. After each phase completes, update `retro/retro_state.md`.
5. If all phases done, show completion summary.

### `init.sh` Changes

Add `retrospective)` case to the recipe dispatch:

```bash
retrospective)
  create_dir_if_missing "retro" "Retrospective output directory"
  copy_template "PROMPT_codegap.md"
  copy_template "PROMPT_implgap.md"
  copy_template "PROMPT_plugingap.md"
  copy_template "PROMPT_synthesis.md"
  copy_template "PROMPT_explanations.md"
  copy_template "PROMPT_todo.md"
  copy_template "AGENTS.md"
  # retro_state.md populated by /ralph command (needs interactive detection)
  ;;
```

The `/ralph retro` command completes init interactively:

1. Auto-detect source recipe from `ralph/manifest.json` or `porting/manifest.json` (legacy)
2. Detect session JSONL path by encoding project directory
3. Write `retro/retro_state.md` with substitutions
4. Copy `CROSS_REF_STANDARD.md` to `retro/`

### SKILL.md Updates

Add to Available Recipes:

```markdown
- **retrospective**: Analyze a completed Ralph project. Produces: codegap → implementation gap → plugin gap → synthesis → session explanation → improvement TODO.
```

Trigger phrases: `"retrospective"`, `"retro"`, `"post-mortem"`, `"what went wrong"`, `"audit the project"`, `"improvement todo"`.

---

## Model Selection Rationale

Based on empirical variance testing from repo-clone/testing/:

| Task Type | Model | Rationale |
|-----------|-------|-----------|
| Per-module gap comparison | Sonnet | 3-5x lower variance than Haiku. Behavioral completeness identical across models. Citations deterministic. |
| Per-session JSONL analysis | Sonnet | Pattern matching + text extraction. Sonnet sufficient, no complex reasoning needed. |
| Cross-document synthesis | Opus | Requires cross-cutting pattern recognition across multiple documents. Theme identification is genuinely hard. |
| Improvement TODO | Opus | Prioritization and root-cause attribution require judgment. |

**Why not Haiku for workers?** Haiku has 2.3-3.3x variance in spec extraction (vs Sonnet 1.3-1.7x). For an audit workflow where accuracy matters more than cost, Sonnet's consistency is worth the premium. The retro runs once per project, not in a tight loop — cost is not the binding constraint.

---

## Loop Architecture Clarification

### The Flat Loop Model

In the Ralph methodology, every loop is **flat**: one `claude -p` call does its entire job and exits. There are no nested loops.

For a **build loop** iteration:

1. Agent gets fresh context (blank slate)
2. Reads IMPLEMENTATION_PLAN.md, specs, AGENTS.md from disk
3. **Picks the most important task** (the agent decides, not an external scheduler)
4. Implements it (may use 500 parallel subagents to read/search, but only 1 for writing)
5. Runs tests
6. Updates IMPLEMENTATION_PLAN.md
7. Commits and exits

Then `loop.sh` starts a fresh `claude -p` call and the cycle repeats. If a task wasn't finished, it stays TODO in the plan — the next iteration picks it up naturally.

**"One thing per loop" = one task per iteration.** A task may touch many files and produces one commit. The granularity is task-level, not file-level.

For the **retrospective recipe**, each phase is also flat — one `claude -p` call per phase. The sophistication comes from the chain of phases, not from nesting.

### The Weaving Loom: Layers, Not Nesting

Huntley's "Weaving Loom" concept describes layers of loops that connect through files on disk:

```
┌─────────────────────────────────────────────────────────┐
│  Layer 1: BUILD LOOP  (/ralph build)                    │
│  Flat: pick task → implement → test → commit → exit     │
│  Output: git commits + IMPLEMENTATION_PLAN.md updates   │
│                          │                              │
│                          ▼ (files on disk)              │
│                                                         │
│  Layer 2: OBSERVE  (iteration journal / session JSONL)  │
│  Hook-based: captures structured data during build      │
│  Output: iteration_journal.jsonl or raw session JSONL   │
│                          │                              │
│                          ▼ (files on disk)              │
│                                                         │
│  Layer 3: ANALYZE  (/ralph retro)                       │
│  Flat chain: 6 phases, each one-shot claude -p          │
│  Output: retro/ gap analysis documents + TODO           │
│                          │                              │
│                          ▼ (files on disk)              │
│                                                         │
│  Layer 4: IMPROVE  (apply Track B items to plugin)      │
│  Manual or future-automated: edit recipes/PROMPTs       │
│  Output: improved plugin for next project               │
└─────────────────────────────────────────────────────────┘
```

Each layer is flat. Layers connect through **files on disk**, not through context passing or nested invocations. This is the core architectural principle: disk is state, git is memory, context is ephemeral.

### Who Schedules What

| Level | Who Decides | What They Decide |
|-------|-------------|-----------------|
| Phase selection | Human or orchestrator | "Now run spec extraction", "Now run build", "Now run retro" |
| Task selection within build | The agent itself | Reads plan, picks most important task each iteration |
| Subagent dispatch within iteration | The agent itself | Fan-out for reads/searches, single-threaded for writes |
| Retro phase ordering | The recipe chain | codegap → implgap → plugingap → synthesis → explanations → todo |

The human stays "on the loop, not in the loop" — they decide when to switch phases but don't micromanage task ordering within a phase.

---

## Observability & Future Work

### The Observability → Review Pipeline

The retrospective recipe is the **automated review layer** that the ecosystem has been missing. Currently:

**v1.0 (raw JSONL parsing):** Phase 5 reverse-engineers "what happened" from Claude Code session JSONL — conversation logs not designed for review. Works but imprecise.

**Future (structured iteration journal):** A PostToolUse hook writes structured entries during build loops, giving Phase 5 precise data:

```json
{"iteration": 7, "task": "TASK-022", "action": "implemented", "files": ["src/auth.rs"], "test_result": "pass", "commit": "abc123"}
{"iteration": 8, "task": "TASK-023", "action": "attempted", "files": ["src/email.rs"], "test_result": "fail", "revert": true}
{"iteration": 9, "task": "TASK-023", "action": "attempted", "files": ["src/email.rs"], "test_result": "fail", "revert": true}
```

Phase 5 could then say: *"Iterations 8-9 were a revert spiral on TASK-023 (email service). This maps to EVR-003. The agent tried twice and failed because it depends on TASK-032 (Resend API client) which was never planned."* — much more precise than parsing raw conversation logs.

### Iteration Journal Specification (Track B Improvement)

Inspired by ABA's observability spec (`/Users/george/repos/aba/specs/observability.md`):

**Storage:** `ralph/iteration_journal.jsonl` — one JSON line per significant action during a build loop.

**Schema:**

```json
{
  "iteration": 3,
  "timestamp": "2026-03-18T14:22:01Z",
  "task": "TASK-007",
  "action": "implemented | attempted | skipped | reverted",
  "files_modified": ["src/auth.rs"],
  "test_result": "pass | fail | skipped",
  "test_output_summary": "42 passed, 0 failed",
  "commit": "abc123 | null",
  "revert": false,
  "cost_tokens": {"input": 12000, "output": 3400},
  "duration_s": 180
}
```

**Capture mechanism:** A `PostToolUse` hook on `Bash` commands that match test/build patterns, plus a `Stop` hook that writes the iteration summary.

**Health detection** (real-time, runs during build loop):

- **Stuck loop:** Same test failure 3+ consecutive iterations → pause and alert
- **Revert spiral:** 3+ consecutive reverts → pause and alert
- **Cost overrun:** Cumulative cost exceeds budget → pause and alert

Health detection is *preventive* (stop burning tokens). The retrospective is *diagnostic* (understand what went wrong after the fact). They are complementary, not redundant.

**Not in v1.0** — this is a Track B improvement the retro itself might surface as `TODO-NNN`.

### Backpressure Metrics

Also from ABA: track commit/revert ratios and consecutive failures to detect stuck loops. A future quality gate could pause the build loop when:

- Same test failure appears N consecutive iterations (stuck loop)
- Consecutive reverts exceed threshold (revert spiral)
- Token count approaches context limit (exhaustion)

### Loop Simplicity Principle

Each retro phase is a single-pass headless run — no iteration, no stop-hook, no loop state. The sophistication comes from the *chain*, not from any individual link. This keeps each phase debuggable and re-runnable independently.

---

## Build Sequence

### Phase 1 — Recipe Scaffold

- [ ] Create `recipes/retrospective/` directory structure
- [ ] Write `recipe.json`

### Phase 2 — Reference Documents

- [ ] Write `references/cross-ref-standard.md` (copy from docs/plans/)
- [ ] Write `references/methodology.md` (six-phase rationale)
- [ ] Write `references/session-jsonl-schema.md` (JSONL parsing reference)

### Phase 3 — Agent Definitions

- [ ] Write `agents/gap-worker.md`
- [ ] Write `agents/session-historian.md`
- [ ] Write `agents/retro-synthesizer.md`

### Phase 4 — Templates

- [ ] Write `templates/retro_state_template.md`
- [ ] Write `templates/AGENTS.md`
- [ ] Write `templates/PROMPT_codegap.md`
- [ ] Write `templates/PROMPT_implgap.md`
- [ ] Write `templates/PROMPT_plugingap.md`
- [ ] Write `templates/PROMPT_synthesis.md`
- [ ] Write `templates/PROMPT_explanations.md`
- [ ] Write `templates/PROMPT_todo.md`

### Phase 5 — Core Integration

- [ ] Add `retrospective)` case to `core/scripts/init.sh`
- [ ] Add `retro` subcommand to `commands/ralph.md`
- [ ] Update `skills/ralph/SKILL.md` with retrospective recipe
- [ ] Update `plugin.json` keywords
- [ ] Add `phase_models` support to loop dispatch (extend recipe.json schema)

### Phase 6 — Validation

- [ ] Run retro against TellMeMo port project (first real-world test)
- [ ] Review generated documents for quality
- [ ] Iterate on PROMPT wording based on results

---

## Data Flow Diagram

```
/ralph init --recipe retrospective [--project-dir /path/to/project]
    │
    ▼
init.sh → creates retro/ dir, copies 6 PROMPT files + AGENTS.md template
/ralph command → detects recipe, writes retro/retro_state.md + CROSS_REF_STANDARD.md
    │
    ▼
/ralph retro
    │
    ├─ Phase 1: claude -p --model sonnet < PROMPT_codegap.md
    │       ├─ Spawns 1-50 gap-worker (sonnet) per module
    │       │   ├─ Reads: specs/{module}.md + impl/{module}
    │       │   └─ Returns: gap fragment with CG-NNN IDs
    │       ├─ Aggregates into retro/codegap.md
    │       └─ Updates retro/retro_state.md: codegap → done
    │
    ├─ Phase 2: claude -p --model sonnet < PROMPT_implgap.md
    │       ├─ Reads: retro/codegap.md + IMPLEMENTATION_PLAN.md
    │       ├─ Spawns N sonnet workers (one per module in codegap)
    │       └─ Writes: retro/implementation_gap.md (IG-NNN IDs)
    │
    ├─ Phase 3: claude -p --model sonnet < PROMPT_plugingap.md
    │       ├─ Reads: retro/implementation_gap.md + recipe workflow
    │       ├─ Spawns N sonnet workers
    │       └─ Writes: retro/plugin_gap.md (PG-NNN IDs)
    │
    ├─ Phase 4: claude -p --model opus < PROMPT_synthesis.md
    │       ├─ retro-synthesizer (opus, ultrathink)
    │       ├─ Reads: all 3 gap files
    │       └─ Writes: retro/expected-vs-reality_gap.md (EVR-NNN IDs)
    │
    ├─ Phase 5: claude -p --model sonnet < PROMPT_explanations.md
    │       ├─ Discovers session JSONLs at ~/.claude/projects/{encoded}/
    │       ├─ Spawns 1 session-historian (sonnet) per .jsonl
    │       ├─ retro-synthesizer (opus) aggregates
    │       └─ Writes: retro/E-V-R_explanations.md (EXP-NNN IDs)
    │
    └─ Phase 6: claude -p --model opus < PROMPT_todo.md
            ├─ retro-synthesizer (opus, ultrathink)
            ├─ Reads: all 5 prior retro documents
            └─ Writes: retro/improvement_todo.md (TODO-NNN IDs)
```

---

## Critical Implementation Details

### Project Detection at Init

1. Read `{project_dir}/ralph/manifest.json` → extract `"recipe"` field
2. If no manifest, check `{project_dir}/porting/manifest.json` (legacy repo-clone) → treat as port
3. If neither exists but `IMPLEMENTATION_PLAN.md` exists → treat as uninitialized greenfield
4. If nothing exists → error with guidance

### Session JSONL Path Encoding

Claude Code stores sessions at `~/.claude/projects/{encoded-path}/`.
The encoding replaces `/` with `-` in the absolute project path.
Example: `/Users/george/repos/meetings` → `-Users-george-repos-meetings`

**Safe detection:** List `~/.claude/projects/` and match visually rather than computing blindly — directory names within the path may already contain hyphens, creating ambiguity.

### Parallelism Caps

- Phase 1 (codegap): Up to 50 gap-workers. Read-heavy, large projects may have many modules.
- Phases 2-3: One worker per module section in the upstream doc. Typically 10-30.
- Phase 5: One session-historian per JSONL file. Typically 3-20 sessions.
- Phases 4, 6: Single Opus instance. Synthesis is not parallelizable.

### Error Handling

Each PROMPT checks for its prerequisite file at the top:

```
If retro/codegap.md does not exist, stop and output:
"ERROR: Run Phase 1 (codegap) first. Use: /ralph retro --phase codegap"
```

This prevents silent failures where Phase 3 runs without Phase 2 output.

### Retro Directory Is Committed

Unlike `.claude/ralph-wiggum.local.md` (ephemeral session state), the `retro/` directory is a persistent project artifact. The final phase (TODO) includes a step to commit:

```bash
git add retro/ && git commit -m "retro: add retrospective analysis"
```

### Port vs Greenfield Layout Differences

| Aspect | Port | Greenfield |
|--------|------|------------|
| Specs location | `specs/src/*.md`, `specs/tests/*.md` | `specs/*.md` |
| Implementation | `{target_root}/` from manifest | `{src_dir}/` from manifest |
| Source comparison | Specs describe source behavior | Specs describe intended behavior |
| SEMANTIC_MISMATCHES.md | May exist | Does not exist |
| AGENTS.md | Has source + target languages | Has single language |

The `retro_state.md` captures these paths at init time so PROMPT files always have a single source of truth.

---

## Appendix A: Research Findings — High-Level Improvement Patterns

Research from Geoffrey Huntley's methodology, ClaytonFarr/ralph-playbook (892 stars), ghuntley.com, agentic-engineer.com, and the ABA repo (`/Users/george/repos/aba/`).

### This Recipe Fills the Biggest Gap in the Ecosystem

Neither Huntley nor ClaytonFarr have formalized an audit or retrospective loop. The methodology has 4 loop types (spec generation, reverse-engineering, planning, building) but **no post-build review mechanism**. Quality enforcement is purely backpressure-based (tests/builds). The retrospective recipe is novel.

### Patterns Validated by Research

| Pattern | Source | How We Apply It |
|---------|--------|----------------|
| "One task per loop" | Huntley | Each retro phase is one task (single-pass, no loop) |
| Phase pipeline with context clearing | agentic-engineer | 6 independent phases, each gets fresh context via `claude -p` |
| File-based state, not in-memory | Huntley, playbook | All retro documents are files; no context carries between phases |
| Backpressure as quality gate | Huntley | Each phase checks prerequisites before running |
| "Architect failures out permanently" | Huntley | Track B TODO items change the plugin itself, not just the project |
| Monolithic process model | Huntley | Each phase is one `claude -p` call with subagent swarms, not inter-agent communication |
| "The orchestration system is the product" | agentic-engineer | The retro recipe is infrastructure, not a prompt |

### Patterns for Future Versions (Track B Improvements)

#### Execution Journal Hook

**Pattern:** During build loops, a PostToolUse hook writes structured entries to `ralph/iteration_journal.jsonl`:

```json
{"iteration": 3, "timestamp": "...", "task": "TASK-007", "action": "implemented", "files": ["src/auth.rs"], "test_result": "pass", "commit": "abc123"}
```

**Source:** ABA repo `specs/observability.md` — thread files per iteration, cost tracking, backpressure metrics.
**Benefit:** Gives Phase 5 (explanation mining) structured data instead of raw JSONL parsing.
**Status:** Not in v1.0. The retro itself may surface this as a TODO item.

#### Convergence Detection

**Pattern:** Track whether the implementation plan is converging (tasks completing faster than new ones appear) or diverging (discovery outpacing implementation).

**Source:** Research gap — nobody tracks this. Simple metric: `tasks_completed / total_tasks` plotted per iteration.
**Benefit:** Automatic re-planning trigger when divergence is detected.

#### Consensus for Ambiguous Judgments

**Pattern:** For retro findings that are judgment calls (was this drift or intentional?), run 3-5 review agents and take majority vote.

**Source:** agentic-engineer reliability post — 3-of-5 consensus achieves ~99.14% accuracy on binary judgments.
**Benefit:** Reduces false positives in gap classification.

#### Cross-Iteration Context Summaries

**Pattern:** After each build loop iteration, append a one-line summary to a log file so the next iteration has richer context without bloating the main prompt.

**Source:** Research gap — methodology relies only on IMPLEMENTATION_PLAN.md for cross-iteration memory. A lightweight `ralph/iteration_log.md` would be more granular.
**Benefit:** Iteration N+1 knows what N did and why, not just what's marked done.

#### Automated Plan Health Checks

**Pattern:** Detect when the same task is attempted in consecutive iterations (stuck loop), or when the plan hasn't changed in N iterations (stale), or when revert ratio exceeds threshold (spiral).

**Source:** ABA repo — stuck loop detection, revert spiral detection, context exhaustion detection.
**Benefit:** Automatic loop pause before burning tokens on a stuck problem.

#### LLM-as-Judge Review Pass

**Pattern:** After build loop completes, run a separate model (or same model with review prompt) to audit recent commits for quality degradation, style drift, or security issues.

**Source:** Huntley mentions LLM-as-judge for subjective criteria but never formalizes it. agentic-engineer uses visual proof (screenshots).
**Benefit:** Catches issues that pass tests but violate intent.

### The "Weaving Loom" Vision

Huntley's `/loop/` post describes infrastructure running "Ralph under system verification loops" — a loop-of-loops where:

1. Top-level loop detects failures
2. Secondary loops study/analyze
3. Tertiary loops implement fixes
4. Quaternary loops verify

The retrospective recipe is the **secondary loop** in this architecture — it analyzes what happened. A future version could close the loop by automatically generating PROMPT modifications (tertiary) and running the build again (quaternary).

### Key Quotes

> "It's important to *watch the loop* as that is where your personal development and learning will come from." — Huntley

> "When you discover problems, put on your engineering hat and resolve the problem so it *never happens again*." — Huntley

> "I'm on the loop, not in the loop." — Huntley, /rad/

> "LLMs and agents are API calls — wrap them in orchestration systems rather than relying on single-shot prompts. The workflow system, not the model, is the actual product." — agentic-engineer
