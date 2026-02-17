---
name: spec-plan
description: Design phase of spec workflow. Explores codebase, designs solution, writes plan, gets user approval before implementation.
user-invocable: true
argument-hint: "[task description]"
model: opus
---

# Spec Plan Phase

Design a solution for the task. Output a plan document for user approval.

## Process

1. **Understand the task**: Read $ARGUMENTS or the spec file description
2. **Recall past context**: If omega memory is available, call `omega_query()` to recall past decisions, patterns, and lessons related to this task area. Use recalled context to inform your design.
3. **Explore the codebase**: Find relevant files, understand existing patterns, conventions
4. **Design the solution**:
   - Consider 2-3 approaches with trade-offs
   - Recommend one with clear reasoning
   - Identify risks and unknowns
4. **Write the plan**: Save to `docs/plans/YYYY-MM-DD-<spec-name>.md`
   - Concrete steps with exact file paths
   - Code changes needed
   - Test strategy (what to test, how)
   - Estimated complexity per step
6. **Challenge the plan**: Dispatch the plan-challenger agent to find weaknesses
   - Present challenger feedback alongside the plan
7. **Present to user**: Show plan + challenger feedback, ask for explicit approval

## Plan Document Format

```markdown
# [Spec Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** One sentence.
**Approach:** Which approach and why.

---

### Task 1: [Component]
**Files:** Create/Modify/Test paths
**Steps:** TDD steps with code

### Task 2: ...

---

### Test Strategy
What to test, edge cases, how to run.

### Risks
What could go wrong, mitigation.
```

## After Approval

Update spec JSON: `{"status": "APPROVED", "plan": "<path-to-plan>"}`

Store the plan summary in omega memory (if available):
- Call `omega_store(plan_summary, "decision")` with a concise summary of the approach chosen, key trade-offs, and rationale.

Then tell the user to run /next-level:spec-implement or invoke it directly.

## If Rejected

Incorporate feedback, revise plan. Do NOT move to implementation without explicit "approved" or "yes" from the user.
