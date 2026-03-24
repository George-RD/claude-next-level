# Spec Coherence Review

## Verdict: NEEDS_WORK

There are significant schema disagreements between the three specs that independently define state.json, naming inconsistencies between agent types, and a few missing pieces that would block or confuse implementation. The individual specs are each well-written and thorough, but they were clearly authored somewhat independently and need a reconciliation pass before implementation begins.

---

## Critical Issues (must fix before implementation)

### C1. Three incompatible state.json schemas

The architecture spec (section 4.2), commands spec (section "Cross-Cutting Concerns"), and hooks-session spec (section 4.2) each define state.json with different structures. An implementer would not know which one to follow.

**Key conflicts:**

| Field | Architecture | Commands | Hooks-Session |
|-------|-------------|----------|---------------|
| Session ID format | `2026-03-17T14-30-00` (ISO timestamp) | `cos-YYYYMMDD-HHMMSS` | Claude Code's native `session_id` |
| `waves` type | Array of objects with `id` field | Object keyed by wave number (`"1": {...}`) | Array of objects with `number` field |
| `agents` type | Object keyed by agent-id with inline fields | Not present (agents tracked via `work_items[].agent_id`) | Object keyed by agent-id with `name`, `type`, `work_item_id` |
| Session status enum | `initializing/active/checkpointing/suspended/completed` | `active/completed/failed/aborted` | `PLANNING/DISPATCHING/MONITORING/CHECKPOINTING/COMPLETE` |
| Work item status enum | (Not explicitly defined as work items) | `pending/dispatched/reviewing/coding/pr-created/merged/completed/failed/quality-gate-failed/conflict/blocked` | `pending/dispatched/complete/failed` |
| VCS field | `project.vcs` | `vcs_type` (top-level) | `vcs_type` (top-level) |
| Context tracking | `context.estimated_usage_pct` with `checkpoint_threshold` | `context_pct` (single number) | `context.percentage` with `context.last_checked` and `context.checkpoints[]` |
| Has `work_items` array? | No (uses flat `agents` map) | Yes | Yes |
| Has `quality_gates` object? | No (in `project.test_command` etc.) | No | Yes |
| Has `installed_plugins`? | No | No | Yes |
| `created_at` vs `created` | `created_at` | `created` | `created_at` |

**Resolution:** Pick ONE canonical schema. Recommendation: use the hooks-session schema as the base (it is the most complete and is what the actual scripts will write), then extend it with the work-item detail fields from the commands spec. Update architecture and commands specs to reference the canonical version rather than redefining it.

### C2. Agent type naming mismatch

| Spec | Names used |
|------|-----------|
| Architecture (section 7) | `research-agent`, `implement-agent`, `review-agent` |
| Architecture (directory structure) | `agents/research-agent.md`, `agents/implement-agent.md`, `agents/review-agent.md` |
| Commands spec | References agent types by role only (`research`, `implement`, `review`), no file names |
| Agents-templates spec | Files: `agents/researcher.md`, `agents/implementer.md`, `agents/reviewer.md` |
| Skill spec | Agent types: `Research`, `Implementation`, `Review`, `Wave coordinator`, `Fix agent` |

The architecture spec says the files are `research-agent.md`, `implement-agent.md`, `review-agent.md`, but the agents-templates spec (which contains the actual file content) uses `researcher.md`, `implementer.md`, `reviewer.md`. These are the files that will actually be created, so whichever naming is chosen, both specs must agree.

**Resolution:** Pick one convention. The agents-templates spec uses `researcher/implementer/reviewer` which matches the repo-clone convention (e.g., `spec-extractor.md`, `parity-checker.md` -- noun forms). Update the architecture spec's directory structure to match.

### C3. Agent frontmatter fields disagree

Architecture spec (section 7) defines agent frontmatter as:

```yaml
name: research-agent
subagent_type: general-purpose  # or coding-agent, checkpoint-reviewer
model: sonnet
mode: default  # or bypassPermissions
```

