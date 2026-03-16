---
description: "Show PR review comments"
argument-hint: "<pr-number>"
---

Fetch and summarize all review comments for PR #$ARGUMENTS.

## Steps

1. **Get the repo context** by running:

   ```
   gh repo view --json nameWithOwner -q .nameWithOwner
   ```

   Parse the `owner/repo` from the result.

2. **Fetch top-level PR data** (reviews and issue-level comments):

   ```
   gh pr view $ARGUMENTS --json reviews,comments,author,title,state
   ```

3. **Fetch inline review comments** (file-level comments with diff context):

   ```
   gh api repos/{owner}/{repo}/pulls/$ARGUMENTS/comments
   ```

4. **Fetch review threads to get resolved status**:

   ```
   gh pr view $ARGUMENTS --json reviewThreads
   ```

## Output Format

Start with a one-line summary: PR title, state, and total comment count.

Then group comments by reviewer. For each reviewer, list their comments:

```
### @reviewer-handle (N comments, M unresolved)

- **file.ts:42** — "The comment body truncated to first 2-3 lines..."
  Status: Unresolved | Resolved | Outdated

- **General comment** — "Top-level review comment..."
  Status: Approved | Changes Requested | Commented
```

## Final Section: Unresolved Action Items

At the end, collect all **unresolved** comments into a numbered checklist:

```
## Unresolved Items

1. @reviewer — file.ts:42 — "Comment summary..."
2. @reviewer — api.ts:15 — "Comment summary..."
```

If there are no unresolved items, say "All review comments are resolved."

## Important

- Always run the actual `gh` commands — do not fabricate data.
- If the PR number is missing or invalid, tell the user to provide one: `/pr-comments <number>`.
- Keep comment bodies concise in the summary (first 3 lines max). Mention if truncated.
