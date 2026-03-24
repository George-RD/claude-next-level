---
name: chief-of-staff
description: "Domain knowledge for meta-orchestration — dispatch-and-poll patterns, wave coordination, merge-as-you-go, JJ workspace integration, quality gate injection, cross-plugin routing, and error recovery. Core methodology for the chief-of-staff plugin."
---

# Chief-of-Staff — Domain Knowledge

Reference knowledge for orchestrating multi-agent development workflows. The procedural commands live in skill files; this document provides the patterns, state machine, and expertise those commands depend on.

## When This Activates

- You are coordinating multiple agents across issues, PRs, or features
- You need to plan and dispatch waves of parallel work
- You are managing context budget across a long orchestration session
- You need to route work to the correct plugin or agent type

---

## 1. Orchestration Patterns

### Dispatch-and-Poll

The fundamental pattern. Spawn a finite number of agents, poll for completion, act on results.

```
1. Determine work units (issues, tasks, files)
2. Spawn agents with run_in_background: true
3. Poll for completion (agents report back automatically)
4. Collect results, evaluate quality gates
5. Act on results: merge, retry, escalate, or dispatch next wave
```

Each agent is **fire-and-forget with result collection**. The agent receives a complete prompt, does its work, and exits. It does not wait for further instructions. The orchestrator (you) handles all coordination.

**Key constraint:** Never use `team()` or `sendMessage()` between agents. Agents are independent. Coordination happens through the orchestrator and through disk (git branches, state files).

### Wave Coordination

Group tasks by dependency layer. Dispatch each wave in parallel. Sequence between waves.

```
Wave 1: [Task A, Task B, Task C]    ← no dependencies, all parallel
         ↓ all complete
Wave 2: [Task D (needs A), Task E (needs B)]  ← depend on wave 1
         ↓ all complete
Wave 3: [Task F (needs D, E)]        ← depends on wave 2
```

Rules:

- Tasks within a wave have zero dependencies on each other
- A wave does not start until all tasks in the previous wave are complete (or failed/skipped)
- Failed tasks: evaluate whether dependents can proceed without them. If yes, continue. If no, skip the dependent and note the reason.
- Maximum 4 agents per wave (backpressure). If a wave has more than 4 tasks, split into sub-waves of 4.

### Merge-as-you-go

Do NOT batch PRs for merge at the end. As each agent completes:

```
Agent completes → quality gates pass? → create PR → review passes? → merge → rebase remaining agents
```

This prevents merge conflicts from accumulating. Each merge narrows the diff surface for remaining work.

**Rebase protocol after each merge:**

1. Identify all active agent branches/workspaces
2. For JJ: `jj rebase -b <bookmark> -d main` in each workspace
3. For git worktrees: `git rebase main` in each worktree
4. If rebase conflicts: pause the affected agent, resolve, then resume

### Context Management

The orchestrator's context window is a finite resource. Monitor and protect it.

| Context % | Action |
|-----------|--------|
| 0-60% | Normal operation. Dispatch freely. |
| 60-80% | Reduce verbosity. Summarize agent outputs instead of including raw results. |
| 80-90% | **Checkpoint.** Write full state to disk (state.json, progress notes). Stop dispatching new waves. |
| 90%+ | **Handoff.** Write a HANDOFF.md with complete status, remaining work, and resumption instructions. Exit gracefully. |

**Checkpoint content:**

- Current wave number and completion status of each task
- Agent results received so far
- Remaining work items
- Any decisions made and rationale
- Blocked items and why

---

## 2. State Machine

### States

```
PLANNING → DISPATCHING → MONITORING → CHECKPOINTING → COMPLETE
               ↑              ↓
               └── RECOVERING ←
```

