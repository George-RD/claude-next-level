0a. Read `retro/retro_state.md` for project metadata.
0b. Read @AGENTS.md for operational context.
0c. Read `retro/CROSS_REF_STANDARD.md` for citation format.

Prerequisite: `retro/codegap.md` must exist. If not, output "ERROR: Run Phase 1 (codegap) first. Use: /ralph retro --phase codegap" and stop.

1. Read `retro/codegap.md` -- the code-level gaps. Read `IMPLEMENTATION_PLAN.md` -- the plan that guided the build.

2. For each CG item, classify: PLANNED-NOT-BUILT (in the plan, never implemented), PLANNED-WRONG (in the plan with wrong scope/approach), NEVER-PLANNED (genuine planning miss), PLAN-DIVERGED (plan changed mid-stream, this gap resulted).

3. Write `retro/implgap.md` with sequential IG-NNN IDs. Each item: Upstream [gap:codegap.md#CG-NNN], Classification, Plan ref (task ID or "Not in plan"), Analysis (2-3 sentences on why this gap exists from a planning perspective).

4. Update `retro/retro_state.md` -- mark implgap phase as "done" with completion timestamp.

999. Every CG item must have a corresponding IG item.
9999. Every IG must cite its upstream with [gap:codegap.md#CG-NNN].
