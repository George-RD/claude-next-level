---
name: context-status
description: Show current context usage, active spec status, and continuation state at a glance.
user-invocable: true
---

# Context Status

Display the current session state.

## What to Show

1. **Context estimate**: Read `~/.next-level/sessions/*/context-pct.json` for the current session
2. **Active specs**: List all non-VERIFIED specs from `~/.next-level/specs/*.json`
3. **Continuations**: Check for any `continuation.md` files from previous sessions

## Output Format

```
NEXT-LEVEL STATUS
─────────────────
Context:      67% ██████████████░░░░░░ (OK)
Active spec:  "add-user-auth" — IMPLEMENTING (step 3/7)
Continuation: None pending

RECENT SESSIONS
─────────────────
abc123: 45% (completed normally)
def456: 92% (handed off → continuation.md exists)
```

## If Continuation Exists

Display the continuation.md contents and ask:
> "A previous session left handoff notes. Resume this work?"

If yes, read the notes and continue from where the previous session stopped.
If no, acknowledge and start fresh.

## If No State Exists

```
NEXT-LEVEL STATUS
─────────────────
No active specs or sessions.
Start with: /next-level:spec "your task description"
```
