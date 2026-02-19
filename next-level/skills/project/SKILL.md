---
name: project
description: Project-level planner — breaks large work into epics and tasks, creates GitHub issues with milestones, sequences execution order.
user-invocable: true
argument-hint: "<project description>"
model: opus
---

# Project Planner

You are planning a multi-epic project. Break large work into executable chunks with GitHub issue tracking.

## Phase 1: Discovery

1. **Understand the goal**: Read $ARGUMENTS for the project description
2. **Recall context**: If omega memory is available, call `omega_query()` to recall past decisions and patterns for this codebase
3. **Explore the codebase**: Use the Explore agent or Glob/Grep/Read to understand:
   - Project structure and architecture
   - Existing patterns and conventions
   - Test infrastructure
   - CI/CD setup
   - Dependencies and constraints

## Phase 2: Clarify Scope

Ask the user clarifying questions about:
- Success criteria — what does "done" look like?
- Constraints — timeline, tech stack restrictions, backwards compatibility?
- Non-goals — what's explicitly out of scope?
- Priority — if we can only ship part of this, what matters most?

Use the AskUserQuestion tool for structured questions.

## Phase 3: Generate Project Structure

Break the project into:

### Epics (major work streams)
- Each epic should be independently shippable
- Epics should be ordered by dependency (what unblocks what)
- Each epic gets a GitHub milestone

### Tasks (individual specs within an epic)
For each task:
- Clear description and acceptance criteria
- Complexity estimate: S (1-2 hours), M (half day), L (full day), XL (multi-day)
- Dependencies (which tasks must complete first)
- Files likely to be created/modified
- Test approach

### Dependency Map
- Draw the dependency graph: which epics/tasks block which
- Identify the critical path
- Flag parallelizable work

## Phase 4: Adversarial Review

Before creating issues, dispatch the **project-reviewer** agent:
- Pass the full project plan
- The reviewer checks for: missing requirements, unrealistic sequencing, scope creep, missing test strategy, integration risks
- Address CRITICAL feedback before proceeding
- Present the plan + reviewer feedback to the user for approval

## Phase 5: Create GitHub Issues

After user approval, create the tracking infrastructure:

### Create Milestones (one per epic)
```bash
gh api /repos/{owner}/{repo}/milestones -f title="Epic: <name>" -f description="<epic description>"
```

Note: `{owner}/{repo}` are placeholders — substitute with actual values or use `$(gh repo view --json owner,name -q '"\(.owner.login)/\(.name)"')`. Capture the milestone number from the response for use in issue creation. You can also use the milestone title directly with `--milestone "Epic: <name>"` in `gh issue create`.

### Create Issues (one per task)
```bash
gh issue create \
  --title "<task title>" \
  --body "$(cat <<'EOF'
## Description
<task description>

## Acceptance Criteria
- [ ] <criterion 1>
- [ ] <criterion 2>

## Dependencies
Blocked by: #<issue-number> (if any)

## Approach
<estimated approach, files to touch>

## Complexity
<S|M|L|XL>
EOF
)" \
  --milestone "<milestone-number>" \
  --label "epic:<name>" \
  --label "size:<S|M|L|XL>" \
  --label "status:planned"
```

### Label Dependencies
After all issues are created, add dependency references:
- Update issue bodies with correct `#issue-number` cross-references
- Add `blocked-by:<issue>` labels where applicable

## Phase 6: Store Plan

1. Write the full project plan to `docs/plans/YYYY-MM-DD-<project-name>.md`
2. If omega memory is available: `omega_store(plan_summary, "decision")` with key architectural decisions

## Output

Present to the user:
- Project overview with epic count and total task count
- Execution order recommendation
- GitHub milestone URLs
- Suggested first command: `/next-level:execute <epic-name>`

## Rules

- Never create more than 30 issues in one go — ask user to confirm if plan exceeds this
- Each task must be completable in a single Claude Code session
- XL tasks should be broken down further — they're too large for one session
- If the project scope is unclear, ask questions rather than guessing
- Include a test strategy for every epic, not just individual tasks
