---
name: spec-verify
description: Verification phase of spec workflow. Validates implementation against plan — tests, coverage, code review.
user-invocable: true
---

# Spec Verify Phase

Validate that the implementation is correct, complete, and clean.

## Checks

Run these in order. Stop on first failure.

1. **Tests pass**: Run the full test suite. Show actual output, not just "tests pass".
2. **Plan coverage**: Check every task in the plan has corresponding code AND tests.
3. **Code review**: Dispatch the spec-reviewer agent with the plan and changed files.
4. **Lint clean**: Run any configured linters if available (eslint, ruff, golangci-lint).
5. **No regressions**: Confirm pre-existing tests still pass.

## If All Checks Pass

Update spec JSON: `{"status": "VERIFIED"}`
Report success to the user with a summary:
- Tasks completed
- Tests passing
- Files changed
- Ready for PR/merge

## If Any Check Fails

Update spec JSON:
```json
{
  "status": "FAILED",
  "feedback": ["specific issue 1", "specific issue 2"]
}
```

Report the specific failures and route back to /next-level:spec-implement with the feedback. The implement phase will address the issues and re-verify.

## Verification Loop

The spec-verify → spec-implement → spec-verify loop continues until all checks pass or the user manually intervenes. Maximum 3 loops before asking the user for guidance.
