---
description: "Phase 3: Run build loop (implement from plan, test, commit)"
argument-hint: "[--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Ralph Wiggum: Build (Phase 3)

Set up the build loop:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh" --mode build $ARGUMENTS
```

You are now in BUILDING mode. Follow the prompt that was loaded.

**Each iteration, you should:**

1. **Orient** - Study `specs/*` to understand requirements
2. **Read plan** - Study `IMPLEMENTATION_PLAN.md` for the current state
3. **Select** - Pick the most important unfinished task
4. **Investigate** - Search the codebase before changing anything ("don't assume not implemented")
5. **Implement** - Use parallel subagents for file operations
6. **Validate** - Run tests (only 1 subagent for build/tests - this is backpressure)
7. **Update plan** - Mark task done, note discoveries or bugs
8. **Update AGENTS.md** - If you learned something operational (brief!)
9. **Commit** - `git add -A && git commit` with a descriptive message

**Guardrails (in order of importance):**
- Keep `AGENTS.md` operational only -- status/progress notes go in `IMPLEMENTATION_PLAN.md`
- Fix spec inconsistencies when found (Opus subagent with ultrathink)
- Clean completed items from `IMPLEMENTATION_PLAN.md` when it grows large
- Implement completely -- no placeholders or stubs
- Document and fix bugs even if unrelated to current task
- Capture the "why" in documentation and tests
- Single sources of truth -- no migrations/adapters
- Create git tags when there are no build/test errors

CRITICAL: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE.
