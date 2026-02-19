---
name: spec-implement
description: Implementation phase of spec workflow. Executes the approved plan using strict TDD — red, green, refactor.
user-invocable: true
model: sonnet
---

# Spec Implement Phase

Execute the approved plan using strict test-driven development.

## Process

1. **Read the plan**: Load from the spec file's `plan` path
2. **For each task in the plan**:
   a. **RED** — Write a failing test first
   b. Run the test — confirm it fails with the expected reason
   c. **GREEN** — Write the minimal implementation to make it pass
   d. Run the test — confirm it passes
   e. **REFACTOR** — Clean up while keeping tests green
   f. Run ALL tests — confirm no regressions
   g. Commit with a clear message referencing the spec and task number
3. **After all tasks**: Update spec status to `COMPLETE`

## Rules

- NEVER write implementation code before the failing test
- NEVER skip running tests between RED and GREEN
- Keep commits small — one task per commit
- If the plan has a bug, note it but follow it anyway. Flag for /spec-verify.
- If stuck on a task for more than 3 attempts, note the blocker and move on

## Using Subagents

For plans with independent tasks, consider using superpowers:subagent-driven-development:
- Fresh subagent per task (no context pollution)
- Spec reviewer + code quality reviewer after each task
- Faster iteration

## On Completion

Update spec JSON: `{"status": "COMPLETE"}`

If omega memory is available, store a milestone:
- Call `omega_store(implementation_summary, "milestone")` with a brief summary: what was built, key decisions made during implementation, any deviations from the plan.

Then invoke /next-level:spec-verify.
