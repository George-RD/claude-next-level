---
name: spec
description: Start or continue a spec-driven development workflow. Orchestrates plan → implement → verify cycle with approval gates.
user-invocable: true
argument-hint: "[task description]"
---

# Spec-Driven Development

Orchestrate structured development through three phases: **plan**, **implement**, **verify**.

## Usage

`/next-level:spec <task description>`

## Workflow

1. Check for existing spec state in `~/.next-level/specs/`
2. Route to the correct phase based on status:

| Status | Action |
|--------|--------|
| No spec | Create new spec → /next-level:spec-plan |
| PLANNING | Continue /next-level:spec-plan |
| APPROVED | Run /next-level:spec-implement |
| IMPLEMENTING | Continue /next-level:spec-implement |
| COMPLETE | Run /next-level:spec-verify |
| VERIFYING | Continue /next-level:spec-verify |
| VERIFIED | Done — report success |
| FAILED | Back to /next-level:spec-implement with feedback |

## Starting a New Spec

1. Slugify the task description (lowercase, hyphens, no special chars)
2. Create spec file at `~/.next-level/specs/<slug>.json`:
```json
{
  "name": "<slug>",
  "description": "$ARGUMENTS",
  "status": "PLANNING",
  "created": "<ISO timestamp>",
  "plan": null,
  "feedback": []
}
```
3. Invoke /next-level:spec-plan with the description

## Resuming an Existing Spec

1. List `~/.next-level/specs/*.json`
2. Find the most recent non-VERIFIED spec
3. Read its status and route to the appropriate skill
4. If multiple active specs, ask user which to continue

## Context Check

Before starting any phase, estimate context usage. If above 80%, write handoff notes to `~/.next-level/sessions/{session}/continuation.md` instead of starting a new phase. Include the spec name, current status, and what phase to resume.
