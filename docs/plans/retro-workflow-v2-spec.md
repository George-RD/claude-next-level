# Retrospective Workflow v2 — Specification

**Status:** Draft
**Date:** 2026-03-23
**Plugin:** ralph-wiggum-toolkit
**Depends on:** [Retrospective Recipe v1](retrospective-recipe-spec.md), [Cross-Reference Standard](retrospective-audit-crossref-spec.md)

---

## Problem Statement

The current retrospective recipe answers "what's wrong between spec and code?" but leaves three critical gaps:

1. **No operational audit.** The retro audits code vs spec alignment but not whether the agent followed the prescribed workflow — did it commit per task? use the right scripts? route to the right models? provide handoff? This means entire categories of failure (skipped commits, ignored CLAUDE.md instructions, wrong tool usage) go undetected.

2. **No handover.** The retro produces `retro/todo.md` with 57 items, but there's no document designed to start a new session — either in the project repo (Track A fixes) or the plugin repo (Track B fixes). A new session has to load the full todo and re-derive context, risking things being missed.

3. **No exit recommendations.** Every Ralph exit path (build complete, plan complete, retro complete, init complete) says "done, here's the next command" without explaining what to expect, what decisions are coming, or what the recommended action is.

---

## Design

### 1. Operational Audit Phase (new Phase: `opsaudit`)

**Question this phase answers:** Did the agent follow the prescribed workflow, and where did operational discipline break down?

**Position in the chain:** Runs after Phase 5 (explanations), before Phase 6 (todo). This gives the todo phase operational findings alongside behavioral findings.

```
Phase 1: codegap        — What's missing between spec and code?
Phase 2: implgap        — Was it planned? Planned wrong? Never planned?
Phase 3: plugingap      — Should the plugin workflow have caught it?
Phase 4: synthesis       — Thematic synthesis
Phase 5: explanations    — WHY did it happen? (session history)
Phase 5b: opsaudit  [NEW] — Did the agent follow the workflow?
Phase 6: todo            — What to fix (now includes ops findings)
Phase 7: handover  [NEW] — Produce handover documents
```

**What it audits:**

#### a. Workflow Compliance

Check whether the agent followed the prescribed ralph workflow:

| Check | How to detect | Severity if missing |
|-------|---------------|-------------------|
| Used `/ralph init` to scaffold | Look for init script execution in session tool calls | HIGH — means no state.json, no quality gates |
| Used `/ralph plan` before build | Check session for plan phase tool calls, or check if IMPLEMENTATION_PLAN.md was created via ralph | MEDIUM — manual planning may be fine |
| Used `/ralph build` (not manual) | Check if loop.sh was invoked, or if stop-hook.sh fired | HIGH — means no quality gates ran |
| Quality gates actually ran | Check for gate results in `ralph/last-gate-result.json` history, or tool calls to gate scripts | HIGH — the whole point of v2 |
| Correct scripts used | Match tool calls against expected scripts from recipe | MEDIUM |

Detection method: Parse session JSONL for `tool_use` blocks where `name == "Bash"` and inspect `input.command` for ralph script invocations. Cross-reference against `ralph/state.json` phase transitions.

#### b. Commit Discipline

| Check | How to detect | Severity if missing |
|-------|---------------|-------------------|
| Commit per completed task | Count git/jj commit calls in session vs completed task count in state.json | HIGH — no incremental history |
| Meaningful commit messages | Extract commit message content from tool calls | LOW — style issue |
| Commits on green (not red) | Check if gate passed before commit (correlate timestamps) | MEDIUM |

Detection method: Parse session JSONL for `Bash` tool calls containing `git commit`, `jj commit`, `jj describe`, `jj new`. Compare count against tasks marked `done` in `ralph/state.json`.

#### c. Model Routing

| Check | How to detect | Severity if missing |
|-------|---------------|-------------------|
| Opus for synthesis tasks | Check `msg.message.model` on assistant messages during synthesis-type work | LOW — cost/quality tradeoff |
| Sonnet for atomic workers | Check model on subagent messages | LOW |
| No haiku for complex reasoning | Flag if haiku used for planning/synthesis | MEDIUM |

