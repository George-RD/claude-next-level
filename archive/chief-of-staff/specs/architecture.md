# Chief of Staff — Architecture Spec

> **Plugin**: chief-of-staff v1.0.0
> **Alias**: cos
> **Role**: Meta-orchestrator that composes existing plugins (cycle/, ralph-wiggum/, next-level/team-execute) to coordinate concurrent workflows, manage agent health, and handle unified context handoff.

---

## 1. Plugin Manifest

```json
{
  "name": "chief-of-staff",
  "description": "Meta-orchestrator for Claude Code: coordinates concurrent workflows across plugins (cycle, ralph-wiggum, team-execute), manages agent waves, tracks session state, and provides unified context handoff. Short alias: /cos.",
  "version": "1.0.0",
  "author": {
    "name": "George-RD"
  },
  "keywords": ["orchestrator", "meta", "coordination", "agents", "waves", "handoff", "session", "dispatch", "cos"]
}
```

---

## 2. Directory Structure

```text
chief-of-staff/
  plugin.json                              # Plugin manifest (content above)
  specs/
    architecture.md                        # This file
  commands/
    cos.md                                 # /cos — main entry point, session init + routing
    research.md                            # /cos:research — spawn research agents
    implement.md                           # /cos:implement — spawn implementation agents
    review.md                              # /cos:review — spawn review agents
    wave.md                                # /cos:wave — execute a wave of agents
    status.md                              # /cos:status — session dashboard
    # Note: handoff is handled automatically by checkpoint.sh (PreCompact + Stop hooks)
  skills/
    cos/
      SKILL.md                             # Domain knowledge: dispatch patterns, state management, isolation
  agents/
    researcher.md                          # Agent type: codebase exploration, doc reading
    implementer.md                         # Agent type: code changes (wraps coding-agent patterns)
    reviewer.md                            # Agent type: code review, test verification
  templates/
    research-prompt.md                     # Prompt template for research agents
    implementation-prompt.md               # Prompt template for implementation agents
    review-prompt.md                       # Prompt template for review agents
    conventions.md                         # Dynamic project conventions, injected via {{CONVENTIONS}}
    implementation-prompt.md ({{QUALITY_GATES}} placeholder)              # Quality gate fragment appended to agent prompts
    handoff-resume.md                      # Template for session resume prompts
  hooks/
    hooks.json                             # Hook definitions (session init, checkpoint, etc.)
    scripts/
      init.sh                              # Create session directory, initialize state.json, detect VCS
      checkpoint.sh                        # State persistence at context thresholds
      utils.sh                             # Shared hook utilities
```

---

## 3. Architecture Overview

### 3.1 Layer Model

```text
┌─────────────────────────────────────────────────┐
│                    USER                          │
│              /cos, /cos:implement, etc.          │
├─────────────────────────────────────────────────┤
│              CHIEF OF STAFF                      │
│  Session state │ Wave coordinator │ Agent health  │
├─────────────────────────────────────────────────┤
│              COMPOSED PLUGINS                    │
│  ┌───────────┐ ┌──────────────┐ ┌─────────────┐ │
│  │  cycle/   │ │ ralph-wiggum/│ │ next-level/ │ │
│  │  PR review│ │ spec-driven  │ │ team-execute│ │
│  │  lifecycle│ │ build loops  │ │ parallel    │ │
│  └───────────┘ └──────────────┘ └─────────────┘ │
├─────────────────────────────────────────────────┤
│              ISOLATION LAYER                     │
│  JJ workspaces (preferred) │ git worktrees      │
└─────────────────────────────────────────────────┘
```

### 3.2 What Chief of Staff Does

Chief of staff is a **coordinator, not a reimplementation**. It never duplicates logic that already exists in the composed plugins. Instead it:

1. **Sequences workflows across plugins.** Example: run ralph-wiggum to build a feature, then cycle to shepherd its PR — as a single orchestrated flow.
2. **Manages concurrent agents.** Tracks which agents are running, in what isolation context, with what status. Prevents resource conflicts (two agents writing to the same worktree).
3. **Coordinates waves.** Groups independent work units into waves, dispatches them in parallel, gates the next wave on the previous wave's completion.
4. **Maintains session state.** Persists agent status, wave progress, and context usage to disk so that sessions can be resumed after compaction or restart.
5. **Injects quality gates.** Appends quality-gate fragments to agent prompts using templates rather than hardcoding checks. Different workflows get different gate configurations.
6. **Provides unified status.** Single `/cos:status` command shows all active workflows, agents, and their states regardless of which plugin is running them.

