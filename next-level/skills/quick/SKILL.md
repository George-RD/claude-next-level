---
name: quick
description: Quick implementation mode — skips plan phase, goes straight to TDD implementation with all quality hooks active.
user-invocable: true
argument-hint: "<task description>"
---

# Quick Mode

Implement a task directly without the full spec planning workflow. For small, well-understood changes where planning overhead isn't justified.

## When to Use

- Bug fixes with clear root cause
- Small features with obvious implementation
- Refactoring where the approach is straightforward
- Tasks the user has already planned externally

## Process

1. **Create spec**: Write a minimal spec JSON to `~/.next-level/specs/<slug>.json`:
   ```json
   {
     "name": "<slug>",
     "description": "$ARGUMENTS",
     "status": "IMPLEMENTING",
     "created": "<ISO timestamp>",
     "mode": "quick"
   }
   ```

2. **Implement with TDD**:
   - RED: Write a failing test first
   - GREEN: Minimal code to pass
   - REFACTOR: Clean up
   - Run all tests after each change
   - All Layer 1 quality hooks (file checker, comment stripping, formatting) fire normally

3. **Verify**:
   - Run full test suite — show actual output
   - Run configured linters
   - Confirm no regressions

4. **Complete**:
   - Update spec: `{"status": "VERIFIED"}`
   - Commit with clear message
   - If omega memory is available, store: `omega_store(completion_summary, "milestone")`

## What's Skipped

- No plan document written
- No plan-challenger agent review
- No spec-reviewer agent review
- No user approval gate before implementation

## What Still Fires

- TDD enforcement hook (PostToolUse)
- File checker hook (formatting, linting, comment stripping)
- Context monitor (with omega checkpoint at 80%)
- Verification guard (Stop hook — must run tests before ending)
- Spec stop guard (Stop hook — warns about active spec)

## Constraints

- If the task turns out to be more complex than expected (>3 files, >30 minutes), suggest switching to the full `/next-level:spec` workflow
- Quick mode is NOT for multi-step features or architectural changes