Detection method: Extract `model` field from assistant entries. Group by task phase. Flag mismatches against recipe's `phase_models` config.

#### d. Session Efficiency

| Check | How to detect | Severity if missing |
|-------|---------------|-------------------|
| Context compactions | Count `summary` entries in JSONL | INFO — indicates long sessions |
| Token usage per task | Aggregate usage metadata by task phase | INFO |
| Subagent spawning | Count `isSidechain: true` messages | INFO |
| Duration per task | Calculate from timestamps | INFO |

These are informational, not failures. They help understand whether the session was efficient.

#### e. Handoff Quality

| Check | How to detect | Severity if missing |
|-------|---------------|-------------------|
| Session ended with recommendation | Check last assistant text message for next-steps language | HIGH — the user complaint |
| Status summary at completion | Check for stats/summary in final output | MEDIUM |
| State files updated | Check if ralph/state.json reflects actual completion state | HIGH |

**Output format:**

```markdown
# Operational Audit

## Metadata
- **Session count:** {n}
- **Total duration:** {hh:mm}
- **Total tokens:** {n}

## Summary
{2-3 sentences: overall operational health, biggest issues}

## Findings

### OPS-001: {Finding title}

**Category:** workflow-compliance | commit-discipline | model-routing | session-efficiency | handoff-quality
**Severity:** HIGH | MEDIUM | LOW | INFO
**Evidence:** {session filename, timestamp, exact tool call or absence thereof}
**Expected:** {what should have happened per the recipe/CLAUDE.md}
**Actual:** {what actually happened}
**Impact:** {what was lost or risked because of this}
```

**ID prefix:** `OPS-NNN`

**Model:** Sonnet (structured comparison against known rules — no creative synthesis needed)

**Integration with todo phase:** Phase 6 reads `retro/opsaudit.md` alongside the other 5 documents. OPS items get their own chain: `OPS-NNN -> TODO-NNN`. They don't need the CG→IG→PG chain because they're not behavioral gaps — they're process gaps.

---

### 2. Handover Phase (new Phase 7: `handover`)

**Question this phase answers:** Given everything the retro found, what should happen next — and in which repo?

**Runs after:** Phase 6 (todo), which now includes operational findings.

**Produces two documents:**

#### a. `retro/HANDOVER_PROJECT.md`

Designed to be the first thing read when opening a new Claude session in the project repo.

```markdown
# Project Handover: {project_name}

## Generated
{date} by retrospective recipe v{version}

## Status
{One paragraph: what state the project is in, what percentage of spec behaviors
are present, what's stubbed vs functional}

## Critical Issues (P0)
{Grouped into workstreams, not a flat list. Each workstream is a coherent
set of related P0 items that should be tackled together.}

### Workstream 1: {name, e.g. "Auth Provider Implementation"}
**Items:** TODO-003, TODO-007, TODO-012
**Effort:** {sum of item efforts}
**Summary:** {what this workstream accomplishes}
**Start with:** TODO-003 — {why this one first}
**Dependencies:** {any ordering constraints}

### Workstream 2: ...

## Important Issues (P1)
{Same workstream format, but briefer}

## Human Observations
{Section for the user to add findings the retro missed.
Uses HO-NNN IDs with relaxed chain requirement.}

### HO-001: {title}
**Observed by:** {user}
**Category:** {free-form}
**Description:** {what was noticed}
**Suggested action:** {what to do about it}

## How to Use This Document
1. Open a new Claude session in {project_dir}
2. Say: "Read retro/HANDOVER_PROJECT.md and start on Workstream 1"
3. After each workstream, re-run `/ralph retro --phase codegap` to verify gaps are closed
```

#### b. `retro/HANDOVER_PLUGIN.md`

Designed to be read in the plugin repo (claude-next-level), not the project repo.

