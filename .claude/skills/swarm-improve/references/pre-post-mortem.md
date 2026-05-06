# Pre-Mortem and Post-Mortem Checkpoints

Use these checkpoints only for larger or riskier improvement waves.

## Pre-mortem before implementation

Ask reviewers to predict concrete failure modes before code changes:

- What hidden requirements or workflow constraints might be missed?
- Which files are likely to be touched accidentally?
- What tests or gates would catch the predicted failure?
- What is the cheapest rescue plan if the approach proves wrong?

## Post-mortem after submit or major checkpoint

Capture durable learning only when it is likely to affect future work:

- decision or bug pattern
- evidence that the pattern mattered
- where to apply it next time
- what should be retired or not repeated

For Jcode, prefer `mcp__automem__store_memory` for durable cross-session learnings and `todo` for near-term next work.
