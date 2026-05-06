# Multi-review fanout

Use for important diffs, pre-submit stacks, or changes where one reviewer lens is not enough.

## Reviewer roles

- Correctness reviewer: behavior, edge cases, error paths, data integrity.
- Maintainability reviewer: architecture, naming, seams, duplication, conventions.
- Test coverage reviewer: missing tests, weak assertions, fixtures, gate gaps.
- Adversarial/process reviewer: workflow violations, spec ownership, hidden scope creep, false completion.

Run reviewers in parallel when possible. Give all reviewers the same git range, requirements, and gates already run. Ask each reviewer to stay within its lens and return structured findings.

## Synthesis

A coordinator deduplicates findings and decides:

- BLOCK: any proven Critical or failed required gate.
- FIX: Important findings worth fixing before proceed.
- PASS: no blocking or required follow-up.

If review fails, fix issues and loop back through gates and review. Do not commit a failed review unless the user explicitly waives it.
