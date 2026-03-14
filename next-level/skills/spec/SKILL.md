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

For each status, Read the corresponding reference file and follow its process.

| Status | Phase | Reference |
|--------|-------|-----------|
| No spec / PLANNING | Plan | `references/spec-plan.md` |
| APPROVED / IMPLEMENTING | Implement | `references/spec-implement.md` |
| COMPLETE / VERIFYING | Verify | `references/spec-verify.md` |
| VERIFIED | Done | — (report success) |
| FAILED | Implement | `references/spec-implement.md` (with feedback) |

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
3. Read `references/spec-plan.md` and follow the process with the description

## Resuming an Existing Spec

1. List `~/.next-level/specs/*.json`
2. Find the most recent non-VERIFIED spec
3. Read its status and route to the appropriate skill
4. If multiple active specs, ask user which to continue

## Context Check

Before starting any phase, estimate context usage. If above 80%, write handoff notes to `~/.next-level/sessions/{session}/continuation.md` instead of starting a new phase. Include the spec name, current status, and what phase to resume.
