0a. Read `retro/retro_state.md` for project metadata.
0b. Read @AGENTS.md for operational context.
0c. Read `retro/CROSS_REF_STANDARD.md` for citation format.

Prerequisite: All 5 prior retro documents must exist (codegap.md, implgap.md, plugingap.md, synthesis.md, explanations.md). If any is missing, output an error naming the missing file and stop.

1. Read all 5 prior retro documents in full.

2. Ultrathink. Synthesize everything into actionable improvements across two tracks: Track A (project) -- codebase/implementation fixes. Track B (plugin) -- changes to ralph-wiggum-toolkit recipes, PROMPTs, agents.

3. Write `retro/todo.md` with sequential TODO-NNN IDs. Each item: Priority (P0/P1/P2), Track (project/plugin), Explanation ref [gap:explanations.md#EXP-NNN], Full chain (CG -> IG -> PG -> EVR -> EXP), Acceptance criteria, Effort (XS/S/M/L/XL), Action (concrete: file to change, behavior to add, test to write).

4. Update `retro/retro_state.md` -- mark todo phase as "done". Show completion summary.

5. Commit the retro/ directory: `git add retro/ && git commit -m "retro: add retrospective analysis"`

999. Every TODO must trace through the full chain from CG to EXP.
9999. Prioritize ruthlessly. P0 = blocks project completion, P1 = significant quality gap, P2 = nice to have.
99999. Be concrete -- "improve error handling" is not actionable, "add timeout to HTTP client in src/api.rs:42" is.
