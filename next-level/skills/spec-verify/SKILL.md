---
name: spec-verify
description: Verification phase of spec workflow. Validates implementation against plan — tests, coverage, code review, CodeRabbit.
user-invocable: true
---

# Spec Verify Phase

Validate that the implementation is correct, complete, and clean.

## Checks

Run these in order. Stop on first failure.

1. **Tests pass**: Run the full test suite. Show actual output, not just "tests pass".
2. **Plan coverage**: Check every task in the plan has corresponding code AND tests.
3. **Code review**: Dispatch the spec-reviewer agent with the plan and changed files.
4. **CodeRabbit review** (if available): Run `coderabbit review --plain` on changes since spec started. Feed findings into spec-reviewer context. If coderabbit is not installed, skip this step with an info message.
5. **Lint clean**: Run any configured linters if available (eslint, ruff, golangci-lint).
6. **No regressions**: Confirm pre-existing tests still pass.

## If All Checks Pass

Update spec JSON: `{"status": "VERIFIED"}`

If omega memory is available, store the verification result:
- Call `omega_store(verification_summary, "milestone")` with: spec name, all checks passed, key metrics (test count, files changed, lint status).

Report success to the user with a summary:
- Tasks completed
- Tests passing
- Files changed
- CodeRabbit findings (if any were addressed)
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
