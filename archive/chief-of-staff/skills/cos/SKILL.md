---
name: cos
description: "Domain knowledge for meta-orchestration — dispatch-and-poll patterns, wave coordination, merge-as-you-go, context management, JJ workspace integration, quality gate injection, cross-plugin routing, error recovery, wave planning algorithms, and orchestrator discipline. Core methodology for the chief-of-staff plugin."
---

# Chief-of-Staff — Domain Knowledge

Reference knowledge for orchestrating multi-agent development workflows. The procedural commands live in `/cos`, `/cos:implement`, `/cos:research`, `/cos:review`, `/cos:wave`, and `/cos:status`; this document provides the patterns, state machine, and expertise those commands depend on. Context handoff is handled automatically via the `checkpoint.sh` hook (PreCompact and Stop events).

## When This Activates

- You are coordinating multiple agents across issues, PRs, or features
- You need to plan and dispatch waves of parallel work
- You are managing context budget across a long orchestration session
- You need to route work to the correct plugin or agent type
- You are resuming a session from a checkpoint or handoff

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
Wave 1: [Task A, Task B, Task C]    <- no dependencies, all parallel
         | all complete
Wave 2: [Task D (needs A), Task E (needs B)]  <- depend on wave 1
         | all complete
Wave 3: [Task F (needs D, E)]        <- depends on wave 2
```

Rules:

- Tasks within a wave have zero dependencies on each other
- A wave does not start until all tasks in the previous wave are complete (or failed/skipped)
- Failed tasks: evaluate whether dependents can proceed without them. If yes, continue. If no, skip the dependent and note the reason.
- Maximum 4 agents per wave (backpressure). If a wave has more than 4 tasks, split into sub-waves of 4.

### Merge-as-you-go

Do NOT batch PRs for merge at the end. As each agent completes:

```
Agent completes -> quality gates pass? -> create PR -> review passes? -> merge -> rebase remaining agents
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
PLANNING -> DISPATCHING -> MONITORING -> CHECKPOINTING -> COMPLETE
```

| State | Entry Condition | What Happens | Exit Condition |
|-------|----------------|--------------|----------------|
| PLANNING | Session start or new work batch | Parse issues, build dependency graph, assign waves | Wave plan written to state.json |
| DISPATCHING | Wave plan ready, or previous wave complete | Spawn agents for current wave with isolation | All agents in current wave launched |
| MONITORING | All agents dispatched | Poll for agent completion, collect results. On agent failure: retry (max 2 retries), then mark work item as `failed` and continue | All agents in wave complete (success, fail, or timeout) |
| CHECKPOINTING | Context at 80%, or wave complete, or explicit request | Write full state to disk, prune context | State persisted, ready for next wave or handoff |
| COMPLETE | All waves done, all quality gates passed | Final report to user | Terminal state |

> **Note:** Recovery from agent failures is handled within the MONITORING state via the retry budget (2 retries per task). There is no separate RECOVERING state — failed tasks are retried inline or marked `failed` and the wave continues.

### State File: state.json

Canonical schema is defined in `specs/state-schema.md`. Key points:

- **Session status** uses SCREAMING_CASE: `PLANNING`, `DISPATCHING`, `MONITORING`, `CHECKPOINTING`, `COMPLETE`
- **Work item status** uses lowercase: `pending`, `dispatched`, `complete`, `failed`
- **Wave status**: `pending`, `active`, `complete`, `failed`
- **Agent status**: `running`, `complete`, `failed`
- State file lives at `~/.chief-of-staff/sessions/{session_id}/state.json`
- Session ID comes from Claude Code's native `session_id` (hook stdin). Never generated by COS.
- `vcs_type` stored at top level: `"jj"` or `"git"`
- `context` object tracks `percentage`, `last_checked`, `checkpoints[]`
- Atomic updates: read, modify in memory, write entire file. Single-writer (the orchestrator).

### Session Resumption Protocol

COS is designed for crash resilience. Agent lifecycle hooks (#37) keep `state.json` continuously current — SubagentStop updates agent/work_item status automatically, so even if the orchestrator crashes mid-session, the ledger reflects reality. Recovery is a read-from-disk operation, not reconstruction.

When resuming from a checkpoint, crash, or new session:

1. Read `state.json` from `~/.chief-of-staff/sessions/{session_id}/`
2. Parse `status` and current wave
3. Cross-reference with per-agent progress files (`agents/{id}.json`) for finer granularity
4. For each task in the current wave, check its status:
   - `dispatched` -> check if the agent branch has new commits since `started_at`. If yes, collect results. If no, treat as timed out.
   - `failed` -> retry if under budget (2 retries), otherwise skip this task
   - `complete` -> verify PR exists and is mergeable
   - `pending` -> ready for dispatch
5. Resume from the appropriate state
6. If `state.json` is missing but HANDOFF.md exists, parse the handoff document and reconstruct state

**Why this works after a crash:** Hooks (SubagentStop, TaskCompleted) write to state.json on every agent lifecycle event. The orchestrator doesn't need to be alive for state to update — hooks fire independently. Per-agent files (`agents/{id}.json`) provide an additional breadcrumb trail even if state.json missed an update.

---

## 3. Agent Dispatch Reference

### Agent Types

| Agent Type | Isolation | Model | Background | Use Case |
|-----------|-----------|-------|------------|----------|
| Research | None (read-only) | sonnet | true | Explore codebase, read issues, analyze dependencies |
| Implementation | JJ workspace or git worktree | sonnet | true | Write code, run tests, create PR |
| Review | None (read-only) | sonnet | true | Review code, review PR, check quality |

Agent definitions live in:

- `agents/researcher.md` -- codebase exploration, doc reading
- `agents/implementer.md` -- code changes with isolation
- `agents/reviewer.md` -- code review, test verification

**Wave coordinator** is not a separate agent type -- it is the orchestrator itself (opus model) operating in foreground when performing wave planning, dependency graph analysis, and cross-agent coordination.

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

Prompt templates live in:

- `templates/research-prompt.md`
- `templates/implementation-prompt.md`
- `templates/review-prompt.md`

### Isolation Strategy Selection

```
Is this a JJ repo? (test -d .jj)
  +- Yes -> Use JJ workspaces
  |         jj workspace add ~/.chief-of-staff/workspaces/item-{id}
  +- No  -> Use git worktrees
            git worktree add ~/.chief-of-staff/workspaces/item-{id} -b cos/{branch}
