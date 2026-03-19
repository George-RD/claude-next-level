0a. Read `retro/retro_state.md` for project metadata and source recipe.
0b. Read @AGENTS.md for operational context.
0c. Read `retro/CROSS_REF_STANDARD.md` for citation format.

Prerequisite: `retro/implgap.md` must exist. If not, output "ERROR: Run Phase 2 (implgap) first. Use: /ralph retro --phase implgap" and stop.

1. Read `retro/implgap.md` (retro_state.md already loaded in 0a has the source recipe).

2. For each IG item, assess which recipe phase should have caught it: spec-writing (spec extraction missed this behavior), planning (planning phase should have included this task), building (build loop should have implemented this), audit (parity checker should have flagged this), none (outside plugin scope).

3. Write `retro/plugingap.md` with sequential PG-NNN IDs. Each item: Upstream [gap:implgap.md#IG-NNN], Codegap origin [gap:codegap.md#CG-NNN], Plugin phase, What should have happened, What actually happened, Improvement opportunity.

4. Update `retro/retro_state.md` -- mark plugingap phase as "done" with completion timestamp.

999. Every IG item must have a corresponding PG item.
9999. Every PG must cite both its upstream IG and origin CG.
