# Model routing

Use cheaper capable models aggressively for bounded tasks. Use stronger coordinator judgment for ambiguity.

## Defaults

- kimi: implementer subagents, ordinary code review, docs sweeps, mechanical refactors, test scaffolding.
- minimax: adversarial review, process review, "what did we miss?", risky diff critique.
- Claude/coordinator: task selection, final synthesis, policy decisions, ambiguous architecture, user-facing tradeoffs.
- Inline coordinator: 1-5 line edits, obvious fixes, urgent gate repairs, or when subagent briefing is larger than the task.

## Good subagent task shape

Dispatch when the task is:

- briefable in 1-3 paragraphs
- locally scoped by files or subsystem
- reversible with one restore/revert
- verifiable by deterministic gates
- not a product/policy decision

## Bad subagent task shape

Keep coordinator-owned when the task is:

- deciding scope or architecture
- reconciling conflicting specs or user preferences
- touching credentials, payments, destructive operations, or privacy-sensitive data
- phase-owned work that needs orchestration through a project process
- too small to justify prompt and review overhead