| State | Entry Condition | What Happens | Exit Condition |
|-------|----------------|--------------|----------------|
| PLANNING | Session start or new work batch | Parse issues, build dependency graph, assign waves | Wave plan is written to state.json |
| DISPATCHING | Wave plan ready, or previous wave complete | Spawn agents for current wave with isolation | All agents in current wave are launched |
| MONITORING | All agents dispatched | Poll for agent completion, collect results | All agents in wave complete (success, fail, or timeout) |
| RECOVERING | An agent failed or quality gate rejected | Analyze failure, adjust scope, re-dispatch | Recovery agent dispatched or task skipped |
| CHECKPOINTING | Context at 80%, or wave complete, or explicit request | Write full state to disk, prune context | State persisted, ready for next wave or handoff |
| COMPLETE | All waves done, all quality gates passed | Final report to user | Terminal state |

### State File Format (state.json)

```json
{
  "version": 1,
  "session_id": "cos-2024-01-15-a3f2",
  "current_state": "MONITORING",
  "current_wave": 2,
  "total_waves": 4,
  "plan": {
    "source": "issues | manual | pr-list",
    "created_at": "2024-01-15T10:30:00Z"
  },
  "waves": [
    {
      "wave": 1,
      "status": "complete",
      "tasks": [
        {
          "id": "task-1",
          "issue": "#42",
          "agent_id": "agent-cos-1",
          "isolation": "jj:cos-agent-1",
          "status": "merged",
          "branch": "feat/issue-42",
          "pr": 101,
          "started_at": "...",
          "completed_at": "..."
        }
      ]
    },
    {
      "wave": 2,
      "status": "in_progress",
      "tasks": [
        {
          "id": "task-3",
          "issue": "#44",
          "agent_id": "agent-cos-3",
          "isolation": "jj:cos-agent-3",
          "status": "running",
          "branch": "feat/issue-44",
          "started_at": "..."
        }
      ]
    }
  ],
  "completed_prs": [101, 102],
  "context_percent": 45,
  "checkpoint_count": 0
}
```

### Session Resumption Protocol

When resuming from a checkpoint or handoff:

1. Read `state.json` from the project root or `.chief-of-staff/` directory
2. Parse `current_state` and `current_wave`
3. For each task in the current wave, check its status:
   - `running` → check if the agent branch exists and has new commits since `started_at`. If yes, collect results. If no, treat as timed out.
   - `failed` → enter RECOVERING for this task
   - `complete` → verify PR exists and is mergeable
   - `merged` → no action needed
4. Resume from the appropriate state
5. If `state.json` is missing but HANDOFF.md exists, parse the handoff document and reconstruct state

---

## 3. Agent Dispatch Reference

### Agent Types

| Agent Type | Isolation | Model | Background | Use Case |
|-----------|-----------|-------|------------|----------|
| Research | None | sonnet | true | Explore codebase, read issues, analyze dependencies |
| Implementation | JJ workspace or git worktree | sonnet | true | Write code, run tests, create PR |
| Review | None | sonnet | true | Review code, review PR, check quality |

**Wave coordinator** is not a separate agent type — it is the orchestrator itself operating in foreground mode (opus model) when performing wave planning, dependency graph analysis, and cross-agent coordination.

**Fix agent** is deferred to v2. For MVP, the orchestrator re-dispatches the implementer agent into the same workspace with corrective instructions when fixes are needed (e.g., after review comments or CI failures).

### Agent Prompt Template

Every dispatched agent receives a structured prompt. Required sections:

```markdown
## Your Task
{One-sentence description of what to accomplish}

## Context
- Repository: {owner}/{repo}
- Branch: {branch_name}
- Working directory: {absolute_path_to_workspace}
- Related issue: {issue_url_or_number}

## Instructions
{Detailed instructions for the task}

## Quality Gates (MUST PASS before you finish)
- [ ] {formatter/linter command} passes with zero errors
- [ ] {test command} passes
- [ ] {any project-specific checks}

## When Complete
1. Commit all changes with message: "{conventional_commit_message}"
2. Push to remote: git push -u origin {branch_name}
3. Create PR: gh pr create --title "{title}" --body "{body}"
4. Report: output a summary of what you did and the PR URL
```

### Isolation Strategy Selection

```
Is this a JJ repo? (jj root 2>/dev/null)
  ├─ Yes → Use JJ workspaces
  │        jj workspace add ../cos-agent-{id}
  └─ No  → Use git worktrees
           git worktree add ../cos-agent-{id} -b {branch}
```

