---
description: "Cancel active Ralph Wiggum loop"
allowed-tools: ["Bash(test -f .claude/ralph-wiggum.local.md:*)", "Bash(rm .claude/ralph-wiggum.local.md)", "Read(.claude/ralph-wiggum.local.md)"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph Wiggum Loop

1. Check if `.claude/ralph-wiggum.local.md` exists: `test -f .claude/ralph-wiggum.local.md && echo "EXISTS" || echo "NOT_FOUND"`

2. **If NOT_FOUND**: Say "No active Ralph Wiggum loop found."

3. **If EXISTS**:
   - Read `.claude/ralph-wiggum.local.md` to get the mode and iteration
   - Remove the file: `rm .claude/ralph-wiggum.local.md`
   - Report: "Cancelled Ralph Wiggum [MODE] loop at iteration N"
