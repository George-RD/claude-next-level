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

After initialization, guide the user through the next steps printed by the script. Emphasize:

- **AGENTS.md is the heart of the loop** -- it tells Ralph how to validate work. Keep it brief (~60 lines) since it's loaded into context every iteration.
- **PROMPT_plan.md** needs `[project-specific goal]` replaced with their actual goal (or re-run init with `--goal`).
- **Write specs next** via `/ralph-wiggum:spec`, then plan with `/ralph-wiggum:plan`, then build with `/ralph-wiggum:build`.

If their source code is not in `src/`, mention `--src-dir <path>` or manual edits to the prompt files.
