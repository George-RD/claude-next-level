# Retrospective Recipe -- Design Rationale

Why the retrospective recipe is built the way it is.
Read this to understand the design decisions, not the operational details.

---

## Why Eight Phases

Each phase answers exactly one question:

| Phase | Question |
|-------|----------|
| 1. codegap | What behavioral gaps exist between spec and implementation? |
| 2. implgap | Were those gaps planned for, planned wrong, or never planned? |
| 3. plugingap | Should the plugin workflow have caught them? |
| 4. synthesis | What themes explain the gap pattern across the whole project? |
| 5. explanations | WHY did each theme occur? (session history evidence) |
| 6. opsaudit | Did the agent follow the prescribed workflow? (operational discipline) |
| 7. todo | What concrete actions fix the gaps? (project + plugin + operational tracks) |
| 8. handover | What should happen next -- and in which repo? |

Phases 5 and 6 can run in parallel -- opsaudit reads JSONL files independently of the behavioral chain.

### Why not collapse phases?

Collapsing phases loses the causal chain. If you merge codegap and implgap into one "find all gaps" phase, you lose the distinction between "the code is wrong" and "the plan was wrong." That distinction is the entire point -- different root causes demand different fixes.

A gap that was never planned needs a planning improvement. A gap that was planned but built wrong needs a build-loop improvement. A gap the plugin should have caught needs a plugin improvement. You cannot assign the right fix without knowing which level failed.

### Why eight and not six?

The original six phases covered behavioral analysis (spec vs code) but missed two concerns:

- **Operational audit (phase 6):** The retro audited *what was built* but not *how it was built*. Skipped commits, unused scripts, wrong model routing, and missing handoff are process failures, not code failures. They need their own analysis dimension with its own chain (OPS -> TODO).
- **Handover (phase 8):** The retro produced findings but no actionable session-starter for the next person. TODO items need to be grouped into workstreams, split by repo (project vs plugin), and sequenced -- that's synthesis work that deserves its own phase.

---

## Behavioral Comparison, Not Line-by-Line Diffs

Phase 1 asks: "Does the implementation deliver the behavior the spec promised?" -- not "Does function X exist?" or "Do the line counts match?"

### Why behavioral?

- A spec might say "retry failed requests with exponential backoff." The implementation might achieve this through a middleware, a decorator, a library call, or inline code. All are valid. A diff-based approach would flag language-idiom differences that are not gaps.
- Behavioral comparison catches the gaps that matter: the spec says retry, the code does not retry. It ignores the gaps that do not matter: the spec says `retry()`, the code says `with_retries()`.
- This aligns with the port recipe's philosophy -- semantic equivalence, not syntactic equivalence.

### What "behavioral" means operationally

The gap-worker agent catalogs every named behavior in the spec, then classifies each as PRESENT, PARTIAL, or MISSING in the implementation. "Error handling is incomplete" is rejected as useless. "The `parse_config` function does not handle missing config files (CG-007, HIGH)" is accepted as actionable.

---

## Why Session History Comes After Synthesis

Phase 5 (explanation mining from session JSONL) runs after Phase 4 (synthesis), not before.

### The problem with early session analysis

If you scan raw session history without a hypothesis, you produce anecdotes: "the user corrected the agent here," "the agent skipped a step there." These are observations, not explanations. You cannot distinguish signal from noise without knowing what you are looking for.

### The synthesis-first approach

Phase 4 produces 3-7 themes that explain the gap pattern. Phase 5 then searches session history for evidence of those specific themes. The themes act as a lens: "EVR-003 says auth-related gaps were systematically missed. Let me find the session moments where auth was discussed, skipped, or misunderstood."

This turns anecdotes into evidence. Every session finding is anchored to a theme, which is anchored to specific gaps in the chain. The result is explanations, not observations.

---

## The Weaving Loom Concept

The retrospective recipe is Layer 3 in a four-layer architecture:

```
Layer 1: BUILD       /ralph build -- pick task, implement, test, commit, exit
Layer 2: OBSERVE     Session JSONL / iteration journal -- captured during build
Layer 3: ANALYZE     /ralph retro -- eight-phase gap + ops analysis (this recipe)
Layer 4: IMPROVE     Apply Track B/C TODO items to the plugin and workflow
```

### Layers connect through files on disk

Layer 1 produces code and plan updates. Layer 2 captures conversation logs. Layer 3 reads those artifacts and produces gap analysis documents. Layer 4 reads the TODO and modifies the plugin.

No layer passes context to the next layer in memory. Disk is state. Git is memory. Context is ephemeral. Each layer can be re-run independently because its inputs are files, not in-flight state.

### Why this matters

The loom architecture means each layer is independently debuggable and re-runnable. If Phase 4 produces bad synthesis, you re-run Phase 4 -- you do not need to re-run Phases 1-3. If the build loop had problems, the retro analyzes them post-hoc without needing to have been running during the build.

---

## Model Selection Rationale

### Sonnet for Atomic Workers (Phases 1-3, 5-6)

