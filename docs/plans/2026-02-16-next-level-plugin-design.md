# next-level Plugin Design

**Date**: 2026-02-16
**Status**: Approved
**Repo**: claude-next-level/next-level/

## Overview

A Claude Code plugin that brings workflow discipline: context monitoring, spec-driven development, TDD enforcement, and verification guards. Inspired by claude-pilot patterns, built for our stack.

## Goals

1. **Context monitor** — track context %, auto-handoff at thresholds, continuation files for seamless resume
2. **Spec workflow** — /spec command: plan → implement → verify cycle with approval gates
3. **TDD enforcer** — hook that reminds about test files before impl edits
4. **Verification guard** — block completion claims until tests actually pass

## Plugin Structure

```
next-level/
├── plugin.json
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── context-monitor.sh
│       ├── tdd-enforcer.sh
│       ├── verification-guard.sh
│       └── utils.sh
├── skills/
│   ├── spec/SKILL.md
│   ├── spec-plan/SKILL.md
│   ├── spec-implement/SKILL.md
│   ├── spec-verify/SKILL.md
│   └── context-status/SKILL.md
├── agents/
│   ├── plan-challenger.md
│   └── spec-reviewer.md
└── rules/
    ├── tdd-enforcement.md
    ├── verification-before-completion.md
    ├── context-continuation.md
    └── coding-standards.md
```

## Component Details

### Hooks

#### context-monitor (PostToolUse, async)

- Reads context usage from Claude Code session transcript
- Thresholds: 80% warn, 90% force handoff, 95% emergency stop
- Writes continuation.md for next session pickup
- Throttled: skips if last check < 30s and context < 80%
- State: `~/.next-level/sessions/{session-id}/context-pct.json`

#### tdd-enforcer (PostToolUse on Edit|Write)

- Fires after file edits to implementation files
- Skips: markdown, config, migrations, test files themselves
- Checks for corresponding test file (language-aware patterns)
- Exit 2 (non-blocking reminder) if no test file found
- Language patterns:
  - Python: `test_module.py` or `module_test.py`
  - TypeScript: `.test.ts`, `.spec.ts`, `.test.tsx`, `.spec.tsx`
  - Go: `module_test.go`

#### verification-guard (Stop event)

- Fires when session is about to end
- Reads transcript to check if tests were actually executed
- Looks for test runner output (jest, pytest, go test, etc.)
- Blocks (exit 2) if no test evidence found and impl files were modified
- Passes through if no impl files were touched (pure research/docs sessions)

### Skills

#### /spec — Dispatcher

Orchestrates the 3-phase workflow:
1. Check spec state file
2. Route to correct phase based on status (PLANNING → IMPLEMENTING → VERIFYING)
3. Context-aware: if context > 80%, write continuation instead of starting new phase

States: `PLANNING` → `IMPLEMENTING` → `VERIFYING` → `VERIFIED`
If verify fails → back to `IMPLEMENTING`

#### /spec-plan — Design Phase

- Explore codebase relevant to the task
- Design solution with trade-offs
- Write formal plan document
- Invoke plan-challenger agent for adversarial review
- Require user approval before transitioning to IMPLEMENTING

#### /spec-implement — TDD Execution

- Read the approved plan
- RED: write failing tests first
- GREEN: implement until tests pass
- REFACTOR: clean up while tests stay green
- Track progress against plan checklist

#### /spec-verify — Validation

- Run full test suite
- Invoke spec-reviewer agent for quality + compliance
- Check for linting/formatting issues
- Verify all plan items completed
- If issues found: revert to IMPLEMENTING with specific feedback

#### /context-status — Quick Check

- Show current context usage %
- Show active spec state if any
- Show continuation status

### Agents

#### plan-challenger

- Model: haiku (fast, cheap adversarial review)
- Tools: Read, Grep, Glob (read-only)
- Purpose: Find holes in plans — missing edge cases, security issues, over-engineering
- Invoked by /spec-plan before user approval

#### spec-reviewer

- Model: sonnet (quality review needs depth)
- Tools: Read, Grep, Glob, Bash (for running linters)
- Purpose: Review implementation against spec, check test coverage, code quality
- Invoked by /spec-verify

### Rules

#### tdd-enforcement.md
- Tests before implementation, always
- RED → GREEN → REFACTOR cycle
- No skipping tests "for now"

#### verification-before-completion.md
- Never claim "done" without running tests
- Evidence before assertions
- Show test output, not just "tests pass"

#### context-continuation.md
- At 80%: prepare handoff notes
- At 90%: write continuation.md and wrap up
- Next session: check for continuation.md before starting fresh

#### coding-standards.md
- Project-appropriate standards (pulled from CLAUDE.md conventions)
- No over-engineering, YAGNI
- Minimal changes, focused PRs

### Runtime State

```
~/.next-level/
├── sessions/
│   └── {session-id}/
│       ├── context-pct.json
│       └── continuation.md
└── specs/
    └── {spec-name}.json
```

## Future Phases

### Phase 2: Dashboard
- Vite/TS web app served locally
- Session viewer, memory timeline, context gauge, cron status
- Read-only view of ~/.next-level/ state

### Phase 3: Memory Integration
- 3-layer recall pattern (search → timeline → detail)
- AutoMem bridge for cross-session persistence
- Session handoff via memory store

## Design Decisions

- **Bash hooks over Python**: No Python 3.12 dependency, works on ARM VM as-is
- **Single plugin**: No dependency management needed between plugins
- **Async context monitor**: Non-blocking, doesn't slow down tool execution
- **Non-blocking TDD enforcer**: Exit 2 = reminder, not blocker. Keeps flow
- **Spec state in JSON files**: Simple, inspectable, no database needed
- **haiku for plan-challenger**: Cheap adversarial review, doesn't need deep reasoning
- **sonnet for spec-reviewer**: Quality review needs more depth than haiku
