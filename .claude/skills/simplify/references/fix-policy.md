# Simplify fix policy

Apply fixes when they are:

- local and reversible
- behavior-preserving
- covered by existing tests or easy to validate
- clearly reduce duplication, complexity, or wasted work

Skip or defer when they are:

- speculative
- feature expansion
- broad architecture changes
- performance work without evidence
- likely to conflict with active phase/spec ownership

If a finding is valid but too large, create a follow-up task instead of folding it into simplify.

## Repeat policy

- Tiny or small feedback fixes: rerun gates, skip another simplify pass.
- Medium or large feedback fixes: run one more simplify pass on the new diff.
- Repeated churn or performance-sensitive code can justify all three lenses again.
- After two simplify/fix cycles, stop and summarize tradeoffs unless correctness or safety requires another pass.
