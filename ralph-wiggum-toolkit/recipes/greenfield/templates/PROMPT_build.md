# Task

Read @ralph/current-task.md for your assignment.
Read @AGENTS.md for build/test/lint commands and operational notes.

# Quality Failures

If @ralph/last-gate-result.json exists and shows failures, fix those FIRST
before continuing with the task.

# Rules

- Implement the task described in current-task.md. Nothing else.
- Implement completely. No stubs, no placeholders, no TODOs.
- Single sources of truth. No duplicate logic across files.
- Search the codebase before assuming something is missing.
- If you find spec inconsistencies, note them in IMPLEMENTATION_PLAN.md.
- Update @AGENTS.md if you learn something operational (build quirks, env setup).
- Do not run tests or linters. The loop infrastructure handles verification.
- Do not commit or push. The loop infrastructure handles VCS operations.
