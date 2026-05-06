---
name: deep-review
description: Heavy review mode normally invoked by request-code-review for risky checkpoints, pre-submit stacks, OpenSpec/cflx acceptance, security-sensitive work, or explicit deep review, audit, or red-team requests.
version: 0.1.0
author: George-RD
x-compatibility: jcode-primary, claude-code-adaptable, opencode-adaptable
---

# Deep Review

Use this skill as the heavy checkpoint review mode called by `request-code-review` when ordinary review is not enough and independent synthesis is required. Use it directly when the user explicitly asks for deep review, audit, red-team, or equivalent high-assurance review.

Core principle: independent perspectives first, coordinator synthesis second.

## Workflow

1. Gather review inputs: repo path, git range, requirements, active specs, gates run, and known risks.
2. If reviewing recent implementation and the prior implementation or feedback fix was medium or large, load or use `simplify` first unless already done. Skip repeat simplify after tiny or small feedback fixes.
3. Dispatch a constructive reviewer with `subagent` or `swarm spawn/assign_task` for maintainability, clarity, tests, architecture, and idioms.
4. Dispatch an adversarial reviewer, preferably minimax when model selection is available, for bugs, process violations, missing tests, semantic drift, and false completion.
5. Synthesize findings. Do not average them away. A single proven Critical blocks.
6. Fix or explicitly defer findings with evidence. Reviewer findings need concrete evidence, plausible impact, and an in-scope remedy before they drive code changes.
7. Re-run gates. Re-review only for Critical/Major behavior-changing fixes, large follow-up diffs, or before external submit.

## Context funnel

Read references only when needed:

- `references/constructive-review.md`: constructive reviewer prompt.
- `references/adversarial-review.md`: adversarial reviewer prompt.
- `references/synthesis-template.md`: final report format.
- `references/openspec-cflx-checklist.md`: phase/process boundaries.
- `references/graphite-checklist.md`: stacked PR workflow checks.
- `assets/council-packet.md`: shared packet template for multi-reviewer council runs.
- `scripts/validate.sh`: behavioral contract checks for this skill.

## Severity

- Critical: blocks submit or acceptance.
- Major: fix before proceeding unless explicitly waived with evidence.
- Minor: note or opportunistically fix.

## Loop policy

- Deep review is the deep mode of `request-code-review`; do not also run a separate ordinary review unless a specific unresolved concern remains.
- If feedback creates a medium or large diff, simplify that new diff before final submit.
- If feedback creates only tiny or small changes, rerun gates and skip repeat simplify.
- After two review/fix cycles, stop and summarize tradeoffs unless safety or correctness requires another pass.

Never let a clean constructive review override a concrete adversarial blocker.
