---
name: workflow-closeout
description: End-of-workflow learning loop for skill-guided work. Use at session/checkpoint closeout to classify GitHub/CodeRabbit/human/CI findings, log missed-review patterns, and propose skill improvements only when evidence justifies them.
version: 0.1.0
author: George-RD
x-compatibility: jcode-primary, claude-code-adaptable, opencode-adaptable
---

# Workflow Closeout

Use this skill only at the end of a substantial skill-guided workflow, PR, cflx phase, or review cycle. Do not run it for routine tiny/small tasks with no meaningful workflow signals; still run it when CI, GitHub/CodeRabbit/human review, missed-use, repeated friction, PR/review-cycle, cflx phase, or skill-change evidence exists.

Core principle: log broadly, change narrowly, validate deterministically, and prefer simplification over added process.

## Default loop

1. Collect signals: CI, GitHub/CodeRabbit/human review, self-review, gate failures, follow-ups, and user friction.
2. Classify each signal: real miss, false positive, preference, unclear instruction, process friction, repeated pattern, or regression.
3. Decide the smallest intervention:
   1. no skill change, just log the signal
   2. delete, trim, or clarify an existing step
   3. edit a Mermaid decision diagram
   4. add or update a deterministic eval
   5. update an existing reviewer lens/persona
   6. add a helper script/reference
   7. create a new targeted persona only after repeated evidenced misses
4. Apply maturity thresholds: stable high-success skills need stronger evidence than draft or recently changed skills.
5. Log usage or missed-use events when they are relevant to cross-repo learning.
6. Before changing workflow skills, run static validation, behavioral evals, evidence/maturity validation, and adversarial review from GPT 5.5 plus Opus 4.7 when available.
7. Record outcome: accepted, rejected, deferred, follow-up, or eval-added.

## Context funnel

Read references only when needed:

- `references/learning-loop.md`: signal taxonomy, logging, and promotion flow.
- `references/maturity-model.md`: evidence thresholds for draft, recent, stable, high-success, and needs-repair skills.
- `references/storage-and-usage.md`: global versus project-local storage, eval run summaries, usage events, missed-skill analysis, and candidate-skill signals.
- `assets/closeout-loop.mmd`: compact Mermaid closeout flow.
- `scripts/append-learning.py`: append a validated workflow learning JSONL record.
- `scripts/log-usage.py`: append a cross-repo skill usage, missed-use, or candidate event.
- `scripts/validate.sh`: behavioral contract checks for this skill.

## Rules

- Do not add process for one-off preferences or false positives.
- Do not create a new reviewer persona unless repeated evidenced misses cannot fit an existing lens.
- Prefer removal, consolidation, clarification, or diagram edits before adding references or steps.
- Treat external review findings as learning signals, not automatic skill changes.
- Do not force every activity into a skill. Prefer skills for repeated, non-obvious, high-value, or safety-critical workflows.
- Any skill update from a learning must pass `.validate-workflow-skills.sh` and adversarial review.