Agents-templates spec defines agent frontmatter as:

```yaml
name: researcher
description: |
  <detailed description with examples>
model: sonnet
```

Missing from agents-templates: `subagent_type`, `mode`. These are important -- `subagent_type` and `mode` control how Claude Code dispatches the agent (e.g., `bypassPermissions` for implementation agents). The agents-templates spec has no `mode` field at all, which means implement agents would run in default (permission-asking) mode.

Also, the repo-clone agent convention (spec-extractor.md) uses `name`, `description` (with examples), and `model` -- matching agents-templates but NOT architecture.

**Resolution:** Reconcile. The agents-templates format (with rich description and examples) matches existing plugin conventions and should be kept. Add `subagent_type` and `mode` fields to the agents-templates frontmatter where needed. Specifically, `implementer.md` needs `mode: bypassPermissions` or equivalent.

### C4. Completion markers disagree

| Spec | Marker |
|------|--------|
| Architecture (section 7.2) | Not specified (says "Mandatory completion steps: implement, test, commit") |
| Commands spec (section 3, implement) | `IMPLEMENTATION_COMPLETE` plain text block |
| Agents-templates spec | `=== IMPLEMENTATION REPORT ===` ... `=== END REPORT ===` |

The commands spec's `/cos:implement` post-completion pipeline checks for `IMPLEMENTATION_COMPLETE`, but the agents-templates spec instructs the agent to output `=== IMPLEMENTATION REPORT ===` with a `Status: COMPLETE | PARTIAL | BLOCKED` field. An implementer following the agents-templates spec would produce output that the commands spec's parser would not detect.

**Resolution:** Standardize on the richer report format from agents-templates (`=== IMPLEMENTATION REPORT ===` with Status field). Update the commands spec's post-completion pipeline to parse the report delimiters and Status field instead of looking for `IMPLEMENTATION_COMPLETE`.

---

## Inconsistencies (should fix)

### I1. Session ID format

- Architecture: ISO timestamp `2026-03-17T14-30-00`
- Commands: `cos-YYYYMMDD-HHMMSS` (e.g., `cos-20260317-143022`)
- Hooks-session: Uses Claude Code's native `session_id` from stdin

The hooks spec is correct -- the session ID comes from Claude Code and is not something we generate. The architecture and commands specs invent their own formats. This matters because `init.sh` creates the directory using the Claude Code session ID, so commands that try to find sessions by a different ID format will fail.

**Resolution:** Use Claude Code's native session ID everywhere. Remove the custom format definitions from architecture and commands. If a human-friendly label is desired, store it as a field within state.json but use the native ID for directory naming.

### I2. `/cos:handoff` present in architecture but missing from commands spec

Architecture spec section 6.7 defines `/cos:handoff` with full behavior. The commands spec does not include it. The directory structure in architecture lists `commands/handoff.md`. The hooks-session spec's checkpoint.sh partially covers the same ground (saving state for resumption).

**Resolution:** Either add `/cos:handoff` to the commands spec with the same level of detail as other commands, or explicitly note that checkpoint.sh + PreCompact/Stop hooks replace the need for a manual handoff command. Given that context limits may be hit mid-session (not just at hook boundaries), a manual `/cos:handoff` command is useful and should be fully specified in the commands spec.

### I3. Retry budget disagreement

| Spec | Max retries |
|------|------------|
| Architecture (section 10.1) | 3 retries (then abandoned) |
| Skill (section 7) | 2 retries (3 total attempts), then skip |
| Agents-templates (Part 5) | 2 retries (for researchers/reviewers), check-then-retry for implementers |
| Commands spec | No retry logic defined (just marks as failed) |

**Resolution:** Standardize on 2 retries (3 total attempts) as stated in the skill and agents-templates specs. Update architecture to match.

### I4. Wave backpressure limit