```

**Never run two implementation agents in the same workspace.** Research and review agents can share the main workspace since they are read-only.

### Model Selection

- **Sonnet** for all leaf-level work: implementation, review, research. Fast, cheap, and high-quality for focused tasks.
- **Opus** only when the task requires cross-cutting analysis: wave planning, dependency graph construction, resolving conflicting agent outputs, architectural decisions. Use sparingly and in foreground (blocking) mode.

---

## 4. JJ Workspace Integration

### Detection

```bash
# Check if current repo uses JJ
if [ -d ".jj" ]; then
  echo "jj"
elif [ -d ".git" ]; then
  echo "git"
else
  echo "none"
fi
```

VCS type is detected at session init by `hooks/scripts/init.sh` and stored in `state.json` under `vcs_type`.

### Workspace Lifecycle

```bash
# Create workspace for an agent
jj workspace add ~/.chief-of-staff/workspaces/item-{id}

# Agent works in the workspace
cd ~/.chief-of-staff/workspaces/item-{id}
# ... edit files ...
jj describe -m "feat: implement issue #42"
jj bookmark set feat/issue-42
jj git push --bookmark feat/issue-42 --allow-new

# After merge, clean up
jj workspace forget item-{id}
rm -rf ~/.chief-of-staff/workspaces/item-{id}
```

### JJ-Specific Patterns

**Bookmark management:**

- Each agent creates a bookmark for its work: `jj bookmark set {branch-name}`
- Push with: `jj git push --bookmark {branch-name} --allow-new`
- After PR merge, delete bookmark: `jj bookmark delete {branch-name}`

**Multi-parent merge (batching related changes):**

```bash
jj new <bookmark1> <bookmark2>
jj describe -m "merge: combine related features"
```

**Rebasing after a merge:**

```bash
jj git fetch
jj rebase -b <bookmark> -d main
```

**Conflict detection:**

```bash
jj log --revisions "conflicts()"
```

### Git Worktree Fallback

If JJ is not available, use git worktrees with equivalent patterns:

```bash
# Create worktree
git worktree add ~/.chief-of-staff/workspaces/item-{id} -b cos/{branch-name}