### 3.3 What Chief of Staff Does NOT Do

- Does not replace `/cycle:pr` — delegates to it.
- Does not replace `/ralph-wiggum:build` — delegates to it.
- Does not replace `/next-level:team-execute` — delegates to it.
- Does not implement its own TDD enforcement, linting, or verification guards — those stay in next-level hooks.
- Does not implement conflict detection between agents (deferred to v2).
- Does not provide a dashboard UI (deferred).
- Does not adaptively resize teams (deferred).

### 3.4 Relationship to Existing Plugins

| Plugin | How COS uses it | Integration point |
|--------|----------------|-------------------|
| `cycle/` | Delegates PR review workflows | `/cos:review` can dispatch `/cycle:pr` in a background agent with worktree isolation |
| `ralph-wiggum/` | Delegates spec-driven build loops | `/cos:implement` can set up and launch ralph loops, tracking iteration state |
| `next-level/team-execute` | Delegates parallel task execution | `/cos:wave` uses the same wave/checkpoint model but adds cross-plugin coordination |
| `next-level/` (hooks) | Quality gates injected via templates | COS reads next-level hook configs to build quality-gate fragments for agent prompts |
| `jj-commands/` | Isolation layer | COS uses JJ workspace commands when available, falls back to git worktree |

---

## 4. State Management Design

### 4.1 State Directory

```text
~/.chief-of-staff/
  config.json                           # Global configuration (optional)
  sessions/
    {session-id}/                       # session-id = Claude Code native ID
      state.json                        # Live session state
      checkpoint.json                   # Snapshot (written at PreCompact/Stop)
      agents/
        {agent-id}.json                 # Per-agent detailed state
  workspaces/                           # Isolated agent workspaces
    item-1/
    wave-2-item-3/
```

Session IDs use Claude Code's native `session_id` (delivered via hook stdin). COS never generates its own session IDs.

### 4.2 state.json Schema

> **Canonical schema**: See [specs/state-schema.md](state-schema.md) for the full schema definition, field reference, status enums, state transitions, and examples.

Key points:

- **Session status** uses SCREAMING_CASE: `PLANNING`, `DISPATCHING`, `MONITORING`, `CHECKPOINTING`, `COMPLETE`.
- **Work item status** uses lowercase: `pending`, `dispatched`, `complete`, `failed`.
- **Waves** are an array of objects with a `number` field.
- **Agents** are an object keyed by agent-id with `name`, `type`, `status`, `work_item_id`, `workspace_path`, `started_at`, `completed_at`.
- **Work items** are an array of objects with full detail: `issue`, `pr_number`, `workspace`, `workspace_type`, `branch`, `error`.
- **VCS type** is stored as `vcs_type` at the top level.
- **Context tracking** uses a `context` object with `percentage`, `last_checked`, and `checkpoints[]`.
- **Retry budget**: 2 retries (3 total attempts) per work item.
- **Wave cap**: 4 agents per wave (configurable via `config.json`).

### 4.3 State Update Rules

- **state.json is updated synchronously** by the COS orchestrator (primary context window). Agents never write to state.json.
- **Agent result files** (`agents/{agent-id}.json`) are written by COS when an agent returns. These contain the full agent output for reference.
- **context.percentage** is updated after each agent returns. If it crosses the checkpoint threshold (default 80%), COS triggers an automatic handoff.
- **Atomic updates**: COS reads state.json, modifies in memory, writes the entire file. No partial updates. Simple and correct for single-writer.

---

## 5. Isolation Model

### 5.1 Decision Matrix

| Agent type | Modifies files? | Isolation required? | Strategy |
|-----------|-----------------|--------------------|---------|
| Research | No (read-only) | No | None — runs in repo root |
| Implement | Yes | Yes | JJ workspace (preferred) or git worktree |
| Review | No (read-only) | No | None — runs in repo root |
| PR fix | Yes | Yes | Git worktree (cycle/ convention) |
| Ralph loop | Yes | Yes | JJ workspace or git worktree |

### 5.2 JJ Workspaces (Preferred)

When the project uses Jujutsu (`test -d .jj`):

```bash
# Create workspace for an agent
jj workspace add ~/.chief-of-staff/workspaces/item-{id}

# Agent works in the workspace
cd ~/.chief-of-staff/workspaces/item-{id}
# ... make changes ...
jj describe -m "agent work"

# After agent completes, merge from primary workspace
cd /path/to/primary
jj new {agent-change-id}  # or squash into current change
```

