---
name: team-execute
description: Execute an epic using agent teams for parallel task execution. Team lead coordinates, coding agents implement, review agent checkpoints.
user-invocable: true
argument-hint: "<epic-name>"
---

# Team Execution

Execute an epic using parallel agent teams. For epics with independent tasks that can be worked on simultaneously.

## When to Use

- Epic has 3+ tasks
- At least 2 tasks are independent (no dependency between them)
- Tasks are well-defined with clear acceptance criteria
- Sequential execution would take too long

## When NOT to Use

- All tasks are sequential (dependent chain)
- Tasks are tightly coupled (changing one affects others)
- Epic has fewer than 3 tasks (overhead not worth it)
- Use `/next-level:execute` for sequential execution instead

## Phase 1: Analyze Epic

1. Fetch all issues for the epic from GitHub
2. Build dependency graph
3. Identify parallelizable groups:
   - Group A: tasks with no dependencies (can start immediately)
   - Group B: tasks depending only on Group A
   - etc.
4. Present execution plan to user for approval

## Phase 2: Create Team

```text
TeamCreate: team_name = "epic-<name>"
```

### Team Composition

Create tasks for each work item, then spawn agents:

**Team Lead** (you — the orchestrator):
- Reads project plan and assigns tasks
- Monitors progress via TaskList
- Routes checkpoint results
- Handles errors and blocked tasks

**Coding Agents** (one per parallelizable task):

```text
Task tool with:
  subagent_type: "coding-agent"
  team_name: "epic-<name>"
  name: "coder-<task-slug>"
  model: "sonnet"
  mode: "bypassPermissions"
  prompt: <task-specific context — see Coding Agent Prompt Template below>
```

**Review Agent** (one, shared across all tasks):

```text
Task tool with:
  subagent_type: "checkpoint-reviewer"
  team_name: "epic-<name>"
  name: "reviewer"
  model: "sonnet"
  mode: "default"
  prompt: <checkpoint context — plan, completed task, test results, git diff>
```

## Phase 3: Execute in Waves

### Wave 1: Independent Tasks
- Spawn coding agents for all Group A tasks simultaneously
- Each agent receives:
  - Task description and acceptance criteria
  - Relevant file paths and patterns
  - TDD requirements
  - Instructions to report back via SendMessage when done

### Between Waves: Checkpoint
- Wait for all Wave 1 agents to complete
- Send completed work to review agent for checkpoint
- If CONTINUE: proceed to Wave 2
- If FLAG_FOR_HUMAN: pause and ask user
- If STOP: halt execution

### Wave 2+: Dependent Tasks
- Spawn agents for next group of unblocked tasks
- Repeat checkpoint between waves

## Phase 4: Finalize

1. Run full test suite to verify integration
2. Close all GitHub issues for the epic
3. Close the milestone
4. Store completion in omega memory
5. Shut down all team agents via SendMessage shutdown_request
6. TeamDelete to clean up

## Coding Agent Prompt Template

Each coding agent uses the `coding-agent` subagent type (see `agents/coding-agent.md`), which has TDD enforcement and quality hooks built into its frontmatter. The spawn prompt provides task-specific context:

```text
You are implementing task #{ISSUE_NUMBER}: {TASK_TITLE}

## Task Description
{ISSUE_BODY}

## Acceptance Criteria
{ACCEPTANCE_CRITERIA}

## Project Context
- Working directory: {PROJECT_ROOT}
- Test command: {TEST_COMMAND}
- Relevant files: {FILE_LIST}
```

## Fallback: Sequential Mode

If team orchestration is unreliable (agents failing, coordination issues):
1. Shut down the team
2. Fall back to `/next-level:execute` for sequential task execution
3. Log the failure mode in omega memory for future reference

## Error Handling

- If a coding agent fails: reassign its task to a new agent or handle sequentially
- If the review agent flags issues: route specific feedback to the responsible coding agent
- If context runs low: checkpoint and prepare for session resume
- Maximum team size: 4 coding agents (to avoid coordination overhead)
