# Development checkpoints and follow-ups

Use checkpoints to keep long implementation runs from compounding planning mistakes.

## Before code

For OpenSpec/cflx or large project work, review the plan before implementation. The plan should name:

- target change ids or phases
- task boundaries and non-goals
- dependency order
- validation gates and e2e/smoke coverage
- what counts as follow-up rather than current scope

Planning fixes are cheaper than code fixes. Use `request-code-review` in plan mode when scope or sequencing is non-obvious.

## During implementation

Checkpoint after each phase, stacked PR, large subagent wave, repeated gate failure, or review BLOCK/Critical.

At a checkpoint:

1. Run gates appropriate to the phase.
2. Run simplify only if the cumulative diff or latest fixes are medium/large.
3. Run `request-code-review`; use deep mode for milestone, risky, or disputed changes.
4. Create follow-up tasks for valid but out-of-scope findings.
5. Reassess whether the next phase is still correctly planned.

## Follow-up policy

Do not expand the current PR/task for every valid finding. Create a separate follow-up when the finding is:

- real and evidenced, but outside current acceptance criteria
- valuable but not required for correctness of this PR
- risky enough to deserve its own design/review
- broad cleanup, refactor, docs expansion, or future-phase work

A follow-up needs: title, evidence or file refs, why it matters, suggested acceptance criteria, priority, and source review/checkpoint. Use repo-native issues when available; otherwise use `todo` for session-local tracking and mention it in the checkpoint report.
