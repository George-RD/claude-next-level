---
name: swarm-improve
description: Planner-led repo improvement loops with subagents, review gates, Mermaid DAGs, and workflow-aware commits. Use for improve, refactor, audit, or continue-loop requests.
version: 0.1.0
author: George-RD
x-compatibility: jcode-primary, claude-code-adaptable, opencode-adaptable
---

# Swarm Improve

Use this skill for repo improvement loops that benefit from subagents and review gates.

Core principle: small ranked tasks, independent workers, explicit evidence, review before submit, stop at diminishing returns. This is Jcode's lightweight first-class RPI-style loop: plan, implement, validate, review, learn, and continue only while value remains clear.

## Default loop

1. Inspect repo state: working tree, branch workflow, docs, tests, active specs, and recent commits.
2. Write or refresh a ranked `todo` list with 3-7 high-leverage safe improvements.
3. Choose a review budget from `references/review-budget.md` before dispatching work.
4. If 3+ tasks have non-obvious dependencies, put a small Mermaid DAG in the visible progress update or swarm shared context.
5. Dispatch implementer subagents with `subagent` for bounded tasks, or `swarm spawn/assign_task` only for persistent multi-agent coordination.
6. Before parallel workers, map intended files to owners, order dependencies, cap at 4 workers per wave by default, and serialize overlapping file claims.
7. Choose and run validation gates by change type after each meaningful diff or wave. When behavior, UI/UX, CLI/TUI, docs/config, or refactor risk is in scope, use `references/change-type-validation.md` to confirm the gate.
8. Use `simplify` based on change scale: inline/skip for tiny fixes, normal pass after medium or large implementation, repeat only if review feedback causes medium or large code changes.
9. Use `request-code-review` as the main review entrypoint. Use quick/standard/deep mode based on risk; deep mode calls `deep-review` for milestone, risky, process-sensitive, high-impact, or pre-submit diffs.
10. If simplify, review, or gates fail, loop back within the caps in `references/review-budget.md`. If clean, commit with the repo's native workflow.
11. At checkpoints, use `references/development-checkpoints.md`: review the plan before code when scope is non-obvious, refactor/extend tests, create follow-ups for valid out-of-scope findings, capture durable learnings when high-value, and rerun broader validation before the next wave.
12. Reassess. Continue only while remaining work is clearly worth the churn.

## Context funnel

Keep this skill light. Read references only when needed:

- `references/planner-led-loop.md`: task DAGs, waves, claims, checkpoints, and dead-letter handling.
- `references/review-budget.md`: task-size budgets, scale-based simplify repeats, loop caps, and reviewer arbitration.
- `references/development-checkpoints.md`: planning review, milestone simplify/review, and out-of-scope follow-up rules.
- `references/change-type-validation.md`: route backend, UI/UX, CLI/TUI, docs/config, and refactor work to appropriate validation gates.
- `references/model-routing.md`: choose kimi, minimax, Claude, or inline work when dispatching non-trivial subagents or adversarial review.
- `references/mermaid-patterns.md`: compact workflow diagrams for plans, simplify, reviews, loopbacks, and checkpoints.
- `references/repo-workflow-adapters.md`: Graphite, OpenSpec/cflx, and generic repo workflow checks.
- `references/subagent-prompt-template.md`: implementer prompt template with gates and reporting.
- `references/evidence-packets.md`: compact shared context packets for workers and reviewers.
- `references/pre-post-mortem.md`: lightweight risk prediction and learning checkpoints.
- `assets/swarm-improve-loop.mmd`: default end-to-end loop diagram.
- `scripts/validate.sh`: behavioral contract checks for this skill.
- `assets/checkpoint-wave.mmd`: checkpoint and continue diagram.

## Hard safety rules

- Do not do destructive or irreversible work without explicit approval.
- Do not manually implement phase-owned feature work when a project uses OpenSpec/cflx. Inspect active changes first.
- Do not use raw git commands that bypass the repo workflow if a tool such as Graphite or jj is configured.
- Do not dispatch subagents for tiny edits where briefing and review cost exceeds the work, unless the user asks for aggressive dispatch.
- Do not run both ordinary review and deep review on the same diff unless `request-code-review` escalates to deep mode for a specific concern.
- Every claim of completion needs evidence: tests, lint, build, measurements, reviewer verdicts, or a clear reason why validation is not applicable.
