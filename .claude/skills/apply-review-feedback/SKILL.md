---
name: apply-review-feedback
description: Triage and apply code review feedback with technical verification. Use when a human, reviewer subagent, CI, or adversarial reviewer returns findings or requested changes.
version: 0.1.0
author: George-RD
x-compatibility: jcode-primary, claude-code-adaptable, opencode-adaptable
---

# Apply Review Feedback

Use this skill when receiving review feedback. Treat feedback as claims to verify, not orders to blindly follow.

Core principle: understand, verify, classify, then fix one item at a time with gates.

## Workflow

1. Read all feedback before editing.
2. Classify each item: accept, reject with evidence, clarify, defer, or already fixed.
3. If any item is unclear and may affect other items, ask or investigate before partial implementation.
4. Verify claims against code, tests, requirements, and repo workflow.
5. Fix accepted Critical items first, then Important, then opportunistic Minor items.
6. Run targeted gates after each fix cluster and full gates before finalizing.
7. Report what changed, what was rejected or deferred, and why.

## Context funnel

Read references only when needed:

- `references/feedback-triage.md`: classification workflow and response templates.
- `references/yagni-check.md`: when reviewers ask for professional but unused features.
- `references/pushback-patterns.md`: how to reject incorrect feedback with evidence.
- `scripts/validate.sh`: behavioral contract checks for this skill.

## Rules

- Avoid performative agreement. Be concise and technical.
- Do not implement unclear multi-item feedback partially if dependencies are possible.
- Do not add scope because a reviewer said "properly" or "production ready". Check actual usage and requirements.
- If feedback conflicts with user decisions or project specs, stop and surface the conflict.
