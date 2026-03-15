---
description: "Cancel active Ralph Wiggum loop"
allowed-tools: ["Bash(test -f .claude/ralph-wiggum.local.md:*)", "Bash(rm -f .claude/ralph-wiggum.local.md)", "Read(.claude/ralph-wiggum.local.md)"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph Wiggum Loop

Check if `.claude/ralph-wiggum.local.md` exists.

- **If missing**: Report "No active Ralph Wiggum loop found."
- **If present**: Read it to get the mode and iteration, remove it, then report "Cancelled Ralph Wiggum [MODE] loop at iteration N."
