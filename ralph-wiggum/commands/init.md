---
description: "Initialize project for Ralph Wiggum spec-driven development"
argument-hint: "[--src-dir <path>] [--goal <text>]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/init-project.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Ralph Wiggum: Init

Execute the init script to set up the project structure:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/init-project.sh" $ARGUMENTS
```

After initialization, help the user with next steps:

1. **Edit AGENTS.md** - Add their project's build, test, typecheck, and lint commands. This is the "heart of the loop" - it tells Ralph how to validate work. Keep it brief (~60 lines). It's loaded into context every iteration, so bloat degrades performance.

2. **Update PROMPT_plan.md** - Replace `[project-specific goal]` with their actual project goal.

3. **Write specs** - Suggest running `/ralph-wiggum:spec` to define requirements through JTBD analysis.

4. **Explain the workflow**:
   - Phase 1: Define requirements → `specs/*.md`
   - Phase 2: Plan → `IMPLEMENTATION_PLAN.md`
   - Phase 3: Build → implement, test, commit

If the user's source code is not in `src/`, mention they can re-run with `--src-dir <path>` or manually edit the prompt files.
