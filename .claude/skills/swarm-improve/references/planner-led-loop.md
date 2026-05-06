# Planner-led improvement loop

Use planner-led mode for normal repositories and small to medium improvement batches. Avoid database orchestration unless there are hundreds of tasks or long-lived autonomous workers.

## Wave algorithm

1. Build a ranked task list.
2. Mark dependencies and conflicts:
   - same file or subsystem means likely conflict
   - feature/spec ownership means process dependency
   - test/gate dependency means validation dependency
3. Group independent tasks into a wave.
4. Assign each task to one implementer subagent with explicit file scope and gates.
5. Collect results, run local gates, then review.
6. Commit or amend after gates pass. Run review before external submit or risky commits; if review later finds issues, amend or create a follow-up using the repo workflow.
7. Replan from current repo state.

## Pre-spawn safety gates

Before a parallel wave:

- Build a file ownership map: each writable file or subsystem has one owner in the wave.
- Serialize tasks with overlapping file claims.
- Order tasks with dependency edges before independent work.
- Cap at 4 workers per wave by default unless tasks are read-only or user explicitly asks for aggressive dispatch.
- Prefer `subagent` for bounded one-shot work. Use `swarm` only when persistent coordination or shared state is needed.

## Task states

- `todo`: not started
- `claimed`: assigned to a subagent or coordinator
- `ready-for-review`: implementation done, gates claimed by implementer
- `blocked`: cannot proceed without decision, missing context, or failing gate
- `done`: committed or explicitly accepted
- `dead-letter`: repeated failure or unclear value, stop and report

## Checkpoints

Checkpoint after:

- each commit or PR in a stack
- each parallel wave
- any reviewer returns Critical or BLOCK
- any gate fails twice
- the batch reaches 3-5 meaningful changes

At a checkpoint, summarize: changes, gates, review verdicts, open blockers, whether later fixes were tiny/small/medium/large, and whether continuing is still worth it.
