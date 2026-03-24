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

# /cos:research

Spawn a read-only research agent. No workspace isolation needed (read-only operations do not conflict). Multiple research tasks can run in parallel. Returns a structured research report.

## Usage

```bash
/cos:research "caching strategies for session tokens"
/cos:research "#42"
/cos:research "#42 focus on the auth module"
```

$ARGUMENTS

---

## Workflow

### 1. Parse Input

Detect whether the input contains an issue reference. If the input starts with `#` followed by digits, extract the issue number. Any remaining text after the issue number is treated as additional focus instructions.

If the input contains no `#` reference, treat the entire argument as a free-text topic description.

### 2. Fetch Issue Context (if issue number present)

```bash
gh issue view <N> --json number,title,body,labels,comments
```

If the issue does not exist, stop and report:

```text
Issue #N not found. Check the number and try again.
```

### 3. Build Research Prompt

Combine the following into a research brief:

- **Issue title and body** (if from an issue)
- **User-provided topic description** (or additional focus instructions)
- **Structured output instructions** (see agent dispatch below)

### 4. Dispatch Explore Agent

Spawn a read-only Explore agent using the Agent tool:

```
Agent tool call:
  description: "Research: <topic summary, max 60 chars>"
  prompt: |
    ## Research Task

    <issue context if available: "Issue #N: <title>\n\n<body>">

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

### 5. Update Session State (if called from a `/cos` session)

If an active chief-of-staff session exists, read `state.json` and update the corresponding work item:

**On dispatch:**

```json
{
  "status": "dispatched",
  "agent_id": "<agent-id>",
  "started_at": "<ISO-8601-now>"
}
```

Add the agent to the `agents` map:

```json
{
  "<agent-id>": {
    "name": "research-<slugified-topic>",
    "type": "research",
    "status": "running",
    "work_item_id": "<item-id>",
    "workspace_path": null,
    "started_at": "<ISO-8601-now>",
    "completed_at": null
  }
}
```

Update `updated_at` on the session root.

**On completion:**

```json
{
  "status": "complete",
  "completed_at": "<ISO-8601-now>",
  "result_summary": "<first 200 chars of Summary section>"
}
```

Update the agent entry: set `status` to `"complete"` and `completed_at`.

**On failure:**

```json
{
  "status": "failed",
  "completed_at": "<ISO-8601-now>",
  "error": "<error description>"
}
```

Update the agent entry: set `status` to `"failed"` and `completed_at`.

### 6. Display Immediate Response

After dispatching, show:

```text
Research agent dispatched: "<topic>"
Agent running in background. Use /cos:status for updates.
```

### 7. Handle Agent Completion

When the agent returns, display the full research report as-is. The report follows the structured format defined in step 4 above.

If the session has additional waves waiting on this research item, notify the orchestrator so it can check wave completion and dispatch the next wave.

---

## Error Handling

| Problem | Action |
|---------|--------|
| Issue does not exist | Report: "Issue #N not found. Check the number and try again." |
| `gh` CLI not authenticated | Stop: "Run `gh auth login` to authenticate." |
| Agent returns empty or unusable output | Report failure, suggest running with a more specific topic description |
| Agent times out | Report timeout, suggest breaking into smaller research questions |
| No active session (standalone call) | Skip state updates, dispatch agent and display report directly |
