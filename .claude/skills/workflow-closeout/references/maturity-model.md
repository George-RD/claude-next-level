# Skill maturity model

Use maturity to decide how much evidence is needed before changing a skill.

## States

- Draft: new or unproven. One credible finding can justify a small edit.
- Recent: changed recently. One high-confidence finding or eval failure can justify a fix.
- Stable: has worked across several workflows. Require repeated findings, high severity, or eval failure.
- High-success: repeatedly successful and low-friction. Require strong repeated evidence and regression-safe replacement.
- Needs-repair: recent regressions or repeated friction. Prefer simplification, rollback, or clarification before adding new process.

## Intervention preference

1. no-op and log
2. remove obsolete/confusing step
3. trim redundant step
4. clarify wording
5. edit diagram/decision branch
6. add deterministic eval
7. update existing reference or reviewer lens
8. add script/helper
9. create new persona

New personas require repeated evidenced misses, clear detection scope, and evidence that existing lenses cannot cover the gap.
