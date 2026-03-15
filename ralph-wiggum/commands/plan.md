---
description: "Phase 2: Run planning loop (gap analysis, create implementation plan)"
argument-hint: "[--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Ralph Wiggum: Plan (Phase 2)

Set up the planning loop:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh" --mode plan $ARGUMENTS
```

You are now in PLANNING mode. Follow the prompt that was loaded.

Your job is to perform gap analysis between `specs/*` and existing source code, then create or update `IMPLEMENTATION_PLAN.md` with a prioritized bullet-point list of tasks.

**Rules:**
- **Plan only. Do NOT implement anything.**
- **Don't assume functionality is missing** -- confirm with code search first.
- Use parallel subagents to study specs and source code simultaneously.
- Use an Opus-level subagent for analysis, prioritization, and writing the plan.
- Search for TODOs, minimal implementations, placeholders, skipped/flaky tests, inconsistent patterns.

**When done:** The stop hook feeds the same prompt back for another iteration. Planning usually completes in 1-2 iterations. When the plan looks solid, output `<promise>PLAN COMPLETE</promise>` if a completion promise was set, or the loop continues until max iterations.

CRITICAL: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE.
