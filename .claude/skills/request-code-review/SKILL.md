---
name: request-code-review
description: Primary review entrypoint for plans, diffs, commits, subagent results, and pre-submit checks. Selects quick, standard, or deep mode by scale and risk.
version: 0.1.0
author: George-RD
x-compatibility: jcode-primary, claude-code-adaptable, opencode-adaptable
---

# Request Code Review

Use this skill as the main code review entrypoint. It can run a quick single-review, a multi-lens lightweight review, or escalate to `deep-review` for milestone/risky checkpoint review.

Core principle: review early, review precisely, scale reviewer effort to the change, and turn valid out-of-scope findings into follow-up tasks instead of expanding the current PR by default.

Default path: identify the target, load only relevant repo/domain skills or instructions, choose quick/standard/deep by scale and risk, dispatch the minimum useful reviewers, synthesize evidenced findings, fix in-scope blockers, and rerun gates.

## Workflow

1. Identify the review target:
   - plan/spec: OpenSpec change, tasks.md, or implementation plan before coding
   - single commit: `HEAD~1..HEAD`
   - stack: `base..HEAD`, often `dev..HEAD`, `main..HEAD`, or upstream branch
   - uncommitted diff: current working tree
2. Summarize what changed or is planned, requirements, non-goals, change type, expected validation gates, and known risks.
3. Discover relevant repo/domain skills or instructions from project-local skills, repo docs, and available skill descriptions. Load only the skill bodies or references that match the target, and record which were considered.
4. Choose review mode:
   - quick = tiny/small low-risk: inline structured review or one reviewer
   - standard = medium ordinary work: 2-4 lightweight lenses when cheap models are available
   - deep = large/risky/checkpoint/pre-submit/security/process-sensitive/disputed: call `deep-review`
5. Choose lenses based on likely failure modes: spec/plan correctness, implementation correctness, maintainability/simplify, tests/gates, UX/docs, workflow/process, adversarial. For runnable user-facing UI/UX changes, treat unexplained missing browser or visual evidence as a review finding unless clearly not runnable.
6. Dispatch reviewers with `subagent` when bounded and cheap. Use `swarm` only when persistent coordination is needed.
7. Require structured output. Prefer JSON when the coordinator must act programmatically. Ask reviewers to summarize large logs or diffs instead of pasting them in full.
8. Treat Critical as blocking. Treat Important as fix-before-proceed only when supported by evidence, plausible impact, and an in-scope remedy. Track Minor or create follow-ups opportunistically.

## Context funnel

Read references only when needed:

- `references/review-rubric.md`: severity definitions and checklist.
- `references/reviewer-json-schema.md`: machine-readable review output.
- `references/adversarial-review.md`: minimax or red-team prompts for adversarial/process/security lenses.
- `references/multi-review-fanout.md`: lightweight multi-lens roles and synthesis. Escalate to `deep-review` for milestone/risky checkpoints.
- `assets/evidence-packet.md`: copyable review packet template.
- `scripts/validate.sh`: behavioral contract checks for this skill.

## Minimum reviewer prompt fields

- repo path and branch
- base and head refs or statement that diff is uncommitted
- what was implemented
- change type and expected validation gates
- requirements or acceptance criteria
- gates already run
- known risks or process constraints
- relevant skills or instructions loaded, plus relevant ones considered but skipped
- exact output format requested
- whether out-of-scope findings should become follow-up tasks

## Follow-up rule

If a reviewer finds a real issue outside current scope, do not silently expand the PR. Create or propose a follow-up with evidence, impact, acceptance criteria, and priority unless it blocks correctness or acceptance for the current task.

Do not give the reviewer the whole session transcript unless the task is reviewing process or truthfulness. Focus review on plan/diff, requirements, and evidence. If reviewer feedback lacks concrete evidence or conflicts with project conventions, verify before changing code.