- Skill spec (section 2): "Maximum 4 agents per wave (backpressure)"
- Hooks-session init.sh: `max_parallel` defaults to 4, configurable
- Architecture spec: "max 5 agents" for research (section 6.2)
- Commands spec: No explicit limit mentioned

The architecture allows up to 5 research agents in one wave but the skill caps all waves at 4.

**Resolution:** Standardize at 4 (configurable via `config.json`). Update architecture's research agent section.

### I5. Workspace path conventions

- Architecture: `../project@{agent-id}` for JJ workspaces
- Commands spec: `~/.chief-of-staff/workspaces/item-{id}` for JJ, Agent SDK for git
- Commands spec (wave): `~/.chief-of-staff/workspaces/wave-{wave}-item-{issue}`
- Skill spec: `../cos-agent-{id}` for both JJ and git

Three different workspace path conventions. This matters for cleanup scripts and for the status command finding active workspaces.

**Resolution:** Pick one convention. `~/.chief-of-staff/workspaces/` from the commands spec is cleanest because it centralizes all workspaces in a known location regardless of project directory. Standardize this across all specs.

### I6. Status command `allowed-tools` conflict

Architecture spec (section 6.6) defines:

```yaml
allowed-tools: ["Bash(cat ~/.chief-of-staff/sessions/*/state.json 2>/dev/null | head -200)"]
```

Commands spec (section 6) defines:

```yaml
allowed-tools:
  - Bash
  - Read
  - Glob
```

The architecture version overly restricts the Bash tool to a single command pattern. The commands spec version is more practical and matches the convention of other plugins (cycle/pr.md uses `Bash`, `Read`, `Edit`, etc.).

**Resolution:** Use the commands spec version.

### I7. Skill spec defines a "Fix agent" and "Wave coordinator" not defined elsewhere

The skill spec (section 3, Agent Types table) lists:

- **Fix agent**: "Address review comments, fix CI failures" -- runs in same workspace as original, sonnet, background
- **Wave coordinator**: "Plan waves, analyze dependency graphs" -- opus model, foreground/blocking

Neither of these has an agent definition in agents-templates, a file in the directory structure, or a command to dispatch them.

**Resolution:** Either add these to the agents-templates spec and architecture directory structure, or remove them from the skill spec. The Fix agent is useful but could be deferred to v2 (the commands spec already handles failures by re-dispatching the implement agent). The Wave coordinator is described as the orchestrator itself operating in foreground mode, not a separate agent -- clarify this in the skill spec.

---

## Gaps (missing pieces)

### G1. No `/cos:setup` command spec

The hooks-session spec (section 4.5) mentions `config.json` is "Created by `/cos:setup` or manually." No spec defines this command. If it is deferred, mark it explicitly.

### G2. How conventions template gets populated is unclear

The agents-templates spec defines `templates/conventions.md` with placeholders (`{{PROJECT_NAME}}`, `{{LANGUAGES}}`, `{{FORMATTERS}}`, etc.). The dispatch protocol (Part 4) says the orchestrator renders this template. But no command or script spec describes the actual rendering logic -- how does the orchestrator detect languages, find formatters, etc.?

The skill spec (section 5, Quality Gate Injection) describes gate sources (CLAUDE.md, next-level config, language defaults) but does not map those sources to the specific convention template placeholders.

**Resolution:** Add a "Convention Detection" section to either the commands spec or the skill spec that maps: (a) which project files are read, (b) which placeholders each file populates, (c) fallback values when files are missing.

### G3. No spec for `templates/agent-prompt-base.md` or `templates/wave-summary.md`

Architecture directory structure lists `templates/agent-prompt-base.md` and `templates/wave-summary.md`. Neither is defined in the agents-templates spec. The agents-templates spec instead defines `templates/research-prompt.md`, `templates/implementation-prompt.md`, `templates/review-prompt.md`, and `templates/conventions.md` -- a different set of files.