```markdown
# Plugin Handover: {project_name} Retrospective

## Generated
{date} from {project_dir} retrospective

## Context
{2-3 paragraphs: what the project was, what recipe was used, what went wrong
at a high level. Enough context that someone in the plugin repo understands
the situation without loading the project.}

## Plugin Issues Found

### From Behavioral Audit (Track B items)
{Each TODO-NNN from Track B, rewritten with plugin-repo file paths.
Instead of "change PROMPT_build.md" it says
"change ralph-wiggum-toolkit/recipes/greenfield/templates/PROMPT_build.md"}

### From Operational Audit (OPS items that indicate plugin gaps)
{OPS items where the plugin should have enforced something but didn't.
Rewritten as plugin changes with specific file paths.}

## Suggested Implementation Order
{Sequence the plugin changes by impact and dependency}

## How to Use This Document
1. Open a new Claude session in the plugin repo
2. Say: "Read retro/HANDOVER_PLUGIN.md from {project_dir} and implement the fixes"
3. After implementing, bump plugin version and re-run retro on the project
```

#### c. Human Observations Integration

The `HO-NNN` prefix is added to the cross-reference standard:

| Document | Prefix | Example |
|----------|--------|---------|
| Human observations | HO | HO-001 |

**Relaxed chain requirement:** HO items don't need a CG→IG→PG→EVR→EXP chain. They need:

- **Category** (free-form: workflow, ux, performance, missed-gap, etc.)
- **Description** (what was observed)
- **Suggested action** (optional)

HO items can be added to `retro/HANDOVER_PROJECT.md` at any time — the handover doc is designed to be a living document, not a frozen audit artifact.

**Model:** Opus (requires cross-cutting synthesis, workstream grouping, and judgment about sequencing)

---

### 3. Exit Path Recommendations

Every Ralph exit point gets a structured recommendation block. This is not a new retro phase — it's a change to the build loop, plan loop, and retro completion paths.

#### Pattern

Every exit produces:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{Phase} Complete

What was done:
  {2-3 lines of stats: tasks completed, tests passing, gaps found, etc.}

What to watch for:
  {1-2 potential issues or decision points coming up}

Recommended next action:
  {specific command or action, with rationale}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Per Exit Point

**Build complete:**

```
What was done:
  44 tasks completed, 3 fix tasks, Tier 3 passed
  {n} commits made ({m} tasks without commits — WARNING if m > 0)

What to watch for:
  {n} todo!() stubs detected (if applicable)
  {n} tasks were omnibus (>5 behaviors)

Recommended next action:
  Run `/ralph retro` to audit spec-vs-implementation alignment
  and identify gaps before shipping.
```

**Plan complete:**

```
What was done:
  {n} tasks planned across {m} phases
  Estimated effort: {XS/S/M/L/XL distribution}

What to watch for:
  {n} tasks have >5 behaviors (consider splitting)
  {n} tasks have external dependencies

Recommended next action:
  Review IMPLEMENTATION_PLAN.md, then run `/ralph build`.
  The build loop will enforce quality gates at 3 tiers.
```

**Retro complete:**

```
What was done:
  {n} code gaps, {m} implementation gaps, {p} plugin gaps
  {q} themes synthesized, {r} session explanations
  {s} improvement items ({P0 count} P0, {P1 count} P1, {P2 count} P2)

What to watch for:
  Top theme: {EVR-001 title} ({n} gaps)
  {m} items are plugin-track (fix in plugin repo)

Recommended next action:
  Review retro/HANDOVER_PROJECT.md for prioritized workstreams.
  For plugin fixes, copy retro/HANDOVER_PLUGIN.md to the plugin repo.
```

**Init complete:**

```
What was done:
  Scaffolded {recipe} project with {language} configuration
  Quality gates: {tier 1}, {tier 2}, {tier 3}

What to watch for:
  Verify gate commands in ralph/state.json match your toolchain
  (e.g., test runner, linter, type checker)

Recommended next action:
  {For greenfield: Run `/ralph spec` to define requirements}
  {For port: Run `/ralph plan` to create the implementation plan}
```