**Never run two implementation agents in the same workspace.** Research and review agents can share the main workspace since they are read-only.

### Model Selection

- **Sonnet** for all leaf-level work: implementation, review, research. It is fast, cheap, and high-quality for focused tasks.
- **Opus** only when the task requires cross-cutting analysis: wave planning, dependency graph construction, resolving conflicting agent outputs, architectural decisions. Use sparingly and in foreground (blocking) mode since you need the result immediately.

---

## 4. JJ Workspace Integration

### Detection

```bash
# Check if current repo uses JJ
jj root 2>/dev/null && echo "JJ repo" || echo "Git-only repo"
```

### Workspace Lifecycle

```bash
# Create workspace for an agent
jj workspace add ../cos-agent-{id}

# Agent works in the workspace
cd ../cos-agent-{id}
# ... edit files ...
jj describe -m "feat: implement issue #42"
jj bookmark set feat/issue-42
jj git push --bookmark feat/issue-42

# After merge, clean up
jj workspace forget cos-agent-{id}
rm -rf ../cos-agent-{id}
```

### JJ-Specific Patterns

**Bookmark management:**

- Each agent creates a bookmark for its work: `jj bookmark set {branch-name}`
- Push with: `jj git push --bookmark {branch-name}`
- After PR merge, delete bookmark: `jj bookmark delete {branch-name}`

**Multi-parent merge (batching related changes):**

```bash
# Create a new change with multiple parents
jj new <bookmark1> <bookmark2>
jj describe -m "merge: combine related features"
```

**Rebasing after a merge:**

```bash
# Rebase an agent's work onto updated main
jj git fetch
jj rebase -b <bookmark> -d main
```

**Conflict detection:**

```bash
# Check for conflicts before merging
jj log --revisions "conflicts()"
```

### Fallback to Git Worktrees

If JJ is not available, use git worktrees with equivalent patterns:

```bash
# Create worktree
git worktree add ../cos-agent-{id} -b {branch-name}

# Agent works in worktree
cd ../cos-agent-{id}
# ... edit, commit, push ...

# After merge, clean up
git worktree remove ../cos-agent-{id}
git branch -d {branch-name}
```

---

## 5. Quality Gate Injection

Quality gates ensure every agent produces work that meets project standards. The orchestrator assembles gates from multiple sources and injects them into agent prompts.

### Gate Sources (priority order)

1. **Project CLAUDE.md** — read `CLAUDE.md` in the repo root for project-specific conventions, test commands, and style rules
2. **next-level config** — if `~/.next-level/config.json` exists, read formatter, linter, and test commands per language
3. **Language defaults** — fallback table if no config is found

### Language Default Gates

| Language | Formatter | Linter | Test |
|----------|-----------|--------|------|
| TypeScript | `npx prettier --write .` | `npx eslint .` | `npm test` |
| Python | `ruff format .` | `ruff check .` | `pytest` |
| Go | `gofmt -w .` | `go vet ./...` | `go test ./...` |
| Rust | `cargo fmt` | `cargo clippy` | `cargo test` |
| Swift | `swift-format -r -i .` | `swiftlint` | `swift test` |

### Gate Assembly

When constructing an agent prompt:

1. Read CLAUDE.md for explicit commands (e.g., "run `make lint` before committing")
2. Check `~/.next-level/config.json` for structured config:

   ```json
   {
     "languages": {
       "typescript": {
         "formatter": "npx prettier --write .",
         "linter": "npx eslint .",
         "test": "npm test"
       }
     },
     "max_file_length": 300,
     "conventions": ["conventional-commits"]
   }
   ```

3. Fall back to the language defaults table
4. If the task has an associated issue, extract acceptance criteria from the issue body and include them as additional gates
5. Combine all gates into the "Quality Gates" section of the agent prompt template

### File Length Enforcement

If `max_file_length` is configured (or defaults to 300 lines):

- Include in agent prompt: "No single file should exceed {N} lines. Split into modules if needed."
- Review agents should flag files exceeding the limit.

---

## 6. Cross-Plugin Routing

The chief-of-staff knows about sibling plugins and routes work to them when appropriate.

