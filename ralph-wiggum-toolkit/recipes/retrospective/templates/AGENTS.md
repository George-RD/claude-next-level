# AGENTS -- Retrospective Audit

## Project

- **Name:** {PROJECT_NAME}
- **Source recipe:** {SOURCE_RECIPE}
- **Spec root:** {SPEC_ROOT}
- **Implementation root:** {IMPL_ROOT}
- **Source language:** {SOURCE_LANG}
- **Target language:** {TARGET_LANG}

## Cross-Reference Standard

All gap items use stable IDs: CG-NNN, IG-NNN, PG-NNN, EVR-NNN, EXP-NNN, TODO-NNN.

Cite upstream items with `[gap:filename.md#ID]` syntax. Chain refs use `->` arrows.

Full specification: retro/CROSS_REF_STANDARD.md

## Quality Standards

- **Behavioral comparison.** "Does the implementation deliver the behavior the spec promised?" -- not "Does function X exist?"
- **Actionable findings.** "Error handling is incomplete" is useless. "parse_config does not handle missing files (CG-007, HIGH)" is actionable.
- **Exhaustive coverage.** Check every behavior in every spec. Do not skip because it "looks fine."
- **No false positives on idiom.** Do not flag semantic/idiomatic differences unless they cause functional gaps.

## Operational Notes

{Add learnings here as the retrospective progresses -- unexpected file layouts, parsing issues, etc.}
