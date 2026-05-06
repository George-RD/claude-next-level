# Reviewer JSON schema

Use this shape when the coordinator needs a programmatic verdict.

```json
{
  "verdict": "pass" | "concerns" | "block",
  "blocking": [
    {"file": "path:line", "issue": "...", "why": "...", "fix": "..."}
  ],
  "important": [
    {"file": "path:line", "issue": "...", "why": "...", "fix": "..."}
  ],
  "minor": [
    {"file": "path:line", "note": "..."}
  ],
  "gates": {
    "fmt": "pass|fail|not-run",
    "build": "pass|fail|not-run",
    "lint": "pass|fail|not-run",
    "tests": "pass|fail|not-run",
    "docs": "pass|fail|not-run"
  },
  "process": "pass|concerns|block",
  "next_action": "submit" | "fix" | "continue" | "stop"
}
```

Verdict rule:

- `block`: any Critical or failing required gate
- `concerns`: no blocker, but Important findings or process concerns remain
- `pass`: no blocker and no required follow-up