**Advantages over git worktrees:**

- No branch name conflicts
- Undo is trivial (`jj undo`)
- Workspaces share the operation log — COS can inspect agent progress from the primary workspace
- No stale worktree cleanup needed

### 5.3 Git Worktrees (Fallback)

When the project uses git (no `.jj` directory):

```bash
# Create worktree for an agent
git worktree add ~/.chief-of-staff/workspaces/item-{id} -b cos/{branch-name}

# Agent works in the worktree
cd ~/.chief-of-staff/workspaces/item-{id}
# ... make changes, commit, push ...

# After agent completes, merge from primary
cd /path/to/primary
git merge cos/{branch-name}

# Cleanup
git worktree remove ~/.chief-of-staff/workspaces/item-{id}
git branch -d cos/{branch-name}
```

### 5.4 Detection Script

VCS detection runs at session init (inline in `hooks/scripts/init.sh`):

```bash
#!/usr/bin/env bash
# Outputs: "jj" | "git" | "none"
if [ -d ".jj" ]; then
  echo "jj"
elif [ -d ".git" ]; then
  echo "git"
else
  echo "none"
fi
```

COS stores the result in `state.json` under `vcs_type` (top-level field) and uses it when dispatching implementation agents.

### 5.5 Isolation Rules

1. **Never dispatch two write-agents to the same workspace.** COS checks `agents` in state.json before dispatch.
2. **Research agents share the primary workspace.** They are read-only and do not conflict.
3. **Review agents run in the primary workspace** (or in the agent's workspace if reviewing that agent's work).
4. **Workspace cleanup happens after wave completion**, not after individual agent completion. This allows re-dispatch to the same workspace on agent failure.

---

## 6. Command Specifications

### 6.1 /cos — Main Entry Point

**Purpose**: Initialize a session and route to the appropriate workflow.

```yaml
name: cos
description: "Meta-orchestrator: initialize a coordination session, or route to a sub-command. Start here for multi-agent workflows."
argument-hint: "[research|implement|review|wave|status|handoff] or describe what you want to do"
```

**Behavior**:

1. If arguments match a sub-command name, route to that command.
2. If arguments describe a task (natural language), analyze the task and recommend a workflow:
   - "Build feature X" → research → implement → review pipeline
   - "Review PR 42" → delegate to `/cycle:pr 42`
   - "Port module Y" → delegate to ralph-wiggum or repo-clone
3. If no arguments, show session status (delegates to `/cos:status`).
4. On first invocation in a session, run `hooks/scripts/init.sh` to create state directory and state.json.

### 6.2 /cos:research — Spawn Research Agents

**Purpose**: Dispatch background agents to explore the codebase and return structured findings.

```yaml
name: research
description: "Spawn research agents to explore codebase, read docs, or analyze architecture. Results feed into implementation planning."
argument-hint: "<what to research>"
```

**Behavior**:

1. Parse the research objective from arguments.
2. Break the objective into independent research questions (max 4 agents, configurable via `config.json`).
3. For each question, dispatch a background agent using the `researcher` type:
   - `run_in_background: true`
   - No isolation (read-only)
   - Prompt includes: research question, relevant file paths (if known), output format instructions
4. Register each agent in state.json.
5. Report dispatch summary to user.
6. When agents return, synthesize findings and present a consolidated research brief.

### 6.3 /cos:implement — Spawn Implementation Agents

**Purpose**: Dispatch implementation agents with proper isolation.

```yaml
name: implement
description: "Spawn implementation agents in isolated workspaces. Supports parallel independent tasks or sequential dependent chains."
argument-hint: "<tasks to implement | issue numbers | epic name>"
```

**Behavior**:

1. Parse implementation scope from arguments.
2. Build dependency graph for tasks.
3. Group into waves (independent tasks per wave).
4. For each task in the current wave:
   - Create an isolated workspace (JJ or git worktree)
   - Dispatch background agent using the `implementer` type
   - Inject quality gates from `templates/implementation-prompt.md ({{QUALITY_GATES}} placeholder)`
   - Register in state.json
5. When wave completes, run gate check (tests pass in all workspaces).
6. If gate passes, merge agent work into primary and dispatch next wave.
7. If gate fails, report failures and either retry or escalate.

### 6.4 /cos:review — Spawn Review Agents

**Purpose**: Dispatch review agents for code review, test verification, or PR lifecycle.