### Detection Matrix

| Signal | Route To | Why |
|--------|----------|-----|
| User says "review this PR" or provides PR URL | `/cycle:pr` | Cycle handles PR review orchestration with CodeRabbit awareness |
| Task requires spec extraction before implementation | `/repo-clone` spec stages | repo-clone has behavioral spec extraction methodology |
| User wants a spec-driven build loop | `/ralph-loop` or `/repo-clone` build stage | Ralph loop handles iterative single-task-per-iteration builds |
| Multiple independent issues to implement | Chief-of-staff wave dispatch | This is the core use case — parallel multi-issue orchestration |
| Single issue, straightforward implementation | Direct agent dispatch | No plugin overhead needed for simple tasks |
| User says "port this to {language}" | `/repo-clone init` | repo-clone handles cross-language porting |

### Routing Decision Tree

```
User request arrives
  ├─ Is it a PR review? → /cycle:pr
  ├─ Is it a codebase port? → /repo-clone
  ├─ Is it a single, small task? → Direct agent (no plugin)
  ├─ Does it require a spec-first approach?
  │   ├─ Yes, single module → /ralph-loop or /spec workflow
  │   └─ Yes, many modules → chief-of-staff with spec extraction wave
  └─ Is it multiple tasks/issues?
      └─ chief-of-staff wave coordination
```

### Composing Plugins

The chief-of-staff can compose plugins within a wave:

```
Wave 1 (research):  Explore agents read issues, assess scope
Wave 2 (specs):     /repo-clone spec extraction for complex modules
Wave 3 (build):     Implementation agents, one per issue
Wave 4 (review):    /cycle:pr for each created PR
```

Each wave can use a different plugin's methodology. The chief-of-staff handles the transitions.

---

## 7. Error Recovery

### Failure Classification

| Problem | Root Cause | Detection | Resolution |
|---------|-----------|-----------|------------|
| Agent stuck (no output 5+ min) | Context exhaustion or infinite loop | Timeout exceeded, no new commits on branch | Cancel agent. Re-dispatch with reduced scope (fewer files, simpler instructions). |
| Quality gate fails | Agent did not follow conventions | CI red, linter errors, test failures | Re-dispatch fix agent into same workspace with explicit gate instructions and the failure output. |
| Merge conflict | Parallel agents touched same files | `git merge --no-commit` fails or JJ reports conflicts | Serialize remaining work on conflicting files. Resolve conflict manually or dispatch a resolution agent. |
| Context at 90% | Too many agents or too much collected output | Context percentage monitor | Checkpoint immediately. Write HANDOFF.md. Exit session gracefully. |
| Agent produces wrong output | Ambiguous instructions or hallucination | Review agent flags issues, or PR review catches problems | Discard agent's branch. Re-dispatch with clearer instructions and examples. |
| PR review requests large refactor | Scope creep from reviewer | Review comments suggest architectural changes | Create follow-up issue. Keep current PR focused. Note the refactor for a future wave. |
| JJ workspace corruption | Interrupted operation or disk issue | `jj workspace list` shows stale entries | `jj workspace forget {id}`, remove directory, re-dispatch. |
| Git worktree in bad state | Uncommitted changes or detached HEAD | `git worktree list` shows inconsistencies | `git worktree remove --force {path}`, `git worktree prune`, recreate. |

### Recovery Protocol

When an agent fails:

1. **Assess impact.** Does this block other tasks in the current wave? Does it block future waves?
2. **Classify severity:**
   - **Retriable:** Quality gate failure, timeout, transient error → re-dispatch with adjustments
   - **Skippable:** Non-critical task, no dependents → mark as skipped, continue
   - **Blocking:** Critical path task with dependents → must resolve before proceeding
3. **Act:**
   - Retriable: Re-dispatch with reduced scope, explicit instructions, and the error output for context. Max 2 retries per task.
   - Skippable: Mark task as `skipped` in state.json with reason. Update dependency graph — dependents of skipped tasks should be re-evaluated.
   - Blocking: Escalate to user with a clear summary: what failed, why, what options exist.

### Retry Budget

