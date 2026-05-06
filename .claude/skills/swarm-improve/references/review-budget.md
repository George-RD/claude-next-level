# Review budget and loop policy

Use the minimum review machinery that can catch the likely failure mode.

## Scale budget

- Tiny: inline only, no subagents, targeted gate. Example: typo, one-line cleanup, docs-only tweak.
- Small: inline simplify or one external review, not both by default. Example: local refactor or small bug fix.
- Medium: targeted gates plus `request-code-review` in standard mode. Use 2-4 lightweight lenses when cheap models are available and the diff has several likely failure modes.
- Large, risky, process-sensitive, phase checkpoint, or pre-submit: simplify plus `request-code-review` in deep mode, which calls `deep-review` for independent synthesis.
- Critical, security, destructive, payment, data-loss, or external-commitment work: `deep-review` plus explicit user approval where required.

## Loop caps

- Run at most one simplify pass per implementation batch unless subsequent fixes are medium or large.
- If review feedback causes only tiny or small changes, rerun gates but skip simplify.
- If review feedback causes medium or large code changes, run simplify again on the new diff before final review or submit.
- Run at most one normal review pass and one feedback-fix pass by default.
- Re-review only for Critical/Major behavior-changing fixes, large follow-up diffs, or before external submit.
- After two review/fix cycles, stop and summarize remaining tradeoffs unless safety or correctness requires another pass.

## Arbitration

- Fix reviewer feedback only when it has concrete evidence, plausible project impact, and an in-scope remedy.
- Correctness and requirements beat style preference.
- Existing project conventions beat reviewer taste.
- If reviewers conflict and neither has evidence, choose no change.
