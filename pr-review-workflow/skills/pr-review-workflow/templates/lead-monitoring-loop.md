# Lead Monitoring Loop Template

Use this template as a reference for the team lead's monitoring loop after all PR agents have opened their PRs.

---

## Setup

Fill in your PR list:

```text
PR TRACKING
──────────────────────────────────────────────────────────────
#    Branch                  Agent           Status   Comments
{{PR_NUM}}  {{BRANCH}}       {{AGENT_NAME}}  Open     -
{{PR_NUM}}  {{BRANCH}}       {{AGENT_NAME}}  Open     -
{{PR_NUM}}  {{BRANCH}}       {{AGENT_NAME}}  Open     -
──────────────────────────────────────────────────────────────
```

## Polling Commands

Run these for each PR. Execute all PR checks in parallel when possible.

### CI Status

```bash
gh pr checks {{PR_NUMBER}}
```

Look for: all checks passing (green), any failures (red), or pending (yellow).

### Review Comments (Inline)

```bash
gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR_NUMBER}}/comments \
  --jq '.[] | {id: .id, path: .path, line: .line, body: .body, user: .user.login, created: .created_at}'
```

### Review Summaries

```bash
gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR_NUMBER}}/reviews \
  --jq '.[] | {id: .id, state: .state, body: .body, user: .user.login}'
```

### General PR Comments

```bash
gh api repos/{{OWNER}}/{{REPO}}/issues/{{PR_NUMBER}}/comments \
  --jq '.[] | {id: .id, body: .body, user: .user.login, created: .created_at}'
```

## Dashboard Update

After each poll, update the dashboard:

```text
PR DASHBOARD — {{TIMESTAMP}}
──────────────────────────────────────────────────────────────
PR   Branch              CI      Pending  Resolved  Agent
#{{N}}  {{BRANCH}}       Pass    0        2         {{AGENT}} (idle)
#{{N}}  {{BRANCH}}       Fail    3        0         {{AGENT}} (working)
#{{N}}  {{BRANCH}}       Pass    1        4         {{AGENT}} (idle)
──────────────────────────────────────────────────────────────
Action needed: Route 3 comments to {{AGENT}} for #{{N}}
```

## Comment Routing

When new comments appear on a PR:

1. **Read the comment** — understand what the reviewer wants
2. **Check for cross-PR relevance** — does this feedback apply to other PRs too?
3. **Route to the owning agent** via `SendMessage`:

```text
SendMessage to {{AGENT_NAME}}:

Review feedback on PR #{{PR_NUMBER}} ({{BRANCH}}):

Comment by {{REVIEWER}} on {{FILE}}:{{LINE}}:
> {{COMMENT_BODY}}

Please evaluate and address this. Fix if valid, discuss if you disagree.
Comment ID for reply: {{COMMENT_ID}}
```

## Cross-PR Overlap Detection

Watch for these patterns:

| Pattern | Example | Action |
|---------|---------|--------|
| Same style comment on 2+ PRs | "Use guard let instead of if let" | Broadcast convention to all agents |
| Architecture feedback | "This should use the service layer" | Broadcast + may need plan revision |
| Merge conflict warning | "This will conflict with PR #X" | Coordinate merge order |
| Shared dependency change | "Update the model in both branches" | Route to both agents with coordination note |

When overlap detected:

```text
Broadcast to all PR agents:

Cross-PR feedback from reviewer on #{{PR_NUMBER}}:
"{{FEEDBACK}}"

This applies to all branches. Please check your code for the same pattern and fix proactively.
```

## Polling Cadence

```text
T+0 min:    PRs opened, start monitoring
T+2 min:    First CI check (most CI runs take 1-5 min)
T+5 min:    Check for CodeRabbit/reviewer comments
T+10 min:   Second full poll (CI + comments)
T+15 min:   Third poll — by now most automated reviews are in
...
Every 5 min: Continue until all PRs show 0 pending comments
T+final:    One last check 5 min after last activity
```

## Completion Criteria

A PR is **done** when:
- [ ] CI all green
- [ ] 0 pending review comments
- [ ] No "Changes requested" reviews outstanding
- [ ] No merge conflicts with base branch

All PRs done → proceed to **Phase 5: Finalization** in the main skill.

## Troubleshooting

| Issue | Resolution |
|-------|-----------|
| CodeRabbit not posting | Check `.coderabbit.yaml` exists; try closing and reopening PR |
| CI stuck pending | Check GitHub Actions tab; may need re-run: `gh run rerun {{RUN_ID}}` |
| Agent not responding | Send a poke message; check if stopped by hook |
| Too many comments at once | Prioritize: security > bugs > style; batch style fixes |
| Reviewer requests changes | Agent should address all, then request re-review |