# Agent works in worktree
cd ~/.chief-of-staff/workspaces/item-{id}
# ... edit, commit, push ...

# After merge, clean up
git worktree remove ~/.chief-of-staff/workspaces/item-{id}
git branch -d cos/{branch-name}
```

### Workspace Path Convention

All agent workspaces are created under `~/.chief-of-staff/workspaces/`:

| Context | Path pattern |
|---------|-------------|
| Single implement item | `~/.chief-of-staff/workspaces/item-{id}` |
| Wave dispatch | `~/.chief-of-staff/workspaces/wave-{wave}-item-{id}` |
| Cleanup | `rm -rf ~/.chief-of-staff/workspaces/wave-*` or per-item |

### Isolation Rules

1. **Never dispatch two write-agents to the same workspace.** Check `agents` in state.json before dispatch.
2. **Research agents share the primary workspace.** Read-only, no conflicts.
3. **Review agents run in the primary workspace** (or in the agent's workspace if reviewing that agent's work).
4. **Workspace cleanup happens after wave completion**, not after individual agent completion. This allows re-dispatch to the same workspace on agent failure.

---

## 5. Quality Gate Injection

Quality gates ensure every agent produces work that meets project standards. The orchestrator assembles gates from multiple sources and injects them into the `{{QUALITY_GATES}}` placeholder in agent prompt templates (e.g., `templates/implementation-prompt.md`).

### Gate Sources (priority order)

1. **Project CLAUDE.md** -- read `CLAUDE.md` in the repo root for project-specific conventions, test commands, and style rules
2. **next-level config** -- if `~/.next-level/config.json` exists, read formatter, linter, and test commands per language
3. **Language defaults** -- fallback table if no config is found

### Gate Assembly

When constructing an agent prompt:

1. Read CLAUDE.md for explicit commands (e.g., "run `make lint` before committing")
2. Check `~/.next-level/config.json` for structured config
3. Fall back to language defaults (table below)
4. If the task has an associated issue, extract acceptance criteria from the issue body and include them as additional gates
5. Combine all gates into the "Quality Gates" section of the agent prompt template

### Language Default Gates

| Language | Formatter | Linter | Test |
|----------|-----------|--------|------|
| TypeScript | `npx prettier --write .` | `npx eslint .` | `npm test` |
| Python | `ruff format .` | `ruff check .` | `pytest` |
| Go | `gofmt -w .` | `go vet ./...` | `go test ./...` |
| Rust | `cargo fmt` | `cargo clippy` | `cargo test` |
| Swift | `swift-format -r -i .` | `swiftlint` | `swift test` |

### File Length Enforcement

If `max_file_length` is configured (or defaults to 300 lines):

- Include in agent prompt: "No single file should exceed {N} lines. Split into modules if needed."
- Review agents should flag files exceeding the limit.

---

## 6. Cross-Plugin Routing and Consolidation

Chief-of-staff is on a consolidation path to become the single development workflow plugin (see #38). Over time, COS absorbs quality enforcement (from next-level), prek integration (#36), and agent lifecycle hooks (#37). During this transition, COS detects sibling plugins at session init and routes work to them when appropriate. Installed plugins are stored in `state.json` under `installed_plugins`.

### Detection Matrix

| Signal | Route To | Why |
|--------|----------|-----|
| User says "review this PR" or provides PR URL | `/cycle:pr` | Cycle handles PR review orchestration with CodeRabbit awareness |
| Task requires spec extraction before implementation | `/repo-clone` spec stages | repo-clone has behavioral spec extraction methodology |
| User wants a spec-driven build loop | `/ralph-loop` or `/repo-clone` build stage | Ralph loop handles iterative single-task-per-iteration builds |
| Multiple independent issues to implement | Chief-of-staff wave dispatch | This is the core use case -- parallel multi-issue orchestration |
| Single issue, straightforward implementation | Direct agent dispatch | No plugin overhead needed for simple tasks |
| User says "port this to {language}" | `/repo-clone init` | repo-clone handles cross-language porting |

### Routing Decision Tree

```
User request arrives
  +- Is it a PR review? -> /cycle:pr
  +- Is it a codebase port? -> /repo-clone
  +- Is it a single, small task? -> Direct agent (no plugin)
  +- Does it require a spec-first approach?
  |   +- Yes, single module -> /ralph-loop or /spec workflow
  |   +- Yes, many modules -> chief-of-staff with spec extraction wave
  +- Is it multiple tasks/issues?
      +- chief-of-staff wave coordination