```yaml
name: review
description: "Spawn review agents for code quality, test verification, or PR lifecycle management. Can delegate to /cycle:pr."
argument-hint: "<what to review | PR numbers>"
```

**Behavior**:

1. If arguments contain PR numbers, delegate to `/cycle:pr`.
2. If arguments describe a code review task:
   - Dispatch a review agent with relevant file paths and review criteria
   - Agent reads code, checks for issues, returns structured findings
3. Register agents in state.json.

### 6.5 /cos:wave — Execute a Wave

**Purpose**: Manually execute a specific wave of agents.

```yaml
name: wave
description: "Execute a wave of parallel agents. Use within a multi-wave workflow or standalone for ad-hoc parallel dispatch."
argument-hint: "<wave-description or wave-number>"
```

**Behavior**:

1. If a wave number is given, execute that wave from the current session plan.
2. If a description is given, parse it into parallel tasks and dispatch.
3. All agents in a wave run concurrently.
4. Wave completes when all agents return.
5. Gate check runs automatically at wave completion.

### 6.6 /cos:status — Session Dashboard

**Purpose**: Display current session state — agents, waves, context usage.

```yaml
name: status
description: "Show session dashboard: active agents, wave progress, context usage, workflow state."
allowed-tools: ["Bash(cat ~/.chief-of-staff/sessions/*/state.json 2>/dev/null | head -200)"]
```

**Behavior**:

1. Read state.json for the active session.
2. Display formatted dashboard:

```text
COS SESSION: {session-id}
════════════════════════════════════════════════
Workflow: research → implement → review
Phase:    implement (wave 2 of 3)
Context:  42% used (checkpoint at 80%)

WAVE 1 — completed ✓
  agent-research-001  research   completed   "Auth module structure"
  agent-research-002  research   completed   "API endpoint inventory"

WAVE 2 — in progress
  agent-impl-001      implement  running     "User registration"
  agent-impl-002      implement  running     "JWT middleware"
  agent-impl-003      implement  completed   "Database schema"

WAVE 3 — planned
  agent-review-001    review     queued      "Integration test suite"
════════════════════════════════════════════════
```

### 6.7 /cos:handoff — Context Checkpoint

**Purpose**: Save session state for resumption in a new context window.

```yaml
name: handoff
description: "Checkpoint current session: save state, generate resume prompt, prepare for new context window."
argument-hint: "[--reason <why>]"
```

**Behavior**:

1. Snapshot current state.json.
2. Collect results from all completed agents.
3. Summarize work done and work remaining.
4. Generate resume prompt from `templates/handoff-resume.md`:
   - Session ID and state path
   - Completed phases/waves
   - In-progress agent tasks
   - Key decisions made during session
   - Exact next steps
5. Write resume prompt to `~/.chief-of-staff/sessions/{id}/handoff/resume.md`.
6. Store handoff in omega memory with `session-handoff` tag.
7. Tell the user to run `/cos` with the session ID in the new session.

---

## 7. Agent Type Specifications

### 7.1 researcher

```yaml
# agents/researcher.md frontmatter
name: researcher
subagent_type: general-purpose
model: sonnet
```

**Prompt structure**:

- Research question
- Scope constraints (directories to search, file types)
- Output format: structured markdown with file paths and citations
- Time budget: terminate after answering the question, do not explore tangentially

### 7.2 implementer

```yaml
# agents/implementer.md frontmatter
name: implementer
subagent_type: general-purpose
model: sonnet
mode: bypassPermissions
```

**Prompt structure**:

- Task description with acceptance criteria
- Working directory (isolated workspace path)
- Test command
- Quality gate injection (appended from template)
- Mandatory completion steps: implement, test, commit

### 7.3 reviewer

```yaml
# agents/reviewer.md frontmatter
name: reviewer
subagent_type: general-purpose
model: sonnet
```

**Prompt structure**:

- What to review (file paths, diff, or PR number)
- Review criteria (correctness, tests, style, integration)
- Output format: per-file verdicts (PASS, FLAG, BLOCK) with rationale
- Verdict: CONTINUE, FLAG_FOR_HUMAN, or STOP

---

## 8. Quality Gate Injection

Quality gates are **not hardcoded** in COS. They are composed from templates and injected into agent prompts at dispatch time.

### 8.1 Template: implementation-prompt.md ({{QUALITY_GATES}} placeholder)