- Each task gets a maximum of **2 retries** (3 total attempts)
- After 3 failures: mark as `skipped`, notify user, move on
- Each wave gets a maximum of **1 full re-dispatch** (if >50% of tasks fail, re-plan the wave rather than retrying individual tasks)

---

## 8. Wave Planning Algorithm

### Input

A list of work items (issues, tasks, or feature descriptions).

### Step 1: Fetch Details

For each work item:

- If it is a GitHub issue: `gh issue view {number} --json title,body,labels,assignees`
- If it is a PR: `gh pr view {number} --json title,body,files`
- If it is a text description: parse directly

Extract:

- **Files likely touched** (from issue body, PR files, or inference from description)
- **Dependencies** (explicit: "depends on #N", or implicit: shared files/modules)
- **Complexity estimate** (small: 1-2 files, medium: 3-5 files, large: 6+ files)

### Step 2: Build Dependency Graph

```
For each pair of tasks (A, B):
  file_overlap = files_touched(A) ∩ files_touched(B)
  if file_overlap is not empty:
    # These tasks conflict — cannot be in the same wave
    add_edge(A, B) if A has lower issue number (arbitrary but deterministic)
  if A explicitly depends on B:
    add_edge(B, A)  # B must complete before A
```

### Step 3: Topological Sort and Wave Assignment

```
remaining = all tasks
wave_number = 1

while remaining is not empty:
  # Find tasks with no unresolved dependencies
  eligible = [t for t in remaining if all deps of t are complete or not in remaining]

  if eligible is empty:
    # Circular dependency — break the cycle
    # Pick the task with fewest dependencies, force it into this wave
    eligible = [min(remaining, key=lambda t: len(deps(t)))]

  # Enforce backpressure: max 4 per wave
  wave = eligible[:4]
  assign wave_number to each task in wave
  remove wave from remaining
  wave_number += 1
```

### Step 4: Output Wave Plan

Write to state.json under the `waves` key. Each wave contains:

- Wave number
- List of tasks with: id, issue reference, estimated files, isolation strategy, branch name
- Status: `pending`

### Complexity-Based Isolation

| Complexity | Isolation Strategy |
|-----------|-------------------|
| Small (1-2 files) | JJ workspace or git worktree |
| Medium (3-5 files) | JJ workspace or git worktree |
| Large (6+ files) | JJ workspace or git worktree, with reduced wave size (max 2 large tasks per wave) |

Large tasks consume more agent context and take longer. Reduce wave concurrency to avoid overwhelming the orchestrator's monitoring capacity.

---

## 9. Orchestrator Discipline

### You Are the Event Loop

Think of yourself as an event loop, not a sequential executor:

```
IDLE (ready for user input)
  ↓ user request arrives
PLAN → dispatch background agents → IDLE
  ↓ agent result arrives
REVIEW → merge/coordinate → dispatch next wave or report → IDLE
  ↓ user input arrives while agents running
RESPOND immediately (agents continue in background)
```

You should spend most of your time in the IDLE state, ready to respond instantly.

### What to Do Directly vs Delegate

| Do Directly | Delegate to Agent |
|-------------|-------------------|
| Read state.json, parse wave status | Any file creation or multi-file change |
| Quick git/jj commands (status, log) | Code implementation |
| Wave planning (with opus if complex) | Codebase exploration or research |
| Merging PRs, rebasing branches | Code review, test execution |
| Writing state updates | PR creation and description |
| Routing decisions | Running quality gate checks |

### Anti-Patterns

- **Do not** implement code yourself. You are the orchestrator, not a worker.
- **Do not** read large files to understand code. Spawn a research agent.
- **Do not** hold agent results in your context if you can write them to disk.
- **Do not** dispatch wave N+1 before wave N is complete (unless tasks are independent).
- **Do not** retry a failed task more than twice without changing the approach.
- **Do not** merge PRs without quality gates passing.
- **Do not** dispatch more than 4 agents simultaneously.
- **Do** checkpoint proactively. Context is your scarcest resource.
- **Do** write decisions to state.json so a resumed session has full context.
- **Do** notify the user at wave boundaries with a concise progress summary.