**Resolution:** Reconcile the directory structure with the agents-templates spec. It appears the agents-templates spec supersedes the architecture's template list. Update architecture to list the actual template files from agents-templates, or merge the concepts (perhaps `agent-prompt-base.md` is replaced by the individual per-type prompts).

### G4. `templates/handoff-resume.md` not defined

Architecture references this template. Neither the agents-templates spec nor the commands spec defines its content. This is needed for `/cos:handoff`.

### G5. `scripts/session-init.sh` and `scripts/session-status.sh` overlap with hooks

Architecture lists `scripts/session-init.sh` and `scripts/session-status.sh` as separate scripts. The hooks-session spec defines `hooks/scripts/init.sh` and `hooks/scripts/checkpoint.sh` with a `hooks/scripts/utils.sh`. These appear to overlap. Meanwhile, the architecture also lists `scripts/detect-isolation.sh` which the hooks-session init.sh subsumes (VCS detection is inline in init.sh).

**Resolution:** Decide on one directory structure for scripts. Recommendation: put everything under `hooks/scripts/` as the hooks-session spec defines, since that is where Claude Code looks for hook scripts. Remove `scripts/` from the architecture directory structure or make it explicit that `scripts/` is for non-hook utility scripts only.

### G6. No `utils.sh` sourcing of shared functions from next-level

The hooks-session spec says `source "$SCRIPT_DIR/utils.sh"` but chief-of-staff has its own `utils.sh` rather than reusing next-level's. The architecture says "reads next-level hook configs to build quality-gate fragments." How this cross-plugin file reading works is not specified anywhere.

---

## Convention Violations

### CV1. Agent frontmatter: missing `description` with examples

