---
name: simplify
description: Post-implementation cleanup for recent changes using parallel reuse, quality, and efficiency reviewers. Use after building a feature or fix, before commit, PR, or submit.
version: 0.1.0
author: George-RD
x-compatibility: jcode-primary, claude-code-adaptable, opencode-adaptable
---

# Simplify

Use this skill after implementation and tests, before commit or submit.

Simplify is cleanup/pre-review hardening, not a substitute for correctness, security, acceptance, or submit review.

Core principle: tighten recent changes without expanding scope. Find duplication, code quality issues, and efficiency problems, then apply only high-signal fixes. Repeat simplify only when the latest fix cycle made medium or large changes.

## Default loop

1. Detect scope from recent changes: `git diff`, `git diff --staged`, or the commit range the user gives.
2. Classify the latest diff scale:
   - tiny/small: inline pass only, no reviewer fanout unless requested
   - medium: one targeted lens most likely to catch the risk
   - large, performance-sensitive, or repeated churn: three parallel lenses
3. Run baseline gates relevant to the repo when feasible.
4. Review with the selected budget:
   - reuse lens: duplication, missed helpers, redundant patterns
   - quality lens: clarity, naming, control flow, conventions, over-engineering
   - efficiency lens: allocations, repeated work, N+1 patterns, unnecessary I/O, obvious performance traps
5. Aggregate findings and discard false positives or churny suggestions.
6. Apply accepted fixes in the smallest safe patch.
7. Rerun gates.
8. If fixes were tiny or small, do not run simplify again. If fixes were medium or large, one more simplify pass is allowed before final review or submit.

## Context funnel

Read references only when needed:

- `references/reviewer-prompts.md`: prompts for reuse, quality, and efficiency lenses when external reviewers are justified by scale.
- `references/fix-policy.md`: which simplify findings to apply or skip.
- `assets/simplify-loop.mmd`: Mermaid loop diagram template.
- `scripts/validate.sh`: behavioral contract checks for this skill.

## Rules

- Review recent changes, not the whole codebase, unless asked.
- Do not add new features or broaden behavior.
- Prefer removing code, reusing existing helpers, and simplifying branches.
- Skip speculative performance work without evidence.
- Do not commit until gates pass and the diff is reviewed.
- Do not repeat simplify after minimal review-feedback fixes. Repeat only when the new diff is medium or large.
