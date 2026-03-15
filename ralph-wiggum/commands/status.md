---
description: "Show Ralph Wiggum project state"
allowed-tools: ["Read(AGENTS.md)", "Read(IMPLEMENTATION_PLAN.md)", "Read(.claude/ralph-wiggum.local.md)", "Bash(test -d specs && ls specs/ || echo NO_SPECS)", "Bash(ls PROMPT_*.md 2>/dev/null || true)", "Bash(test -f loop.sh && echo LOOP_SH_EXISTS || echo LOOP_SH_MISSING)", "Bash(git tag -l)", "Bash(git log --oneline -5)"]
---

# Ralph Wiggum: Status

Check and report the current state of the Ralph Wiggum project:

1. **Project structure** - Check which Ralph files exist:
   - `specs/` - List spec files
   - `AGENTS.md` - Exists? How many lines?
   - `IMPLEMENTATION_PLAN.md` - Exists? Summary of open items?
   - `PROMPT_plan.md` / `PROMPT_build.md` - Exist?
   - `loop.sh` - Exists?

2. **Active loop** - Check `.claude/ralph-wiggum.local.md`:
   - If exists: show mode, iteration, max_iterations, completion_promise
   - If not: report "No active loop"

3. **Git state** - Show recent commits and tags

4. **Recommendations** - Based on what exists:
   - No specs? → "Write specs first: /ralph-wiggum:spec"
   - Specs but no plan? → "Run planning: /ralph-wiggum:plan"
   - Plan exists? → "Ready to build: /ralph-wiggum:build"
   - AGENTS.md empty? → "Fill in your build/test/lint commands"
