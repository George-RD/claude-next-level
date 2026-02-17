---
name: execute
description: Execute an epic — sequences tasks from GitHub issues, runs spec workflow per task, adversarial checkpoints between tasks.
user-invocable: true
argument-hint: "<epic-name | issue-number>"
---

# Epic Executor

Execute an epic by running the spec workflow on each task in dependency order, with adversarial checkpoints between tasks.

## Phase 1: Load Epic

1. **Identify the epic**: Parse $ARGUMENTS for epic name or issue number
2. **Fetch issues**: Use `gh issue list` to get all tasks for this epic:
   ```bash
   gh issue list --milestone "<epic-milestone>" --state open --json number,title,body,labels --limit 50
   ```
3. **Parse dependencies**: Read each issue body for "Blocked by: #N" references
4. **Build execution order**: Topological sort respecting dependencies
5. **Show plan**: Present the execution order to the user for confirmation

## Phase 2: Execute Tasks

For each task in execution order:

### 2a. Start Task
- Update GitHub issue: `gh issue edit <number> --remove-label "status:planned" --add-label "status:in-progress"`
- Read the full issue body for acceptance criteria and approach
- If omega memory is available, call `omega_query()` for context on related past work

### 2b. Run Spec Workflow
- Create a spec from the issue: write spec JSON with issue details
- **Plan**: If the issue body has a clear approach, use `/next-level:quick`. Otherwise, run `/next-level:spec-plan` for the task.
- **Implement**: Run the spec-implement phase with strict TDD
- **Verify**: Run spec-verify — tests, lint, code review

### 2c. Adversarial Checkpoint
After each task completes, dispatch the **checkpoint-reviewer** agent:
- Pass: project plan, completed task details, test results, diff since epic started
- The reviewer verifies: task matches plan, no drift from vision, integration with previous tasks works

#### Trust Escalation
Review depth adjusts based on task position and track record:
- **First 2-3 tasks**: Full review (code + tests + integration check)
- **Middle tasks**: Medium review (tests pass + integration check)
- **Final tasks**: Light review (tests pass, no regressions)

If the reviewer returns a non-CONTINUE verdict:
- **FLAG_FOR_HUMAN**: Pause and present findings to the user
- **STOP**: Halt execution, report the issue

### 2d. Complete Task
- Update GitHub issue: `gh issue edit <number> --remove-label "status:in-progress" --add-label "status:complete"` and close it
- Commit with message referencing the issue: `fixes #<number>`
- If omega memory available: `omega_store(task_summary, "milestone")`
- Call `omega_checkpoint()` if context is above 60% to ensure session continuity

## Phase 3: Multi-Epic Coordination

When a project has multiple epics:
- Respect epic-level dependencies (don't start Epic 3 if Epic 2 isn't done)
- Track cross-epic integration points
- After completing an epic, update the GitHub milestone:
  ```bash
  gh api repos/{owner}/{repo}/milestones/<number> -X PATCH -f state="closed"
  ```

Independent epics CAN run in parallel via agent teams (see `/next-level:team-execute`).

## Phase 4: Session Continuity

If context approaches 85% during execution:
1. Call `omega_checkpoint()` to save full state
2. Write resume prompt to `~/.next-level/sessions/{id}/resume.md`:
   - Project context and epic being executed
   - Completed tasks (with issue numbers)
   - Current task (in progress or next)
   - Key decisions made during execution
3. Tell the user to run `/next-level:resume` in a new session

## Error Handling

- If a task fails verification after 3 attempts: mark it as blocked, skip to next unblocked task, flag for human
- If a dependency is unresolvable: pause and ask the user
- If `gh` commands fail: fall back to local tracking via spec JSON files
- If omega is unavailable: use local state files for continuity

## Output

After completing all tasks in the epic:
```
EPIC COMPLETE: <epic-name>
═════════════════════════
Tasks completed: N/M
Tests passing: all
Issues closed: #1, #2, #3, ...
Milestone: closed

Next: /next-level:execute <next-epic> (if applicable)
```
