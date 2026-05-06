# Workflow Skill Governance

Workflow skills are operational code. Changes to `swarm-improve`, `simplify`, `request-code-review`, `deep-review`, `apply-review-feedback`, `workflow-closeout`, or their shared validators require:

1. Static validation: run each touched skill's `scripts/validate.sh`.
2. Behavioral eval: run `.workflow-evals/scripts/eval-workflow-skills.py` from the skills root.
3. Evidence and maturity validation: run `.workflow-evals/scripts/validate-evidence.py`.
4. Adversarial review: request independent review from both GPT 5.5 and Opus 4.7 when available. If unavailable, record an `UNAVAILABLE` review entry in the evidence packet and use the strongest available fallback.
5. Evidence packet: record changed files, eval output, reviewer verdicts, accepted/rejected findings, and any follow-up tasks.

Do not treat static validation as sufficient. It only proves structure, not workflow behavior.

## Session monitoring and learning loop

At the end of any substantial skill-guided workflow, ask:

- Did the workflow choose the wrong entrypoint or model route?
- Did it over-review, under-review, or loop too long?
- Did review feedback cause scope creep instead of follow-up creation?
- Did a planning issue surface only after code was written?
- Did a gate/review failure reveal a missing eval case?

If yes, record a workflow learning in memory and append a JSONL item to `~/.jcode/skill-state/workflow-learnings.jsonl` when editing the local skill suite is appropriate. `validate-evidence.py` is the canonical runtime-telemetry validator. New learnings should become either:

- a behavioral eval case,
- a skill doc clarification,
- a validator rule,
- or a rejected/deferred idea with rationale.

Any skill update produced from a learning must go through the five required checks above.

## Deterministic metrics

Keep metrics simple and auditable. Track them in `.workflow-evals/maturity.json` and evidence packets:

- success_count: completed workflows where the skill helped without material friction
- miss_count: evidenced issue the workflow should have caught
- friction_count: workflow was skipped, misunderstood, or too heavy
- regression_count: skill change made a previous scenario worse
- last_changed and state: draft, recent, stable, high-success, needs-repair

These metrics are not automatic truth. They are decision support for evidence thresholds: stable/high-success skills require stronger repeated evidence before edits; draft/recent/needs-repair skills can change with lower evidence but still require eval and review.
