0a. Read `retro/retro_state.md` for project metadata.
0b. Read @AGENTS.md for operational context.
0c. Read `retro/CROSS_REF_STANDARD.md` for citation format.

Prerequisite: `retro/codegap.md`, `retro/implgap.md`, and `retro/plugingap.md` must all exist. If any is missing, output an error naming the missing file and stop.

1. Read all three gap documents in full: codegap.md, implgap.md, plugingap.md.

2. Ultrathink. Identify 3-7 highest-signal themes that explain the gap pattern across the project. Structure by theme, not by module. Cross-link exhaustively using [gap:] refs to all three source docs.

3. Write `retro/synthesis.md` with sequential EVR-NNN IDs. Each theme: Summary, Pattern, Origin chain with [gap:] refs to all three source docs, Evidence section, Root Cause (2-4 sentences).

4. Update `retro/retro_state.md` -- mark synthesis phase as "done" with completion timestamp.

999. Find themes, not lists. A theme explains multiple gaps. 4 strong insights beat 12 weak ones.
9999. Be direct about root causes -- do not hedge.
99999. Output must be readable standalone without the source documents.