#### Implementation Approach

The exit recommendation is generated by the orchestrating agent (the `/ralph` command handler), not by the loop scripts. The loop scripts exit with a status code and minimal message. The `/ralph` command reads state.json and produces the rich recommendation.

This keeps the shell scripts simple (they already are) and puts the intelligence in the markdown command spec where it's easier to iterate.

---

## Data Flow: How JSONL Gets Used

```
~/.claude/projects/{encoded-path}/*.jsonl
         │
         ├── Phase 5 (explanations) — text signals: corrections, ignored instructions
         │                            [EXISTING, unchanged]
         │
         └── Phase 5b (opsaudit) — structured signals: tool calls, models, timing
                                   [NEW]
                                   │
                                   ├── Bash tool calls → commit discipline, script usage
                                   ├── msg.message.model → model routing
                                   ├── msg.message.usage → token efficiency
                                   ├── isSidechain/sessionId → subagent patterns
                                   └── last assistant message → handoff quality
```

The session-historian (Phase 5) and ops-auditor (Phase 5b) read the same JSONL files but extract different signals. Phase 5 looks for human-readable conversation patterns. Phase 5b looks for structured operational data.

This is the same data claude-devtools visualizes — we're just extracting it programmatically with `jq` rather than rendering it in an Electron GUI.

---

## Cross-Reference Standard Updates

New prefixes:

| Document | Prefix | Example |
|----------|--------|---------|
| Operational audit | OPS | OPS-001 |
| Human observations | HO | HO-001 |

Chain rules:

- OPS items: `OPS-NNN -> TODO-NNN` (no behavioral chain needed)
- HO items: standalone, no chain required (human-authored)
- TODO items from ops: `[gap:opsaudit.md#OPS-NNN]` as upstream ref

---

## Phase Summary (Updated)

| Phase | Question | Model | Output |
|-------|----------|-------|--------|
| 1. codegap | What's missing between spec and code? | Sonnet workers | retro/codegap.md |
| 2. implgap | Was it planned? Planned wrong? Never planned? | Sonnet | retro/implgap.md |
| 3. plugingap | Should the plugin have caught it? | Sonnet | retro/plugingap.md |
| 4. synthesis | What themes explain the gap pattern? | Opus | retro/synthesis.md |
| 5. explanations | WHY did it happen? (conversation evidence) | Sonnet workers + Opus | retro/explanations.md |
| 5b. opsaudit | Did the agent follow the workflow? | Sonnet | retro/opsaudit.md |
| 6. todo | What to fix? (now includes ops findings) | Opus | retro/todo.md |
| 7. handover | Produce actionable handover documents | Opus | retro/HANDOVER_PROJECT.md, retro/HANDOVER_PLUGIN.md |

---

## What This Does NOT Cover

- **Automated fix application.** No `/ralph fix` command that reads todo.md and feeds items into the build loop. That's a separate feature.
- **DevTools integration.** claude-devtools is a GUI with no CLI/API. We extract the same data directly from JSONL. If devtools adds an export API later, we could consume it.
- **Live operational monitoring.** The opsaudit is post-hoc. A real-time hook that refuses to proceed without a commit would be a separate stop-hook enhancement (and is a likely Track B output from running this improved retro).

---

## Open Questions

1. **Should opsaudit be 5b or a standalone phase number?** Calling it 5b keeps the numbering familiar but may confuse tooling that expects integer phase IDs. Alternative: renumber as Phase 6 and bump todo/handover to 7/8.

2. **Should HANDOVER_PROJECT.md be regenerated or manually maintained?** If regenerated, human observations (HO items) would need to be preserved across re-runs. Options: (a) store HO items in a separate file that handover reads, (b) detect and preserve the HO section during regeneration.

3. **How prescriptive should exit recommendations be?** Current design gives one recommended action. Alternative: give 2-3 options with tradeoffs. Risk: decision paralysis.