```

### Composing Plugins Within Waves

The chief-of-staff can compose plugins within a wave pipeline:

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

| Problem | Detection | Resolution |
|---------|-----------|------------|
| Agent stuck (no output 5+ min) | Timeout exceeded, no new commits on branch | Cancel agent. Re-dispatch with reduced scope. |
| Quality gate fails | CI red, linter errors, test failures | Re-dispatch into same workspace with gate instructions and failure output. |
| Merge conflict | `git merge --no-commit` fails or JJ reports conflicts | Serialize remaining work on conflicting files. Resolve manually or dispatch resolution agent. |
| Context at 90% | Context percentage monitor | Checkpoint immediately. Write HANDOFF.md. Exit session gracefully. |
| Agent produces wrong output | Review agent flags issues, or PR review catches problems | Discard agent's branch. Re-dispatch with clearer instructions and examples. |
| PR review requests large refactor | Review comments suggest architectural changes | Create follow-up issue. Keep current PR focused. Note refactor for future wave. |
| JJ workspace corruption | `jj workspace list` shows stale entries | `jj workspace forget {id}`, remove directory, re-dispatch. |
| Git worktree in bad state | `git worktree list` shows inconsistencies | `git worktree remove --force {path}`, `git worktree prune`, recreate. |

### Recovery Protocol

When an agent fails:

1. **Assess impact.** Does this block other tasks in the current wave? Does it block future waves?
2. **Classify severity:**
   - **Retriable:** Quality gate failure, timeout, transient error -> re-dispatch with adjustments
   - **Skippable:** Non-critical task, no dependents -> mark as skipped, continue
   - **Blocking:** Critical path task with dependents -> must resolve before proceeding
3. **Act:**
   - Retriable: Re-dispatch with reduced scope, explicit instructions, and the error output for context. Max 2 retries per task.
   - Skippable: Mark task as `failed` in state.json with reason. Update dependency graph.
   - Blocking: Escalate to user with a clear summary: what failed, why, what options exist.

### Retry Budget

- Each task gets a maximum of **2 retries** (3 total attempts)
- After 3 failures: mark as `failed`, notify user, move on
- Each wave gets a maximum of **1 full re-dispatch** (if >50% of tasks fail, re-plan the wave rather than retrying individual tasks)
- Retry count is tracked via the number of agents in the `agents` map that reference the same `work_item_id`

---

## 8. Wave Planning Algorithm

### Input

A list of work items (issues, tasks, or feature descriptions).

### Step 1: Fetch Details

For each work item:

- If GitHub issue: `gh issue view {number} --json title,body,labels,assignees`
- If PR: `gh pr view {number} --json title,body,files`
- If text description: parse directly

Extract:

- **Files likely touched** (from issue body, PR files, or inference from description)
- **Dependencies** (explicit: "depends on #N", or implicit: shared files/modules)
- **Complexity estimate** (small: 1-2 files, medium: 3-5 files, large: 6+ files)

### Step 2: Build Dependency Graph

```
For each pair of tasks (A, B):
  file_overlap = files_touched(A) intersection files_touched(B)
  if file_overlap is not empty:
    # These tasks conflict -- cannot be in the same wave
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
    # Circular dependency -- break the cycle
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
- List of task item IDs
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
  | user request arrives
