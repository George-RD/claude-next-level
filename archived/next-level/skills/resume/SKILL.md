---
name: resume
description: Resume execution from a previous session — reads checkpoint state and continues where the last session left off.
user-invocable: true
---

# Session Resume

Resume work from a previous session's checkpoint.

## Process

1. **Find resume state**: Check for resume files in this order:
   a. Omega memory: call `omega_resume_task()` if available
   b. Local resume file: `~/.next-level/sessions/*/resume.md` (most recent)
   c. Continuation file: `~/.next-level/sessions/*/continuation.md` (most recent)

2. **Load context**: Read the resume/continuation file. It contains:
   - Project name and epic being executed
   - Completed tasks (with issue numbers)
   - Current task (in progress or next up)
   - Key decisions made in the previous session
   - Context percentage when checkpointed

3. **Verify state**: Before resuming:
   - Check that completed tasks are actually closed on GitHub: `gh issue list --state closed --json number | jq -r '[.[].number]'` and verify the issue numbers from the resume file appear in the output
   - Run the test suite to confirm previous work is intact
   - Check for any code changes made outside this workflow (manual edits, other sessions)

4. **Resume execution**:
   - If mid-task: continue from where the task left off
   - If between tasks: start the next task in the execution plan
   - Use `/next-level:execute` to continue the epic from the right point

5. **Clean up**: Delete the resume/continuation file only after the resumed task completes successfully (not immediately on resume — keep as fallback if the resumed task fails)

## Resume File Format

The resume file (`resume.md`) is written by `/next-level:execute` when context runs low:

```markdown
# Resume: <project-name> / <epic-name>

## Completed Tasks
- #12: Setup configuration system ✓
- #13: Dependency detection engine ✓
- #14: Setup skill ✓

## Current Task
- #15: Doctor skill — IN PROGRESS (step 2/4: "Check 2: Dependencies")

## Next Tasks
- #16: SessionStart hook
- #17: File checker dispatcher

## Key Decisions
- Chose ruff over black for Python (faster, single tool)
- Using jq for JSON parsing in bash hooks

## Context When Saved
- 87% at checkpoint
- Session: abc123
```

## If No Resume State Found

```text
No resume state found. Nothing to resume.

Options:
- /next-level:spec "task" — start a new spec
- /next-level:project "description" — plan a new project
- /next-level:context-status — check session state
```

## If State is Stale

If the resume file is older than 24 hours, or if significant code changes have been made since:
- Warn the user that the state may be outdated
- Suggest running tests first to verify
- Offer to start fresh or continue cautiously
