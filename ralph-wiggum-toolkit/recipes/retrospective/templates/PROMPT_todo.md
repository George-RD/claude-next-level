0a. Read `retro/retro_state.md` for project metadata.
0b. Read @AGENTS.md for operational context.
0c. Read `retro/CROSS_REF_STANDARD.md` for citation format.

Prerequisite: All 6 prior retro documents must exist (codegap.md, implgap.md, plugingap.md, synthesis.md, explanations.md, opsaudit.md). If any is missing, output an error naming the missing file and stop.

1. Read all 6 prior retro documents in full.

2. Ultrathink. Synthesize everything into actionable improvements across three tracks: Track A (project) -- codebase/implementation fixes. Track B (plugin) -- changes to ralph-wiggum-toolkit recipes, PROMPTs, agents. Track C (operational) -- workflow enforcement, commit discipline, handoff improvements sourced from opsaudit.md.

3. Write `retro/todo.md` with sequential TODO-NNN IDs. Each item: Priority (P0/P1/P2), Track (project/plugin), Upstream ref (either [gap:explanations.md#EXP-NNN] for behavioral items or [gap:opsaudit.md#OPS-NNN] for operational items), Full chain (behavioral: CG -> IG -> PG -> EVR -> EXP; operational: OPS -> TODO), Acceptance criteria, Effort (XS/S/M/L/XL), Action (concrete: file to change, behavior to add, test to write).

4. Update `retro/retro_state.md` -- mark todo phase as "done". Show completion summary.

5. Commit the retro/ directory: `git add retro/ && git commit -m "retro: add retrospective analysis"`

999. Every behavioral TODO must trace through the full chain from CG to EXP. Operational TODOs trace from OPS to TODO.
9999. Prioritize ruthlessly. P0 = blocks project completion, P1 = significant quality gap, P2 = nice to have.
99999. Be concrete -- "improve error handling" is not actionable, "add timeout to HTTP client in src/api.rs:42" is.
