---
name: context-status
description: Show current context usage, active spec status, project progress, omega memory state, and continuation info at a glance.
user-invocable: true
---

# Context Status

Display the current session state with project-level info.

## What to Show

1. **Context estimate**: Read `~/.next-level/sessions/*/context_state` for the current session
2. **Active specs**: List all non-VERIFIED specs from `~/.next-level/specs/*.json`
3. **Continuations**: Check for any `continuation.md` files from previous sessions
4. **Omega memory**: If omega is available, call `omega_query()` with the current project name to show recent decisions/milestones
5. **GitHub issues**: If in a project with milestones, show `gh issue list --milestone <current-epic> --state all` for progress

## Output Format

```
NEXT-LEVEL STATUS
=====================
Context:      67% ██████████████░░░░░░ (OK)
Active spec:  "add-user-auth" — IMPLEMENTING (step 3/7)
Continuation: None pending

PROJECT PROGRESS (if available)
=====================
Epic: "Quality Layer"
  Issues: 5/8 closed
  Current: #23 Python checker (in-progress)
  Blocked: None

RECENT DECISIONS (omega, if available)
=====================
- Chose ruff over black for Python formatting (2 days ago)
- TypeScript checker uses project-local eslint first (3 days ago)

RECENT SESSIONS
=====================
abc123: 45% (completed normally)
def456: 92% (handed off — continuation.md exists)
```

## If Continuation Exists

Display the continuation.md contents and ask:
> "A previous session left handoff notes. Resume this work?"

If yes, read the notes and continue from where the previous session stopped.
If no, acknowledge and start fresh.

## If No State Exists

```
NEXT-LEVEL STATUS
=====================
No active specs or sessions.
Start with: /next-level:spec "your task description"
```