```markdown
## Quality Requirements (Injected by COS)

Before reporting completion, you MUST verify:

{{#if tdd}}
- [ ] All new code has corresponding tests
- [ ] Tests pass: `{{test_command}}`
{{/if}}

{{#if lint}}
- [ ] No lint errors: `{{lint_command}}`
{{/if}}

{{#if build}}
- [ ] Build succeeds: `{{build_command}}`
{{/if}}

{{#if integration}}
- [ ] Integration with existing code verified — no broken imports or missing dependencies
{{/if}}

If any gate fails, fix the issue before reporting completion. If you cannot fix it after 2 attempts, report the failure with details.
```

### 8.2 Gate Configuration

COS reads gate configuration from the project. Sources, in priority order:

1. `AGENTS.md` in the project root (ralph-wiggum convention)
2. `package.json` scripts (for Node projects)
3. `Makefile` / `Justfile` targets
4. Explicit user input at session init

The gate config is stored in `state.json` under `project.test_command` and `project.build_command`.

---

## 9. Workflow Patterns

### 9.1 Research-Implement-Review Pipeline

The default COS workflow for feature development:

```text
/cos "Build user authentication"
  │
  ├─ WAVE 1: Research (parallel, no isolation)
  │   ├─ agent: explore existing auth patterns
  │   ├─ agent: read relevant specs/docs
  │   └─ agent: check test coverage baseline
  │
  ├─ SYNTHESIZE: COS merges research findings → implementation plan
  │
  ├─ WAVE 2: Implement (parallel, isolated workspaces)
  │   ├─ agent: implement auth module (jj workspace)
  │   ├─ agent: implement JWT middleware (jj workspace)
  │   └─ agent: implement DB schema migration (jj workspace)
  │
  ├─ GATE: merge all workspaces, run full test suite
  │
  ├─ WAVE 3: Review (parallel, no isolation)
  │   ├─ agent: code review all changes
  │   └─ agent: security review auth implementation
  │
  └─ COMPLETE: commit, create PR, optionally delegate to /cycle:pr
```

### 9.2 Ralph Loop Delegation

When the task is spec-driven and benefits from iterative refinement:

```text
/cos "Port parser module to Go"
  │
  ├─ Detect: spec-driven task → delegate to ralph-wiggum
  ├─ Initialize: /ralph-wiggum:init with COS tracking
  ├─ Monitor: COS tracks ralph iteration state via IMPLEMENTATION_PLAN.md
  ├─ Checkpoint: COS intervenes at context threshold
  └─ Handoff: COS generates unified resume prompt
```

### 9.3 PR Batch Review

When the task is PR review:

```text
/cos "Review all open PRs"
  │
  ├─ Detect: PR task → delegate to cycle
  ├─ Dispatch: /cycle:pr --all in background agent
  ├─ Monitor: COS tracks PR states from state.json
  └─ Report: unified status across all PRs
```

---

## 10. Error Handling

### 10.1 Agent Failures

| Failure mode | Detection | Recovery |
|-------------|-----------|----------|
| Agent stops without completing | Agent returns but task not marked done | Re-dispatch with explicit completion instructions |
| Agent crashes | Background task error | Log error, re-dispatch (max 2 retries, 3 total attempts) |
| Agent produces bad output | Review agent flags issues | Re-dispatch with corrective feedback |
| Agent exceeds time budget | Timeout on background task | Kill agent, mark task as timed out, re-dispatch or escalate |
| Workspace conflict | Two agents assigned same workspace | Block second agent until first completes (prevented by dispatch rules) |

### 10.2 Session Failures

| Failure mode | Detection | Recovery |
|-------------|-----------|----------|
| Context window approaching limit | `context.percentage` exceeds checkpoint threshold (default 80%) | Auto-trigger `/cos:handoff` |
| State file corruption | JSON parse error on state.json read | Fall back to last agent result files, reconstruct state |
| VCS operation fails | Non-zero exit from jj/git commands | Log error, retry once, escalate to user |
| Plugin not available | Command routing fails | Fall back to direct agent dispatch without plugin delegation |

### 10.3 Escalation Policy

COS escalates to the user (stops and asks) only when:

1. An agent has failed 3 times on the same task (3 total attempts = 1 initial + 2 retries)
2. A wave gate check fails and the failure is not auto-recoverable
3. Context usage exceeds 90% (hard limit — must handoff)
4. Merge conflicts between agent workspaces that require human judgment
5. A review agent returns STOP verdict

COS does NOT stop to ask for:

