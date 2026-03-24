# Chief-of-Staff: Commands Spec

Chief-of-staff is a meta-orchestrator plugin for Claude Code. It coordinates multiple concurrent workflows by dispatching agents, tracking their status, and driving work to completion. The plugin sits above existing plugins:

- **cycle/** for PR review lifecycle (`/cycle:pr`)
- **ralph-wiggum/** for spec-driven development loops (`/ralph-wiggum:build`)
- **next-level/team-execute** for parallel task execution

All state is persisted to `~/.chief-of-staff/sessions/{session-id}/state.json`.

---

## 1. /cos

---
name: cos
description: "Parse a work description, analyze dependencies, route to workflows, dispatch agents in waves."
argument-hint: '"build feature X, review PRs 42-44, port module Y"'
allowed-tools:

- Bash
- Read
- Write
- Edit
- Glob
- Grep
- Agent

---

### Description

Main entry point. Accepts a natural-language work description containing one or more work items. Parses them, determines dependencies, routes each to the appropriate workflow, and dispatches Wave 1 agents.

### Usage

```bash
/cos "build feature X, review PRs 42-44, port module Y"
/cos "implement #18, #12 depends on #18, review PR #55"
/cos "research caching strategies, then implement #22"
```

### Input Parsing

1. **Split work items.** Parse the description into discrete work items. Delimiters: commas, "and", "then", semicolons. Each item becomes a node in the dependency graph.

2. **Classify each work item** by scanning for keywords:

   | Pattern | Workflow | Route to |
   |---------|----------|----------|
   | `review PR #N`, `review PRs N-M` | PR review | `/cos:review` |
   | `build`, `implement`, `create`, `add`, `fix` + `#issue` or description | Implementation | `/cos:implement` |
   | `research`, `explore`, `investigate`, `analyze` | Research | `/cos:research` |
   | `port`, `migrate`, `clone` + module/repo reference | Porting | `repo-clone` plugin |
   | `spec`, `design`, `plan` | Spec-driven dev | `ralph-wiggum` plugin |

3. **Extract identifiers.** Pull out issue numbers (`#N`), PR numbers (`PR #N`, `PR N`), branch names, file paths, and free-text descriptions.

4. **Validate identifiers.** For each issue number:

   ```bash
   gh issue view <N> --json number,title,state,body,labels,assignees
   ```

   For each PR number:

   ```bash
   gh pr view <N> --json number,title,state,headRefName,url
   ```

   If an identifier doesn't exist, report the error and exclude it from the plan. Continue with valid items.

### Dependency Analysis

1. **Detect explicit dependencies.** Keywords: "depends on", "after", "then", "once X is done", "blocked by", "requires". Build a directed acyclic graph (DAG).

2. **Detect implicit dependencies.** If two work items reference the same files or module, they cannot run in parallel. Use heuristics:
   - Same issue label or milestone suggests coupling
   - "implement X" followed by "review X" implies sequence
   - Research items feeding into implementation items implies sequence

3. **Topological sort.** Order the DAG into waves:
   - **Wave 1**: All items with no unmet dependencies (root nodes)
   - **Wave N**: Items whose dependencies were all in waves 1..N-1

4. **Validate the graph.** If cycles are detected, report them to the user and ask for clarification.

### Session Initialization

1. **Use the Claude Code session ID.** The session ID is Claude Code's native `session_id`, available from the SessionStart hook stdin. If `/cos` is invoked before the hook runs, read it from the existing `state.json` or fall back to a generated UUID.

2. **Create session directory and state file.**

    ```bash
    mkdir -p ~/.chief-of-staff/sessions/{session-id}
    ```

3. **Write initial state.** Create `~/.chief-of-staff/sessions/{session-id}/state.json` following the [canonical schema](state-schema.md):

    ```json
    {
      "session_id": "<claude-code-native-session-id>",
      "created_at": "2026-03-17T14:30:22Z",
      "updated_at": "2026-03-17T14:30:22Z",
      "vcs_type": "jj",
      "installed_plugins": ["cycle", "ralph-wiggum", "next-level"],
      "status": "PLANNING",
      "work_items": [
        {
          "id": "item-1",
          "description": "implement #18",
          "type": "implement",
          "issue": 18,
          "pr_number": null,
          "wave": 1,
          "depends_on": [],
          "agent_id": null,
          "workspace": null,
          "workspace_type": null,
          "branch": null,
          "status": "pending",
          "started_at": null,
          "completed_at": null,
          "result_summary": null,
          "error": null
        }
      ],
      "waves": [
        { "number": 1, "status": "pending", "items": ["item-1", "item-3"], "started_at": null, "completed_at": null },
        { "number": 2, "status": "pending", "items": ["item-2"], "started_at": null, "completed_at": null }
      ],
      "agents": {},
      "quality_gates": {},
      "context": {
        "percentage": 0,
        "last_checked": "2026-03-17T14:30:22Z",
        "checkpoints": []
      }
    }
    ```

### Dispatch Wave 1

1. **For each item in Wave 1**, dispatch via the appropriate `/cos:*` subcommand:
    - Research items: call `/cos:research` logic
    - Implementation items: call `/cos:implement` logic
    - Review items: call `/cos:review` logic

    All dispatches use `run_in_background: true`. Update `state.json` with agent IDs and status `"dispatched"` after each dispatch.

2. **Display the dispatch plan** to the user:

    ```text
    CHIEF OF STAFF - SESSION {session-id}
    ═══════════════════════════════════════════════════════════

    Work Items:
    ┌────────┬──────────────┬───────────┬───────┬─────────────┐
    │ ID     │ Description  │ Type      │ Wave  │ Status      │
    ├────────┼──────────────┼───────────┼───────┼─────────────┤
    │ item-1 │ implement #18│ implement │  1    │ dispatched  │
    │ item-2 │ review PR #55│ review    │  1    │ dispatched  │
    │ item-3 │ research X   │ research  │  1    │ dispatched  │
    │ item-4 │ implement #12│ implement │  2    │ pending     │
    └────────┴──────────────┴───────────┴───────┴─────────────┘

    Wave 1: 3 agents dispatched (item-1, item-2, item-3)
    Wave 2: 1 item waiting on item-1

    Run /cos:status for live updates.
    ```

### Agent Completion Handling

1. **When a background agent completes**, update `state.json`:
    - Set work item `status` to `"complete"` or `"failed"`
    - Set agent `status` to `"complete"` or `"failed"`
    - Record `completed_at` timestamp
    - If failed, record `error` message

2. **Check wave completion.** If all items in the current wave are complete (or failed):
    - Mark the wave as `"complete"` in state
    - Dispatch the next wave's items

3. **On final wave completion**, display summary:

    ```text
    SESSION COMPLETE - {session-id}
    ═══════════════════════════════════════
    Completed: 3/4 items
    Failed: 1 item (item-4: merge conflict on src/auth.ts)
    PRs created: #56, #57
    PRs merged: #56
    Duration: 23 minutes
    ```

### Error Handling

| Problem | Action |
|---------|--------|
| Issue number doesn't exist | Report error, exclude from plan, continue |
| Cycle in dependency graph | Report cycle to user, ask for resolution |
| Agent fails | Mark item as failed, continue wave, report at completion |
| All items in a wave fail | Stop, report to user with failure details |
| `gh` CLI not authenticated | Stop immediately, tell user to run `gh auth login` |
| Session directory can't be created | Fall back to `/tmp/chief-of-staff/sessions/` |

---

## 2. /cos:research

---
name: research
description: "Spawn a read-only Explore agent to research a topic or issue."
argument-hint: '"topic description" or "#issue-number"'
allowed-tools:

- Bash
- Read
- Glob
- Grep
- Agent

---

### Description

Spawns a read-only research agent. No workspace isolation needed (read-only operations don't conflict). Multiple research tasks can run in parallel. Returns a structured research report.

### Usage

```bash
/cos:research "caching strategies for session tokens"
/cos:research "#42"
/cos:research "#42 focus on the auth module"
```

### Input Parsing

1. **Detect issue reference.** If input starts with `#` followed by digits, extract the issue number.

2. **Fetch issue context** (if issue number present):

   ```bash
   gh issue view <N> --json number,title,body,labels,comments
   ```

   If the issue doesn't exist, report the error and stop.

3. **Build research prompt.** Combine:
   - Issue title and body (if from issue)
   - User-provided topic description
   - Instruction to produce a structured report

### Agent Dispatch

1. **Spawn the Explore agent:**

   ```
   Agent tool call:
     description: "Research: <topic summary, max 60 chars>"
     prompt: |
       ## Research Task

       <issue context if available>

       **Topic**: <user description or issue body>

       ## Instructions

       1. Search the codebase for relevant files, patterns, and prior art
       2. Read documentation (CLAUDE.md, AGENTS.md, README) for conventions
       3. Check git log for related commits: `git log --oneline --all --grep="<keyword>"`
       4. Check for related issues: `gh issue list --search "<keyword>" --json number,title`
       5. Identify risks, unknowns, and decision points

       ## Output Format

       Produce a report with these sections:

       ### Summary
       <2-3 sentence overview>

       ### Relevant Files
       | File | Purpose | Relevance |
       |------|---------|-----------|
       | ... | ... | ... |

       ### Key Findings
       <Numbered list of discoveries>

       ### Risks and Unknowns
       <Bulleted list>

       ### Recommended Approach
       <Actionable recommendation>

       ### Open Questions
       <Questions that need human input>

     subagent_type: "research"
     run_in_background: true
   ```

   The agent is read-only: no `Write`, `Edit`, or file-modifying `Bash` commands.

### State Updates

1. **If called from a `/cos` session**, update the work item in `state.json`:

   ```json
   {
     "status": "dispatched",
     "agent_id": "<agent-id>",
     "started_at": "<timestamp>"
   }
   ```

2. **On completion**, update:

   ```json
   {
     "status": "complete",
     "completed_at": "<timestamp>",
     "result_summary": "<first 200 chars of summary section>"
   }
   ```

### Output Format

1. **Immediate response** (when dispatched):

   ```text
   Research agent dispatched: "<topic>"
   Agent running in background. Use /cos:status for updates.
   ```

2. **On completion** (when agent returns):
   Display the full research report as-is. The report follows the structured format defined in the agent prompt above.

### Error Handling

| Problem | Action |
|---------|--------|
| Issue doesn't exist | Report: "Issue #N not found. Check the number and try again." |
| Agent returns empty/garbage | Report failure, suggest running with more specific topic |
| Agent times out | Report timeout, suggest breaking into smaller research questions |

---

## 3. /cos:implement

---
name: implement
description: "Spawn an implementation agent in an isolated workspace. Creates PR on completion."
argument-hint: '"#issue-number" or "description of work"'
allowed-tools:

- Bash
- Read
- Write
- Edit
- Glob
- Grep
- Agent
- LSP

---

### Description

Fetches issue details (if issue number provided), creates an isolated workspace, spawns an implementation agent with quality gates, and creates a PR on completion. Uses merge-as-you-go strategy (don't batch PRs).

### Usage

```bash
/cos:implement "#18"
/cos:implement "#18 focus on the API endpoint only"
/cos:implement "add rate limiting to /api/auth"
```

### Input Parsing

1. **Detect issue reference.** If input contains `#` followed by digits, extract the issue number.

2. **Fetch issue details** (if issue number present):

   ```bash
   gh issue view <N> --json number,title,body,labels,milestone,assignees
   ```

   If the issue doesn't exist, report the error and stop.

3. **Build task description.** Combine issue title, body, labels, and any user-provided description into a consolidated task brief.

### VCS Detection and Workspace Setup

1. **Detect VCS type:**

   ```bash
   jj root >/dev/null 2>&1
   ```

   - If exits 0: **JJ mode**
   - If exits non-zero: **Git mode**

2. **Create isolated workspace.**

   **JJ mode:**

   ```bash
   # Create a new workspace for this task
   jj workspace add ~/.chief-of-staff/workspaces/item-{id}
   # Create a new change in the workspace
   cd ~/.chief-of-staff/workspaces/item-{id}
   jj new main
   jj describe -m "wip: <task brief, max 72 chars>"
   ```

   **Git mode:**
   Use the Agent tool with `isolation: "worktree"`. The Agent SDK handles worktree creation and cleanup automatically.

3. **Record workspace path** in `state.json`:

   ```json
   {
     "workspace": "~/.chief-of-staff/workspaces/item-{id}",
     "workspace_type": "jj" | "git-worktree"
   }
   ```

### Branch Naming

1. **Generate branch name** from the task:
   - From issue: `cos/<issue-number>-<slugified-title>` (e.g., `cos/18-add-rate-limiting`)
   - From description: `cos/<slugified-first-5-words>` (e.g., `cos/add-rate-limiting-api-auth`)
   - Max 50 characters, lowercase, hyphens only

### Agent Dispatch

1. **Read project conventions:**

   ```bash
   # Check for project conventions
   cat CLAUDE.md 2>/dev/null || true
   cat AGENTS.md 2>/dev/null || true
   ```

2. **Spawn the implementation agent:**

   ```
   Agent tool call:
     description: "Implement: <task brief, max 60 chars>"
     prompt: |
       ## Task

       <issue title and body if from issue, or user description>

       ## Branch

       Work on branch: <branch-name>
       Workspace: <workspace-path>

       ## Project Conventions

       <contents of CLAUDE.md / AGENTS.md, truncated to essentials>

       ## Instructions

       1. **Understand the task.** Read the issue/description carefully. Search
          the codebase for related code before writing anything.
       2. **Plan before coding.** Identify which files need changes. Check for
          existing patterns to follow.
       3. **Implement incrementally.** Make changes in logical commits. Each
          commit should build and pass tests.
       4. **Follow existing patterns.** Match the codebase's style, naming
          conventions, and architecture.
       5. **Write tests.** If the project has tests, add tests for new
          functionality. Run the test suite to verify.
       6. **Run quality gates:**
          - Build: use the project's build command
          - Lint: use the project's lint command
          - Test: use the project's test command
          - Type check: if applicable
       7. **Commit with conventional commits.** Format: `feat(scope): description`
          or `fix(scope): description`. Stage specific files only.

       ## Quality Gates (must all pass before completion)

       - [ ] Code builds without errors
       - [ ] All existing tests pass
       - [ ] New tests added for new functionality (if test infrastructure exists)
       - [ ] No lint errors
       - [ ] Commits follow conventional commit format

       ## On Completion

       When all quality gates pass, output an implementation report in this exact format:
       ```
       === IMPLEMENTATION REPORT ===
       Status: COMPLETE

       Issue: <task brief>
       Workspace: <workspace-path>
       VCS: git | jj
       Branch/Bookmark: <branch-name>
       PR: <URL or "N/A">

       Files Changed:
       - <path> (created | modified | deleted)

       Tests:
       - <test file>: <N> tests added, <M> tests modified

       Quality Gates:
       - format: PASS
       - lint: PASS
       - test: PASS (<N> passed)

       Commits:
       - <sha> <message>

       Issues Encountered:
       - none

       Deviations from Acceptance Criteria:
       - none
       === END REPORT ===
       ```

       If blocked or only partially complete, set Status to PARTIAL or BLOCKED and fill in the Issues Encountered section.

     subagent_type: "general-purpose"
     isolation: "worktree"  # (git mode only; JJ uses manual workspace)
     run_in_background: true
   ```

### Post-Completion Pipeline

1. **On agent completion**, parse the agent output for `=== IMPLEMENTATION REPORT ===` ... `=== END REPORT ===`. Extract the `Status:` field (`COMPLETE`, `PARTIAL`, or `BLOCKED`).

2. **If Status is not COMPLETE** (or the report is missing), update state to `"failed"` with the error details. Report to user.

3. **If quality gates passed**, create a PR:

    **JJ mode:**

    ```bash
    cd <workspace-path>
    jj bookmark set <branch-name> -r @-
    jj git push --bookmark <branch-name> --allow-new
    gh pr create --head <branch-name> \
      --title "<issue title or task brief>" \
      --body "$(cat <<'EOF'
    ## Summary

    <auto-generated from commits>

    Closes #<issue-number>  (if from issue)

    ## Quality Gates

    - [x] Build passes
    - [x] Tests pass
    - [x] Lint clean

    Automated by chief-of-staff
    EOF
    )"
    ```

    **Git mode:**

    ```bash
    git push -u origin <branch-name>
    gh pr create --head <branch-name> \
      --title "<issue title or task brief>" \
      --body "<same format as above>"
    ```

4. **Merge-as-you-go.** After PR creation, if CI passes and no review is required (or auto-merge is enabled):

    ```bash
    gh pr merge <pr-number> --squash --delete-branch
    ```

    If review is required, leave the PR open and note it in the state.

5. **Rebase downstream work.** If other agents in later waves depend on this item, they will start from an updated base after the merge.

### State Updates

Update `state.json` through the lifecycle:

| Event | State change |
|-------|-------------|
| Agent dispatched | `status: "dispatched"`, `agent_id`, `started_at`, `workspace` |
| Agent completes successfully | `status: "complete"`, `pr_number`, `completed_at` |
| Agent fails | `status: "failed"`, `error` |
| Quality gates fail | `status: "failed"`, `error` (error message details which gate failed) |

### Output Format

1. **Immediate response:**

    ```text
    Implementation agent dispatched: "<task brief>"
    Branch: <branch-name>
    Workspace: <workspace-type> at <path>
    Agent running in background. Use /cos:status for updates.
    ```

2. **On PR creation:**

    ```text
    PR #<N> created for: <task brief>
    URL: <pr-url>
    Status: awaiting CI / awaiting review
    ```

### Error Handling

| Problem | Action |
|---------|--------|
| Issue doesn't exist | Report error, stop |
| JJ workspace creation fails | Fall back to git worktree |
| Git worktree creation fails | Report error, suggest manual workspace |
| Agent fails mid-implementation | Save partial work (branch is pushed), report failure with details |
| Build/test fails in quality gates | Report which gate failed and the error output |
| PR creation fails | Branch is still pushed; report error, user can create PR manually |
| Merge conflict on PR | Report conflict, leave PR open for manual resolution |

### Workspace Cleanup

1. **After successful merge** (or on explicit cleanup):

    **JJ mode:**

    ```bash
    jj workspace forget <workspace-name>
    rm -rf ~/.chief-of-staff/workspaces/item-{id}
    ```

    **Git mode:**
    Handled automatically by the Agent SDK's worktree cleanup.

---

## 4. /cos:review

---
name: review
description: "Route a PR or branch to the review lifecycle."
argument-hint: '"PR #N" or "branch-name"'
allowed-tools:

- Bash
- Read
- Edit
- Write
- Glob
- Grep
- Agent
- LSP

---

### Description

Routes review work to the appropriate handler. For PRs, delegates to `/cycle:pr`. For branches without a PR, spawns a code-reviewer agent. Tracks review status in the session state.

### Usage

```bash
/cos:review "PR #42"
/cos:review "#42"            # also interpreted as PR
/cos:review "feature/foo"    # branch review
/cos:review "PR #42 #43 #44" # multiple PRs
```

### Input Parsing

1. **Detect PR references.** Look for patterns: `PR #N`, `PR N`, `#N` (check if it's a PR or issue), bare numbers.

2. **Detect branch references.** Anything that isn't a number and looks like a branch name.

3. **Validate references.**

   For PR numbers:

   ```bash
   gh pr view <N> --json number,title,state,headRefName,url,reviewDecision
   ```

   For branch names:

   ```bash
   git branch --list <name> --remotes
   gh pr list --head <name> --json number,title,state
   ```

   If a PR already exists for the branch, use the PR workflow.

### Workflow Routing

1. **PR review (single or multiple):**

   Delegate directly to `/cycle:pr`:

   ```
   Invoke /cycle:pr <pr-number> [<pr-number> ...]
   ```

   This handles the full review lifecycle: poll for reviews, address comments, push fixes, re-poll, merge. See cycle/commands/pr.md for the full protocol.

2. **Branch review (no existing PR):**

   Spawn a code-reviewer agent:

   ```
   Agent tool call:
     description: "Review branch: <branch-name>"
     prompt: |
       ## Code Review

       Review the changes on branch `<branch-name>` compared to `main`.

       ```bash
       git diff main...<branch-name>
       git log main...<branch-name> --oneline
       ```

       ## Review Checklist

       For each file changed:
       1. **Correctness**: Does the code do what it claims?
       2. **Edge cases**: Are error paths handled?
       3. **Tests**: Are there tests? Do they cover the changes?
       4. **Style**: Does it follow the project's conventions?
       5. **Security**: Any credentials, injection risks, or auth gaps?
       6. **Performance**: Any obvious N+1 queries, unbounded loops, or memory leaks?

       ## Output Format

       ### Review Summary
       <overall assessment: approve / request changes / needs discussion>

       ### File-by-File Review
       For each file:
       **<filename>**
       - <finding 1>
       - <finding 2>

       ### Critical Issues (must fix)
       <numbered list, or "None">

       ### Suggestions (nice to have)
       <numbered list, or "None">

       ### Questions
       <numbered list, or "None">

     subagent_type: "research"
     run_in_background: true
   ```

### State Updates

1. **If called from a `/cos` session**, update the work item:

   | Event | State change |
   |-------|-------------|
   | Review dispatched (branch) | `status: "dispatched"`, `agent_id` |
   | Review dispatched (PR via cycle) | `status: "dispatched"`, `pr_number` |
   | Review complete (branch) | `status: "complete"`, `completed_at` |
   | PR merged (via cycle) | `status: "complete"`, `completed_at` |
   | Review failed / stuck | `status: "failed"`, `error` |

### Output Format

1. **For PR review:**

   ```text
   Routing PR #<N> to /cycle:pr for full review lifecycle.
   ```

   Then the cycle plugin takes over and produces its own output.

2. **For branch review:**

   ```text
   Code review agent dispatched for branch: <branch-name>
   Agent running in background. Use /cos:status for updates.
   ```

3. **On branch review completion:**
   Display the full review report from the agent.

### Error Handling

| Problem | Action |
|---------|--------|
| PR doesn't exist | Report: "PR #N not found." |
| Branch doesn't exist | Report: "Branch '<name>' not found locally or on remote." |
| `/cycle:pr` not available | Fall back to spawning a review agent manually |
| Agent timeout | Report timeout, suggest reviewing manually |

---

## 5. /cos:wave

---
name: wave
description: "Analyze dependencies, group into waves, dispatch parallel agents with isolated workspaces."
argument-hint: '"issues: 18,12,15,13" or "tasks: description1; description2; ..."'
allowed-tools:

- Bash
- Read
- Write
- Edit
- Glob
- Grep
- Agent
- LSP

---

### Description

The power command. Takes a batch of issues or task descriptions, analyzes their dependency graph, detects file overlap, groups them into waves of parallelizable work, and executes each wave with isolated workspaces. Implements merge-as-you-go: as each agent completes, quality gates run, PR is created, and if clean, merged before the next wave starts.

### Usage

```bash
/cos:wave "issues: 18,12,15,13"
/cos:wave "issues: 18,12,15,13 deps: 12->18, 15->18"
/cos:wave "tasks: add auth middleware; refactor user model; update API docs"
```

### Input Parsing

1. **Parse issue list.** If input contains `issues:`, extract comma-separated issue numbers.

2. **Parse task list.** If input contains `tasks:`, extract semicolon-separated task descriptions.

3. **Parse explicit dependencies.** If input contains `deps:`, extract dependency pairs in `A->B` format (meaning A depends on B completing first).

4. **Fetch issue details** for each issue:

   ```bash
   gh issue view <N> --json number,title,body,labels,milestone
   ```

   Collect all issue metadata into a work items list.

5. **Validate all issues exist.** Report any missing issues and exclude them.

### Dependency Analysis

1. **Start with explicit dependencies** from the `deps:` parameter.

2. **Detect implicit dependencies from issue content:**
   - Scan issue bodies for "depends on #N", "blocked by #N", "after #N"
   - Check GitHub issue links: `gh api repos/{owner}/{repo}/issues/<N>/timeline --jq '[.[] | select(.event == "cross-referenced")]'`

3. **Detect file overlap.** For each pair of issues, estimate whether they touch the same files:
   - Search codebase for files mentioned in issue bodies
   - If two issues reference the same module/directory, flag as potentially conflicting
   - Present conflicts to user for confirmation: "Issues #12 and #15 both reference `src/auth/`. Run in parallel anyway? (y/n)"
   - Default to sequential if overlap detected and user doesn't confirm

4. **Build the dependency DAG.** Create an adjacency list. Validate:
   - No cycles (report and ask user to break them)
   - No self-dependencies
   - All referenced issue numbers exist in the work set

5. **Topological sort into waves:**
    - **Wave 1**: Issues with no dependencies (in-degree 0)
    - **Wave N**: Issues whose dependencies are all in waves 1..N-1
    - Within each wave, order by estimated complexity (smaller issues first)

6. **Display the wave plan:**

    ```text
    WAVE PLAN
    ═══════════════════════════════════════════════════

    Wave 1 (parallel):
      #18 - Add rate limiting         [no deps]
      #13 - Fix typo in README        [no deps]

    Wave 2 (parallel):
      #12 - Auth middleware            [depends on #18]
      #15 - Update API docs           [depends on #18]

    Detected overlap: none
    Total waves: 2
    Estimated agents: 4

    Proceed? (y/n)
    ```

    Wait for user confirmation before dispatching.

### Workspace Creation

1. **Detect VCS type** (same as `/cos:implement` step 4).

2. **Create one isolated workspace per agent:**

    **JJ mode (preferred):**

    ```bash
    # For each issue in the current wave:
    jj workspace add ~/.chief-of-staff/workspaces/wave-{wave}-item-{issue}
    cd ~/.chief-of-staff/workspaces/wave-{wave}-item-{issue}
    jj new main
    jj describe -m "wip: #<issue> <title>"
    ```

    **Git mode (fallback):**
    Use `isolation: "worktree"` on each Agent dispatch. The Agent SDK creates and manages the worktrees.

### Wave Dispatch

1. **For each item in the current wave**, dispatch an implementation agent using the same protocol as `/cos:implement` step 9. All agents in the same wave are dispatched simultaneously with `run_in_background: true`.

2. **Create a `/cos` session** (if not already in one) to track all items. Use the same `state.json` schema as `/cos` step 11.

### Wave Completion and Progression

1. **Monitor agent completions.** As each agent finishes:

    a. **Run quality gates** (build, test, lint). Parse the agent output for `=== IMPLEMENTATION REPORT ===` and check the `Status:` field.

    b. **Create PR:**

       ```bash
       # JJ:
       jj bookmark set cos/<issue>-<slug> -r @-
       jj git push --bookmark cos/<issue>-<slug> --allow-new
       # Git:
       git push -u origin cos/<issue>-<slug>
       # Both:
       gh pr create --head cos/<issue>-<slug> \
         --title "<issue title>" \
         --body "Closes #<issue>. Automated by chief-of-staff."
       ```

    c. **Merge immediately** if CI passes (merge-as-you-go):

       ```bash
       gh pr checks <pr-number> --watch --fail-fast
       gh pr merge <pr-number> --squash --delete-branch
       ```

    d. **Update state.** Mark item as `"complete"`.

2. **Wave transition.** When ALL items in the current wave are completed (merged or failed):

    a. **Rebase next wave's workspaces** onto the updated main:

       ```bash
       # JJ (automatic):
       # JJ auto-rebases descendants — no action needed if workspaces track main

       # Git:
       git checkout main && git pull
       # For each next-wave worktree:
       cd <worktree-path> && git rebase main
       ```

    b. **Increment wave counter** and dispatch next wave agents.

    c. **Display wave transition:**

       ```text
       Wave 1 COMPLETE (2/2 merged)
       ─────────────────────────────
       #18 - Add rate limiting       merged (PR #56)
       #13 - Fix typo in README      merged (PR #57)

       Dispatching Wave 2 (2 agents)...
       ```

3. **Final wave completion.** When the last wave finishes:

    ```text
    ALL WAVES COMPLETE
    ═══════════════════════════════════════════════════

    ┌────────┬──────────────────────┬─────────┬───────┐
    │ Issue  │ Title                │ PR      │ Status│
    ├────────┼──────────────────────┼─────────┼───────┤
    │ #18    │ Add rate limiting    │ #56     │ merged│
    │ #13    │ Fix typo in README   │ #57     │ merged│
    │ #12    │ Auth middleware       │ #58     │ merged│
    │ #15    │ Update API docs      │ #59     │ merged│
    └────────┴──────────────────────┴─────────┴───────┘

    4/4 items completed. 4 PRs merged.
    Duration: 41 minutes.
    ```

### State Updates

The wave state is tracked in `state.json` using the [canonical schema](state-schema.md). Waves are an array of objects with a `number` field:

```json
{
  "waves": [
    {
      "number": 1,
      "status": "complete",
      "items": ["item-1", "item-2"],
      "started_at": "2026-03-17T14:31:00Z",
      "completed_at": "2026-03-17T14:45:00Z"
    },
    {
      "number": 2,
      "status": "active",
      "items": ["item-3", "item-4"],
      "started_at": "2026-03-17T14:46:00Z",
      "completed_at": null
    }
  ]
}
```

### Error Handling

| Problem | Action |
|---------|--------|
| Agent fails quality gates | Mark item as `"failed"` with error details, continue wave, report at wave end |
| Merge conflict on PR | Attempt auto-rebase. If rebase fails, mark as `"failed"` with conflict details, continue wave |
| All agents in a wave fail | Stop. Report failures. Do NOT dispatch next wave. |
| Partial wave failure | Continue with succeeded items. Dispatch next wave with caveat that some deps failed. Report which downstream items are affected. |
| File overlap detected at runtime | If two agents edited the same file, the second PR will likely conflict. Merge the first, rebase the second, re-run quality gates. |
| JJ workspace add fails | Fall back to git worktree for that specific item |
| User declines wave plan | Stop. Suggest editing dependencies or reordering. |

### Workspace Cleanup

1. **After all waves complete** (or on abort):

    **JJ mode:**

    ```bash
    # For each workspace:
    jj workspace forget <workspace-name>
    rm -rf ~/.chief-of-staff/workspaces/wave-*
    ```

    **Git mode:**
    Agent SDK handles worktree cleanup automatically.

    ```bash
    # Clean up session workspace directory:
    rm -rf ~/.chief-of-staff/workspaces/wave-*
    ```

---

## 6. /cos:status

---
name: status
description: "Show dashboard of all active agents, wave progress, PRs, and context usage."
argument-hint: "[session-id]"
allowed-tools:

- Bash
- Read
- Glob

---

### Description

Displays a live dashboard of the current (or specified) chief-of-staff session. Shows agent status, wave progress, PR state, and context window usage.

### Usage

```bash
/cos:status
/cos:status {session-id}
```

### Input Parsing

1. **Determine session.** If a session ID is provided, use it. Otherwise, find the most recent active session:

   ```bash
   ls -t ~/.chief-of-staff/sessions/ | head -1
   ```

2. **Read session state:**

   ```bash
   cat ~/.chief-of-staff/sessions/{session-id}/state.json
   ```

   If the session doesn't exist, report: "No active session found. Start one with /cos."

### Data Gathering

1. **For each work item with a PR**, fetch current CI/review status:

   ```bash
   gh pr view <pr-number> --json state,reviewDecision,statusCheckRollup,mergeable
   ```

2. **Estimate context usage.** Read the current session's token/context percentage if available from the Claude Code runtime. If not available, display "N/A".

### Output Format

1. **Render the dashboard:**

    ```text
    CHIEF OF STAFF - STATUS
    Session: {session-id}
    Started: 2026-03-17 14:30:22 (23 min ago)
    ═══════════════════════════════════════════════════════════════

    AGENTS
    ┌────────┬──────────────────────┬───────────┬──────────┬──────┐
    │ ID     │ Task                 │ Type      │ Status   │ Time │
    ├────────┼──────────────────────┼───────────┼──────────┼──────┤
    │ item-1 │ #18 Rate limiting    │ implement │ merged   │ 12m  │
    │ item-2 │ PR #55 review        │ review    │ active   │ 8m   │
    │ item-3 │ Caching research     │ research  │ complete │ 3m   │
    │ item-4 │ #12 Auth middleware  │ implement │ coding   │ 5m   │
    └────────┴──────────────────────┴───────────┴──────────┴──────┘

    WAVES
    ┌───────┬──────────────────┬──────────┬───────────────────────┐
    │ Wave  │ Items            │ Status   │ Progress              │
    ├───────┼──────────────────┼──────────┼───────────────────────┤
    │ 1     │ item-1, item-3   │ complete │ 2/2 done              │
    │ 2     │ item-2, item-4   │ active   │ 1/2 done, 1 running  │
    └───────┴──────────────────┴──────────┴───────────────────────┘

    PULL REQUESTS
    ┌────────┬──────────────────────┬────────┬────────┬───────────┐
    │ PR     │ Title                │ CI     │ Review │ Status    │
    ├────────┼──────────────────────┼────────┼────────┼───────────┤
    │ #56    │ Add rate limiting    │ pass   │ -      │ merged    │
    │ #58    │ Auth middleware      │ running│ -      │ open      │
    └────────┴──────────────────────┴────────┴────────┴───────────┘

    CONTEXT
    Session context: 34% used

    ───────────────────────────────────────────────────────────────
    Overall: 3/4 items complete | Wave 2 of 2 active
    ```

### State Updates

This command is read-only. It does not modify `state.json`.

### Error Handling

| Problem | Action |
|---------|--------|
| No sessions exist | Report: "No active session found. Start one with /cos." |
| Session ID not found | Report: "Session '<id>' not found." List available sessions. |
| `state.json` is corrupted | Report: "Session state is corrupted. Available data:" then show what can be parsed. |
| `gh` commands fail | Show cached state from `state.json` without live PR data. Mark as "(cached)" |
| No PR data available | Show agent status only, skip PR table |

---

## Cross-Cutting Concerns

### Session State Schema

> **Canonical schema**: See [specs/state-schema.md](state-schema.md) for the full schema definition, field reference, status enums, state transitions, and examples.
>
> All commands read and write state.json using the canonical schema. Key points relevant to commands:
>
> - **Session ID**: Claude Code's native `session_id` (not a custom format).
> - **Session status**: `PLANNING | DISPATCHING | MONITORING | CHECKPOINTING | COMPLETE` (SCREAMING_CASE).
> - **Work item status**: `pending | dispatched | complete | failed` (lowercase).
> - **Waves**: Array of objects with `number` field.
> - **Agents**: Object keyed by agent-id.
> - **Workspace paths**: `~/.chief-of-staff/workspaces/item-{id}` or `~/.chief-of-staff/workspaces/wave-{wave}-item-{id}`.
> - **Timestamps**: All use `_at` suffix (`created_at`, `started_at`, `completed_at`).
> - **Retry budget**: 2 retries (3 total attempts) per work item.

### VCS Strategy

1. **Prefer JJ.** Check `jj root` first. JJ workspaces are lighter than git worktrees and auto-rebase descendants.
2. **Fall back to git worktrees.** Use the Agent SDK's `isolation: "worktree"` for automatic management.
3. **Never mix.** Within a session, all workspaces use the same VCS type. Detect once at session start.

### Merge-as-you-go

Do not batch PRs. As soon as a work item passes quality gates and CI:

1. Create PR
2. Wait for CI (up to 10 minutes)
3. Merge with `--squash --delete-branch`
4. Pull updated main into remaining workspaces / let JJ auto-rebase

This minimizes merge conflicts between agents in later waves.

### Quality Gates Protocol

Every implementation agent must pass these gates before a PR is created:

1. **Build**: Run the project's build command. Must exit 0.
2. **Test**: Run the project's test command. Must exit 0.
3. **Lint**: Run the project's lint command (if configured). Must exit 0.
4. **Type check**: Run type checking (if applicable). Must exit 0.
5. **Commit format**: All commits must follow conventional commit format.

The agent signals completion with a structured report delimited by `=== IMPLEMENTATION REPORT ===` ... `=== END REPORT ===`. The `Status:` field indicates `COMPLETE`, `PARTIAL`, or `BLOCKED`. If the report or `Status: COMPLETE` is absent, the implementation is considered incomplete.

Similarly, research agents produce `=== RESEARCH REPORT ===` ... `=== END REPORT ===` and review agents produce `=== REVIEW REPORT ===` ... `=== END REPORT ===`, each with a `Status:` field.

### Context Window Management

The orchestrator thread stays lightweight by:

- Dispatching all heavy work to background agents
- Storing state in `state.json` rather than in-context
- Reading state from disk when `/cos:status` is called
- Never loading full file contents into the orchestrator — only summaries and metadata
