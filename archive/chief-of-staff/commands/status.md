---
name: status
description: "Show dashboard of all active agents, wave progress, PRs, and context usage."
allowed-tools:
  - Bash
  - Read
  - Glob
---

# /cos:status

Display a read-only dashboard of the current (or specified) chief-of-staff session. Shows agent status, wave progress, PR state, and context window usage. This command does not modify `state.json`.

## Usage

```bash
/cos:status
/cos:status {session-id}
```

---

## Workflow

### 1. Determine Session

If a session ID is provided as an argument, use it.

Otherwise, find the most recent active session:

```bash
ls -t ~/.chief-of-staff/sessions/ | head -1
```

If no sessions exist, stop and report:

```text
No active session found. Start one with /cos.
```

### 2. Read Session State

```bash
cat ~/.chief-of-staff/sessions/{session-id}/state.json
```

If the session ID is not found, report:

```text
Session '<id>' not found. Available sessions:
```

Then list available sessions:

```bash
ls ~/.chief-of-staff/sessions/
```

If `state.json` exists but cannot be parsed, report:

```text
Session state is corrupted. Available data:
```

Then show whatever fields can be extracted.

### 3. Fetch Live PR Data

For each work item that has a `pr_number`, fetch current CI and review status:

```bash
gh pr view <pr-number> --json state,reviewDecision,statusCheckRollup,mergeable
```

If `gh` commands fail (network error, auth issue), fall back to cached data from `state.json` and mark PR entries as `(cached)`.

### 4. Calculate Timing

For each agent/work item, calculate elapsed time:

- If `completed_at` is set: `completed_at - started_at`
- If `started_at` is set but not `completed_at`: `now - started_at`
- If neither is set: show `-`

Format durations as `Nm` (minutes) or `Nh Nm` (hours and minutes).

Calculate session duration: `now - created_at`.

### 5. Render the Dashboard

```text
CHIEF OF STAFF - STATUS
Session: {session-id}
Started: {created_at formatted} ({duration} ago)
Status: {session status}
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
```

### 6. Render PR Table (if any work items have PRs)

Only display this section if at least one work item has a `pr_number` set.

```text
PULL REQUESTS
┌────────┬──────────────────────┬────────┬────────┬───────────┐
│ PR     │ Title                │ CI     │ Review │ Status    │
├────────┼──────────────────────┼────────┼────────┼───────────┤
│ #56    │ Add rate limiting    │ pass   │ -      │ merged    │
│ #58    │ Auth middleware      │ running│ -      │ open      │
└────────┴──────────────────────┴────────┴────────┴───────────┘
```

CI status values: `pass`, `fail`, `running`, `pending`, `(cached)`.
Review status values: `approved`, `changes_requested`, `pending`, `-` (no review required).
PR status values: `open`, `merged`, `closed`.

### 7. Show Context and Summary

```text
CONTEXT
Session context: {percentage}% used

───────────────────────────────────────────────────────────────
Overall: {completed}/{total} items complete | Wave {current} of {total_waves} {wave_status}
```

If context percentage is not available, display `Session context: N/A`.

If context percentage exceeds 80%, add a warning:

```text
Session context: {percentage}% used (approaching limit — checkpoint recommended)
```

---

## Error Handling

| Problem | Action |
|---------|--------|
| No sessions exist | Report: "No active session found. Start one with /cos." |
| Session ID not found | Report: "Session '<id>' not found." List available sessions. |
| `state.json` is corrupted or unreadable | Report: "Session state is corrupted. Available data:" then show what can be parsed |
| `gh` commands fail | Show cached state from `state.json` without live PR data. Mark PR entries as `(cached)` |
| No PR data available | Show agents and waves tables only, skip the PR table entirely |
| Session is COMPLETE | Show the full dashboard with all final statuses and total duration |