- Normal wave transitions
- Successful agent completions
- Auto-recoverable failures (retry handles it)
- Status updates (user can check `/cos:status` when they want)

---

## 11. MVP Scope Boundaries

### 11.1 In Scope for v1.0

| Feature | Priority | Description |
|---------|----------|-------------|
| Session state management | P0 | state.json creation, reading, updating via scripts |
| Agent dispatch | P0 | Background agent spawn with proper isolation |
| Wave coordination | P0 | Group agents into waves, gate between waves |
| Status dashboard | P0 | `/cos:status` reads state.json and formats output |
| Unified handoff | P0 | `/cos:handoff` generates resume prompt from session state |
| Research-implement-review pipeline | P1 | Default workflow pattern with 3 wave types |
| Quality gate injection | P1 | Template-based gate injection into agent prompts |
| JJ workspace isolation | P1 | Create/manage JJ workspaces for implementation agents |
| Git worktree fallback | P1 | Fall back to git worktrees when JJ not available |
| Plugin delegation | P1 | Route to cycle/, ralph-wiggum/ when appropriate |
| Omega memory integration | P2 | Store/recall session context via automem |

### 11.2 Deferred to v2.0+

| Feature | Reason for deferral |
|---------|-------------------|
| Conflict detection between agents | Requires file-level dependency analysis — significant complexity |
| Adaptive team sizing | Needs telemetry data from v1 usage to calibrate |
| Dashboard UI | Terminal UI adds dependency complexity; text dashboard sufficient for v1 |
| Cross-session agent reuse | Agents are currently stateless; adding persistence changes the model |
| Cost tracking | Requires API-level integration not available in plugin layer |
| Parallel ralph loops | Ralph's single-iteration model needs adaptation for true parallelism |
| Auto-retry with modified strategy | v1 retries with same prompt; v2 could analyze failure and adjust |

### 11.3 Implementation Order

Build in this sequence to have a working system at each step:

1. **hooks/scripts/init.sh + hooks/scripts/utils.sh** — state management foundation
2. **hooks/hooks.json** — hook definitions
3. **commands/cos.md + commands/status.md** — entry point and status display
4. **agents/researcher.md** — simplest agent type (read-only, no isolation)
5. **commands/research.md** — first dispatch command
6. **templates/implementation-prompt.md ({{QUALITY_GATES}} placeholder) + templates/conventions.md** — prompt templates
7. **agents/implementer.md** — implementation agent with isolation
8. **commands/implement.md** — implementation dispatch with wave support
9. **commands/wave.md** — explicit wave execution
10. **agents/reviewer.md + commands/review.md** — review pipeline
11. **commands/handoff.md + templates/handoff-resume.md** — context continuity
12. **skills/cos/SKILL.md** — domain knowledge consolidation
13. **plugin.json + marketplace registration** — packaging

---

## 12. Key Design Decisions

### 12.1 Composition Over Reimplementation

COS delegates to existing plugins rather than absorbing their logic. This means:

- cycle/ owns PR review patterns — COS dispatches to it
- ralph-wiggum/ owns spec-driven loops — COS dispatches to it
- next-level/ owns quality hooks — COS reads their configs

**Rationale**: Existing plugins are stable and tested. Reimplementing their logic would create maintenance burden and divergence risk.

### 12.2 JSON State, Not Markdown State

Ralph-wiggum uses IMPLEMENTATION_PLAN.md (markdown) as state. COS uses state.json (JSON).

**Rationale**: COS state is read/written programmatically by scripts. JSON is unambiguous to parse. Markdown state works for ralph because humans read and edit it between iterations. COS state is machine-primary.

### 12.3 Templates Over Hardcoded Gates

Quality gates are injected via mustache-style templates, not hardcoded in agent dispatch logic.

**Rationale**: Different projects have different quality requirements. Templates let the user (or project config) control what gates apply. Adding a new gate type requires only a template change, not a code change.

### 12.4 Waves as First-Class Concept

A "wave" is a set of agents dispatched together with a gate check at completion. This is the core coordination primitive.

**Rationale**: Waves map naturally to dependency graphs (wave 1 = leaves, wave 2 = depends on wave 1, etc.). They provide natural checkpoints for context management and error handling. The team-execute skill already uses this pattern — COS generalizes it.

### 12.5 Session-Based, Not Global

COS state is per-session, not global. Each `/cos` invocation starts a new session (or resumes an existing one).

**Rationale**: Concurrent COS sessions working on different tasks should not interfere. Per-session state also makes cleanup simple (delete the session directory).
