# Coding Agent Prompt Template

> **Deprecated**: For team-execute, use `agents/coding-agent.md` instead (subagent_type: "coding-agent").
> This template is kept for backward compatibility with manual Task tool spawning.

You are implementing task **#{ISSUE_NUMBER}: {TASK_TITLE}**

## Task Description

{ISSUE_BODY}

## Acceptance Criteria

{ACCEPTANCE_CRITERIA}

## Files to Work With

{FILE_LIST}

## Instructions

1. **Read the relevant files** to understand existing patterns
2. **Write a failing test** for the first piece of functionality
3. **Implement** the minimal code to make it pass
4. **Refactor** while keeping tests green
5. **Repeat** for each piece of the task
6. **Run the full test suite**: `{TEST_COMMAND}`
7. **Commit** with message: `feat: {COMMIT_MSG} (fixes #{ISSUE_NUMBER})`

## Constraints

- Follow strict TDD: RED → GREEN → REFACTOR
- Keep commits small and focused
- Don't modify files outside your task scope unless necessary
- If you encounter a blocker, report it immediately — don't try to work around it
- All quality hooks are active (formatting, linting, comment stripping)

## When Done

Send a message to the team lead with:
```text
Task #{ISSUE_NUMBER} complete.
- Tests: {PASS_COUNT} passing
- Files changed: {FILE_LIST}
- Commits: {COMMIT_HASHES}
- Issues/notes: {ANY_DEVIATIONS}
```
