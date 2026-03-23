0a. Read `retro/retro_state.md` for project metadata and session_path.
0b. Read @AGENTS.md for operational context.
0c. Read `retro/CROSS_REF_STANDARD.md` for citation format.

Prerequisite: `retro/synthesis.md` and `retro/explanations.md` must exist. If either is missing, output "ERROR: Run prior phases first. Use: /ralph retro --from-phase synthesis" and stop.

1. Discover session JSONL files: read session_path from `retro/retro_state.md`, list the directory. Each `.jsonl` is a session. If no sessions found, write `retro/opsaudit.md` noting session unavailability and exit normally.

2. Read `ralph/state.json` (or `ralph/state.md`) from the project root to get phase transitions and completed tasks. If no ralph state exists, note it and proceed with session-only checks.

3. Spawn one ops-auditor subagent (Sonnet) per JSONL file. Each worker: reads the full JSONL and the ralph state, checks workflow compliance (ralph script invocations, quality gate execution), commit discipline (commit count vs completed tasks), model routing (model per message role), session efficiency (tokens, compactions, subagents, duration), and handoff quality (final message, state update, summary). Returns OPS-NNN markdown fragments.

3b. Aggregate results. Deduplicate cross-session findings. Assign final sequential OPS-NNN IDs.

4. Write `retro/opsaudit.md` with sequential OPS-NNN IDs. Each finding: Category (workflow-compliance | commit-discipline | model-routing | session-efficiency | handoff-quality), Severity (HIGH | MEDIUM | LOW | INFO), Evidence (session filename + timestamp + exact tool call or absence), Expected (what should have happened), Actual (what happened), Impact (consequence of the deviation).

5. Update `retro/retro_state.md` -- mark opsaudit phase as "done" with completion timestamp.

999. Every finding must cite specific session evidence (filename, timestamp, tool call or absence). No finding without evidence.
9999. Do not flag INFO-severity items as HIGH. Efficiency metrics are informational unless extreme (>3x expected tokens, >5 compactions).
99999. OPS-NNN IDs must be sequential, zero-padded three digits.