Existing plugins (repo-clone's `spec-extractor.md`, `parity-checker.md`) use a rich `description` field with `<example>` tags. The architecture spec's agent frontmatter (section 7) only has a one-line `description`. The agents-templates spec correctly uses the rich format. The architecture spec should be updated to match.

### CV2. Command frontmatter: architecture vs actual

The architecture spec (section 6) uses YAML-in-markdown for command frontmatter that does not match the actual YAML frontmatter format used by existing plugins. For example, the architecture uses:

```yaml
allowed-tools: ["Bash(cat ~/.chief-of-staff/sessions/*/state.json 2>/dev/null | head -200)"]
```

But real plugins (cycle/pr.md) use:

```yaml
allowed-tools:
  - Bash
  - Read
  - Edit
  ...
```

The commands spec correctly uses the list format. The architecture spec should not redefine command frontmatter.

### CV3. File naming: `SKILL.md` location

Architecture says `skills/cos/SKILL.md`. This matches the cycle convention (`skills/cycle/SKILL.md`) -- correct.

### CV4. Plugin.json is consistent

Architecture's plugin.json (section 1) follows the same format as cycle and repo-clone. No issues.

### CV5. hooks.json format

The hooks-session spec defines `hooks.json` at the top level (presumably `chief-of-staff/hooks/hooks.json`), but the directory structure in architecture does not list a `hooks/` directory at all. The architecture only lists `scripts/`. This is a structural gap -- hooks need to be in `hooks/hooks.json` per Claude Code plugin conventions.

**Resolution:** Add `hooks/hooks.json`, `hooks/scripts/init.sh`, `hooks/scripts/checkpoint.sh`, `hooks/scripts/utils.sh` to the architecture's directory structure.

---

## Suggestions (nice to have)

### S1. Unify "the spec of truth" for state.json

Create a single `specs/state-schema.md` file that is the canonical reference. All other specs reference it rather than embedding their own version.

### S2. Add a concrete end-to-end walkthrough

The architecture has workflow patterns (section 9) and the hooks-session has a lifecycle walkthrough, but no spec traces a complete `/cos "implement #18, review PR #55"` invocation from user input through state changes, agent dispatches, and completion. This would catch integration gaps.

### S3. Consider merging architecture + commands into a single spec

The architecture spec duplicates much of the commands spec (section 6 of architecture is a lighter version of the commands spec). This creates two places to update and two places where definitions can diverge.

### S4. The skill spec is self-contained and could serve as the primary reference

The skill spec (SKILL.md) is the most internally consistent document. Consider promoting it to the "source of truth" for behavioral patterns and having commands/architecture reference it rather than redefining patterns.

### S5. Template rendering: consider simpler approach than mustache

The architecture mentions "mustache-style templates" (section 12.3) but the agents-templates spec uses `{{PLACEHOLDER}}` syntax that looks like mustache but is actually just string replacement. Clarify that no actual mustache library is needed -- these are plain string substitutions done by the orchestrator inline.

---

## Implementation Order (recommended)

1. **Reconcile state.json schema** -- Create a single canonical schema before any code is written. This unblocks everything else. (30 min)

2. **Reconcile agent naming and frontmatter** -- Decide on `researcher.md` vs `research-agent.md`, add missing frontmatter fields. (15 min)

3. **Reconcile completion markers** -- Pick `=== IMPLEMENTATION REPORT ===` format, update commands spec. (10 min)

4. **Update architecture directory structure** -- Add `hooks/` directory, reconcile `scripts/` vs `hooks/scripts/`, update template file list. (15 min)

5. **hooks/scripts/utils.sh + hooks/hooks.json** -- Foundation for all hooks. (Implement first)

6. **hooks/scripts/init.sh** -- Session bootstrap, VCS detection, state creation. (Implement second)

7. **hooks/scripts/checkpoint.sh** -- State persistence. (Implement third)

8. **templates/conventions.md** -- Convention detection and rendering logic. (Implement fourth -- agents need this)

9. **agents/researcher.md + templates/research-prompt.md** -- Simplest agent type, no isolation needed. (Implement fifth)

10. **commands/cos.md** -- Entry point and routing. (Implement sixth -- depends on state schema being settled)

11. **commands/research.md** -- First dispatch command, exercises the full dispatch-monitor-collect loop. (Implement seventh)

12. **commands/status.md** -- Dashboard, useful for debugging all subsequent work. (Implement eighth)

13. **agents/implementer.md + templates/implementation-prompt.md** -- Implementation agent with isolation. (Implement ninth)

14. **commands/implement.md** -- Implementation dispatch with workspace creation and PR pipeline. (Implement tenth)

15. **commands/wave.md** -- Multi-issue wave coordination. (Implement eleventh -- builds on implement)

16. **agents/reviewer.md + templates/review-prompt.md** -- Review agent. (Implement twelfth)

17. **commands/review.md** -- Review dispatch and cycle delegation. (Implement thirteenth)

18. **commands/handoff.md + templates/handoff-resume.md** -- Context continuity. (Implement fourteenth)

19. **skills/cos/SKILL.md** -- Domain knowledge consolidation. (Implement fifteenth -- captures lessons from implementation)

20. **plugin.json + marketplace registration** -- Packaging. (Last)

---

## Summary

The five specs cover the chief-of-staff plugin comprehensively, but they were written with enough independence that they have diverged on foundational definitions: the state.json schema, agent naming, completion markers, directory structure, and status enums. These are not philosophical disagreements -- they are concrete conflicts that would force an implementer to make arbitrary choices or ask for clarification repeatedly.

The most impactful fix is reconciling the state.json schema into a single canonical definition. This touches all five specs and resolves roughly half of the issues listed above. The second most impactful fix is reconciling agent naming and frontmatter fields, which resolves the gap between architecture and agents-templates.

The individual quality of each spec is high. The commands spec is particularly thorough with its input parsing, error handling tables, and state transition documentation. The agents-templates spec provides excellent, implementation-ready agent definitions with rich examples. The hooks-session spec has well-designed scripts with proper error handling and idempotency. The skill spec provides strong behavioral guidance. Once the cross-spec inconsistencies are resolved, this plugin is ready to build.