Gap-workers, session-historians, and ops-auditors perform structured comparison: read input A, read input B, classify the relationship. This is pattern matching with citation, not creative synthesis. Sonnet handles it with low variance (1.3-1.7x vs Haiku's 2.3-3.3x in empirical testing).

### Opus for Synthesis (Phases 4, 7-8)

Cross-document synthesis, prioritization, and handover grouping require genuine judgment. Phase 4 must find themes across three gap documents -- this is cross-cutting pattern recognition, not pairwise comparison. Phase 7 must prioritize and assign root causes across behavioral and operational findings. Phase 8 must group TODO items into coherent workstreams and produce self-contained handover documents. These tasks benefit from Opus's stronger reasoning.

### Why not Haiku for workers?

Cost is not the binding constraint. The retrospective runs once per project, not in a tight loop. Haiku's higher variance (2.3-3.3x) means more false positives and missed gaps in an audit workflow where accuracy matters. Sonnet's consistency is worth the premium for a run-once diagnostic tool.

### Why not Opus for everything?

Opus is slower and more expensive. Phases 1-3 spawn up to 50 parallel workers per phase. Running 50 Opus instances for structured comparison wastes capacity. Sonnet handles the atomic work; Opus handles the synthesis. Match the model to the task.

---

## Loop Architecture

### The Flat Loop Model

Every phase is a single-pass headless run: one `claude -p` call does its entire job and exits. There are no nested loops, no stop-hooks, no iteration within a phase.

```bash
claude -p --model sonnet < PROMPT_codegap.md       # Phase 1: runs once, exits
claude -p --model sonnet < PROMPT_implgap.md       # Phase 2: runs once, exits
claude -p --model sonnet < PROMPT_plugingap.md     # Phase 3: runs once, exits
claude -p --model opus   < PROMPT_synthesis.md     # Phase 4: runs once, exits
claude -p --model sonnet < PROMPT_explanations.md  # Phase 5: runs once, exits
claude -p --model sonnet < PROMPT_opsaudit.md      # Phase 6: runs once, exits (can parallel with 5)
claude -p --model opus   < PROMPT_todo.md          # Phase 7: runs once, exits
claude -p --model opus   < PROMPT_handover.md      # Phase 8: runs once, exits
```

The sophistication comes from the chain of phases, not from any individual phase being complex. Each phase reads its predecessor's output from disk, does its analysis, writes its output to disk, and exits.

### Disk-as-State Principle

All state lives on disk in the `retro/` directory. No state is passed between phases in memory. This means:

- Any phase can be re-run without re-running prior phases
- Phase outputs are human-readable markdown, not opaque intermediate formats
- The retro directory is a complete, self-contained audit artifact
- `git diff` shows exactly what changed between retro runs

### Subagent Parallelism Within Phases

A phase may internally spawn many subagents (up to 50 gap-workers in Phase 1). But these subagents are coordinated by the phase's orchestrating prompt, not by an external scheduler. The phase prompt reads inputs, fans out to workers, aggregates results, and writes the output file. From the outside, each phase is a single atomic operation.

---

## Comparison with Existing Methodology

### What Exists Today

The Ralph methodology (Huntley/ClaytonFarr) has four loop types:

1. Spec generation (extract behavioral specs from source)
2. Reverse-engineering (understand source architecture)
3. Planning (create implementation plan)
4. Building (implement tasks from the plan)

Quality enforcement is purely backpressure-based: tests must pass, builds must succeed. There is no formalized post-build review mechanism.

### What This Recipe Adds

The retrospective recipe is the **automated review layer** that fills the biggest gap in the ecosystem. It answers: "The build completed and tests pass, but did we actually deliver what the spec promised? And if not, why not?"

No existing tool or methodology in the Ralph ecosystem provides this. The retrospective is novel infrastructure, not a wrapper around existing capabilities.

### Design Principles Inherited from the Methodology

| Principle | Source | Application |
|-----------|--------|-------------|
| One task per loop | Huntley | Each phase is one task (single-pass, no nesting) |
| Context clearing between iterations | agentic-engineer | Each phase gets fresh context via `claude -p` |
| File-based state | Huntley, playbook | All documents are files; no context carries between phases |
| Backpressure as quality gate | Huntley | Each phase checks prerequisites before running |
| Architect failures out permanently | Huntley | Track B/C TODO items change the plugin and workflow, not just the project |
| The orchestration system is the product | agentic-engineer | The recipe is infrastructure, not a prompt |

---

## Key Design Decisions Summary

| Decision | Alternative Considered | Why This Way |
|----------|----------------------|--------------|
| 8 separate phases | Fewer merged phases | Preserves causal chain for root-cause attribution; adds operational and handover dimensions |
| Behavioral comparison | Line-by-line diff | Catches functional gaps, ignores idiom differences |
| Session history after synthesis | Session history first | Themes provide a lens; raw history without hypothesis produces noise |
| Stable IDs, not heading slugs | GitHub auto-slugs | Survives heading edits; assigned not derived |
| Sonnet workers, Opus synthesis | Single model for all | Match model capability to task complexity; cost-effective |
| Flat single-pass phases | Iterative phases with loops | Simplicity; sophistication from the chain, not from nesting |
| Disk-as-state | In-memory context passing | Re-runnable, debuggable, human-readable, git-trackable |
| Three tracks in TODO (project + plugin + operational) | Single improvement list | Separates "fix this project" from "fix the process" from "fix the workflow" |
