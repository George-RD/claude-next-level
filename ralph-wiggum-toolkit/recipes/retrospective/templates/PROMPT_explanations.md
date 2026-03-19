0a. Read `retro/retro_state.md` for project metadata and session_path.
0b. Read @AGENTS.md for operational context.
0c. Read `retro/CROSS_REF_STANDARD.md` for citation format.

Prerequisite: `retro/synthesis.md` must exist. If not, output "ERROR: Run Phase 4 (synthesis) first. Use: /ralph retro --phase synthesis" and stop.

1. Read `retro/synthesis.md` -- the themes to explain.

2. Discover session JSONL files: read `retro/retro_state.md` for session_path, list the directory. Each `.jsonl` is a session. If no sessions found, write the output file noting session unavailability and exit normally so Phase 6 can proceed.

3. Spawn one session-historian subagent (Sonnet) per JSONL file. Each worker: reads the full JSONL, filters for user text and assistant text, scans for gap signals (corrections, ignored instructions, incomplete claims, skipped steps), matches signals to EVR themes, returns EXP-NNN fragments.

3b. Aggregate results. Use Opus-level reasoning to synthesize worker findings into the final output.

4. Write `retro/explanations.md` with sequential EXP-NNN IDs. Each item: Gap ref [gap:synthesis.md#EVR-NNN], Origin chain, Session evidence (filename, timestamp), Root cause category (context-loss | misunderstanding | tool-limitation | scope-creep | oversight), User said (exact quote), Agent did (summary), Explanation (2-3 sentences).

5. Update `retro/retro_state.md` -- mark explanations phase as "done" with completion timestamp.