PLAN -> dispatch background agents -> IDLE
  | agent result arrives
REVIEW -> merge/coordinate -> dispatch next wave or report -> IDLE
  | user input arrives while agents running
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

---

## 10. Agent Design Philosophy

### Agents Are Dynamic Compositions, Not Fixed Scripts

The pre-defined agent types (researcher, implementer, reviewer) are **role cards** — lean identities with output format contracts. They are NOT the full instructions an agent receives.

The actual agent prompt is **composed at dispatch time**:

```
┌─────────────────────────────────────────────┐
│           Composed Agent Prompt             │
├─────────────────────────────────────────────┤
│ 1. Role identity (from agents/*.md)         │
│    - Who you are, hard constraints          │
│    - Output format (=== REPORT ===)         │
│                                             │
│ 2. Task context (from templates/*.md)       │
│    - {{ISSUE_BODY}}, {{ACCEPTANCE_CRITERIA}}│
│    - {{WORKSPACE_PATH}}, {{VCS_TYPE}}       │
│    - Workflow steps, MUST-complete checklist │
│                                             │
│ 3. Conventions (from templates/conventions) │
│    - {{FORMATTERS}}, {{LINTERS}}            │
│    - {{TEST_COMMANDS}}, {{COMMIT_STYLE}}    │
│                                             │
│ 4. Quality gates (injected inline)          │
│    - Project-specific gates from CLAUDE.md  │
│    - Language defaults if no config         │
└─────────────────────────────────────────────┘
```

### Why This Matters

**The 3 pre-defined agents are starting archetypes, not a fixed menu.** The orchestrator can compose entirely custom agents:

- A "migration agent" for database schema changes
- A "docs agent" for documentation updates
- A "benchmark agent" for performance testing
- A "security agent" for vulnerability scanning

To dispatch a custom agent, compose the prompt inline — no agent definition file needed:

```
Agent tool call:
  description: "Run security audit on auth module"
  prompt: <custom prompt with task details, output format, constraints>
  subagent_type: "general-purpose"
  model: sonnet
  run_in_background: true
```

### Keeping Agents Lean

Agent definitions should contain ONLY:

- **Role identity** (1-2 sentences: who you are)
- **Hard constraints** (what NOT to do)
- **Output format** (=== REPORT === delimiters, required fields)

Everything else belongs in the **template** (filled at dispatch time) or the **conventions** (project-specific). This keeps agents reusable across projects and tasks.

### Per-Project Setup

Quality gates and conventions vary by language and project. The orchestrator detects these at dispatch time:

| Language | Formatter | Linter | Test Command |
|----------|-----------|--------|-------------|
| TypeScript | prettier | eslint | npm test |
| Python | ruff format | ruff check | pytest |
| Go | gofmt | golangci-lint | go test ./... |
| Rust | cargo fmt | cargo clippy | cargo test |
| Swift | swiftformat | swiftlint | swift test |

These are injected into `{{QUALITY_GATES}}` and `{{CONVENTIONS}}` placeholders. If a project has a CLAUDE.md or next-level config, those take priority over defaults.

For project-specific setup (e.g., a Rust project with custom benchmark gates):

```toml
# Example: what COS reads from project context
[quality-gates]
fmt = "cargo fmt --all -- --check"
lint = "cargo clippy --all-targets --all-features -- -D warnings"
test = "cargo test --all-features"
benchmark = "cargo run --release --bin locomo_bench -- --samples 2"
```

The orchestrator reads this from CLAUDE.md or project config and injects it into every agent prompt automatically.
