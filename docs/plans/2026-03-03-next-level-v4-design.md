# next-level v4 Design: Hard Shell, Soft Integrations

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Date:** 2026-03-03
**Goal:** Simplify next-level while making it more capable. Fewer components, clearer philosophy, strict quality enforcement.

---

## Design Principle

**"Hooks enforce. The state machine orchestrates. Integrations enhance."**

Three tiers with different philosophies:

| Tier | Examples | Philosophy |
|------|----------|-----------|
| **Core Quality** | Linting, TDD, verification guards | Strict. Required. No bypass. `/doctor` demands tools upfront. |
| **Workflow** | Spec state machine, review agents | Self-contained. Deterministic. Works without any external plugins. |
| **Integrations** | Context7, pr-review-toolkit, CodeRabbit, AutoMem | Graceful degradation. Use if available, skip if not. |

---

## Change 1: Consolidate Review Agents (5 → 2 + template)

### Problem

Five agents with overlapping concerns:
- `plan-challenger` — challenges plans
- `project-reviewer` — reviews project plans
- `checkpoint-reviewer` — between-task checkpoints
- `spec-reviewer` — reviews implementations
- `coding-agent` — template for subagents

The first three all answer: "Is this plan/progress sound?" The `spec-reviewer` answers: "Is this code good?"

### Design

**`plan-reviewer.md`** — One parameterized agent that replaces three:

```yaml
name: plan-reviewer
description: Adversarial review of plans, projects, and checkpoints. Mode determined by caller.
tools: Read, Grep, Glob, Bash
model: sonnet
maxTurns: 15
```

Modes (passed via prompt context, not config):
- **plan mode**: Challenges a task-level plan (was `plan-challenger`)
- **project mode**: Reviews multi-epic project plan (was `project-reviewer`)
- **checkpoint mode**: Between-task progress check (was `checkpoint-reviewer`)

All three share the same output format: FINDINGS → VERDICT (APPROVE/REVISE/FLAG_FOR_HUMAN/STOP).

The trust escalation logic from `checkpoint-reviewer` stays — it just lives in the checkpoint mode section.

**`code-reviewer.md`** — Enhanced from `spec-reviewer`, adds:
- Performance checklist (activates when: loops, queries, collections, recursion, concurrency detected)
- Security checklist (activates when: user input handling, auth, file I/O, network calls detected)
- Severity scoring per finding (Critical / Important / Suggestion)
- Plan alignment check (carried over from spec-reviewer)

**`coding-agent.md`** — Stays as-is (it's a subagent template, not a reviewer).

### Files to delete

- `agents/plan-challenger.md`
- `agents/project-reviewer.md`
- `agents/checkpoint-reviewer.md`
- `agents/spec-reviewer.md`

### Files to create

- `agents/plan-reviewer.md`
- `agents/code-reviewer.md`

### Files to update
- `skills/spec-plan/SKILL.md` — dispatch `plan-reviewer` (plan mode) instead of `plan-challenger`
- `skills/project/SKILL.md` — dispatch `plan-reviewer` (project mode) instead of `project-reviewer`
- `skills/execute/SKILL.md` — dispatch `plan-reviewer` (checkpoint mode) instead of `checkpoint-reviewer`
- `skills/spec-verify/SKILL.md` — dispatch `code-reviewer` instead of `spec-reviewer`

---

## Change 2: Strict Linting in Hooks

### Problem

`file_checker.py` does AST-level checks and comment stripping but doesn't run actual linters (ruff, eslint, gofmt, clippy). Issue #5 proposed making this opt-in. That's wrong — quality enforcement isn't optional.

### Design

`file_checker.py` gains a new step after existing checks: **run the real linter if it's on PATH**.

```python
# In check_file() after existing AST checks:
linter_findings = run_linter(file_path, language)
if linter_findings:
    findings.extend(linter_findings)
```

Per-language linter dispatch:

| Language | Formatter | Linter | Behavior |
|----------|-----------|--------|----------|
| Python | `ruff format --check` | `ruff check` | Format on write, lint findings as errors |
| TypeScript | `prettier --check` | `eslint` | Format on write, lint findings as errors |
| Go | `gofmt -l` | `golangci-lint run` | Format on write, lint findings as errors |
| Rust | `rustfmt --check` | `cargo clippy` | Format on write, lint findings as errors |
| Swift | `swiftformat --lint` | `swiftlint lint` | Format on write, lint findings as errors |

**If linter not on PATH**: Log a single warning per session (not per edit) directing user to run `/doctor`. Don't silently skip — the user should know they're operating without quality enforcement.

**Exit behavior**: Stays exit code 2 (PostToolUse can't block retroactively). But the feedback message is assertive: "ruff found 3 issues. Fix these before proceeding." Combined with the `coding-standards` rule reinforcement, Claude treats these as requirements, not suggestions.

### `/doctor` changes

Currently `/doctor` reports missing tools as `WARN`. Change to:

- Formatter missing → `FAIL` (not WARN)
- Linter missing → `FAIL` (not WARN)
- LSP missing → `WARN` (nice to have, not blocking)
- Optional plugin missing → `INFO`

The doctor should be blunt: "You're writing Python without ruff. Code quality enforcement is disabled for Python. Install: `uv tool install ruff`"

### Files to modify
- `hooks/scripts/file_checker.py` — add linter dispatch
- `lib/checkers/__init__.py` — add `run_linter()` function
- `lib/checkers/python.py` — add ruff integration
- `lib/checkers/typescript.py` — add eslint/prettier integration
- `lib/checkers/go.py` — add gofmt/golangci-lint integration
- `lib/checkers/rust.py` — add rustfmt/clippy integration
- `lib/checkers/swift.py` — add swiftformat/swiftlint integration
- `skills/doctor/SKILL.md` — change WARN → FAIL for missing formatters/linters

---

## Change 3: Improve Test Evidence Detection (Issue #13)

### Problem

Current `has_test_evidence()` in `utils.sh` greps for strings like "passed", "failed", "pytest" in transcripts. False positives (word "failed" in comments) and false negatives (custom runners).

### Design

Instead of scanning output text, scan for **tool invocations** — look for Bash tool calls where the command matches a test runner pattern:

```bash
# Look for Bash tool_input containing test commands, not output containing "passed"
test_commands='pytest|jest|vitest|mocha|go test|cargo test|swift test|npm test|yarn test|bun test|make test'

# Parse transcript for Bash tool invocations
has_test_invocation() {
  local transcript="$1"
  # Match Bash tool calls with test commands in input
  grep -qE "\"command\"[[:space:]]*:[[:space:]]*\"[^\"]*($test_commands)" "$transcript" 2>/dev/null
}
```

This checks: "Did Claude actually RUN a test command?" not "Did the output contain the word 'passed'?"

### Files to modify
- `hooks/scripts/utils.sh` — rewrite `has_test_evidence()`

---

## Change 4: Context7 Integration in `/spec-plan`

### Problem

During planning, Claude designs solutions using training data which may have outdated API signatures. Context7 MCP provides current library documentation.

### Design

Add a step to `/spec-plan` Phase 3 (after codebase exploration, before solution design):

```markdown
## Process

...
3. **Explore the codebase**: Find relevant files, understand existing patterns
4. **Check current API docs**: If Context7 MCP is available (`mcp__plugin_context7_context7__resolve-library-id`), identify key dependencies from package.json/pyproject.toml/go.mod/Cargo.toml and query Context7 for current API documentation. Focus on packages central to the task, not every dependency.
5. **Design the solution**: ...
```

This is ~5 lines added to one skill. Not a new system.

**Graceful degradation**: "If Context7 MCP is not available, proceed with codebase exploration only. Note in the plan which APIs were not verified against current docs."

### Files to modify
- `skills/spec-plan/SKILL.md` — add Context7 step

---

## Change 5: Documentation Maintenance Step in `/spec-verify`

### Problem

No mechanism to keep project documentation in sync with code changes. READMEs go stale, CHANGELOGs aren't updated.

### Design

Add a check to `/spec-verify` after code review, before the "all checks pass" gate:

```markdown
## Checks

...
5. **Lint clean**: Run configured linters
6. **Documentation check**:
   - If the spec added a new user-facing feature or changed behavior: does the README mention it?
   - If there's a CHANGELOG: does it have an entry for this change?
   - If files in `docs/` reference modified code: are they still accurate?
   - This is a WARN, not a FAIL — flag for human judgment, don't block.
7. **No regressions**: Confirm pre-existing tests still pass
```

The `code-reviewer` agent also gets a documentation section in its checklist:
- "If the implementation adds public API or changes behavior, check if docs need updating"
- This is context-aware — modifying an internal utility doesn't trigger it

### Files to modify
- `skills/spec-verify/SKILL.md` — add documentation check step
- `agents/code-reviewer.md` — add docs checklist section

---

## Change 6: Extend Spec State Machine for PR Cycle

### Problem

The spec workflow ends at VERIFIED. Getting from verified code to a merged PR is manual. Issue #8 requested this.

### Design

Add two states to the spec state machine:

```text
PLANNING → APPROVED → IMPLEMENTING → COMPLETE → VERIFYING → VERIFIED
                                                              ↓
                                                         PR_REVIEW → MERGED
```

New `/spec` routing:

| Status | Action |
|--------|--------|
| VERIFIED | Create PR → move to PR_REVIEW |
| PR_REVIEW | Check PR status, fix review comments, re-push |
| MERGED | Done — report success, close spec |

**PR_REVIEW phase** (added to `/spec` orchestrator, not a new skill):

1. Create branch if not on one: `git checkout -b spec/<slug>`
2. Push and open PR: `gh pr create`
3. If `pr-review-toolkit` is installed: dispatch `/review-pr` for local pre-review
4. If `code-review` plugin is installed: it will auto-review the PR
5. If CodeRabbit is configured on the repo: wait for its review
6. Parse review comments via `gh pr view`
7. Fix issues (dispatch code-reviewer agent or fix inline)
8. Push fixes, wait for re-review
9. After clean review (or user says "merge"): `gh pr merge`
10. Update spec: `{"status": "MERGED"}`

**Graceful degradation**:
- No review plugins installed → still creates PR, relies on human review
- No GitHub access → skip PR, mark VERIFIED as terminal state

### Files to modify
- `skills/spec/SKILL.md` — add PR_REVIEW and MERGED routing
- No new skills needed — it's 30-40 lines added to the existing orchestrator

---

## Change 7: Bugfix Mode (inspired by Pilot Shell)

### Problem

The spec workflow is designed for features. Bugfixes need a different contract: define what MUST change AND what MUST NOT change (no regressions).

### Design

Add a `mode` field to spec JSON:

```json
{
  "name": "fix-auth-bypass",
  "mode": "bugfix",
  "description": "Fix authentication bypass on /api/admin",
  "must_change": ["Authentication check added to /api/admin endpoint"],
  "must_not_change": ["Other endpoints still accessible", "Existing auth flow for normal users"],
  "status": "PLANNING"
}
```

`/spec` auto-detects mode from description keywords ("fix", "bug", "broken", "crash", "error") or user can specify.

In bugfix mode:
- `/spec-plan` focuses on root cause analysis, not multi-approach exploration
- `/spec-implement` requires a **regression test first** (test that reproduces the bug), then the fix
- `/spec-verify` checks both must_change AND must_not_change criteria
- `code-reviewer` gets the behavior contract and validates against it

### Files to modify
- `skills/spec/SKILL.md` — add mode detection
- `skills/spec-plan/SKILL.md` — bugfix-specific planning flow
- `skills/spec-implement/SKILL.md` — regression test first
- `skills/spec-verify/SKILL.md` — behavior contract validation
- `agents/code-reviewer.md` — behavior contract checking

---

## Change 8: Event Logging Foundation

### Problem

Hooks fire-and-forget. There's no record of what was enforced, when, or the outcome. Pilot Shell's dashboard works because every hook writes structured events to a persistent store. We need the same foundation — not a dashboard yet, but the data layer.

### Design

Every hook appends a JSON line to `~/.next-level/events/YYYY-MM-DD.jsonl`:

```jsonl
{"ts":"2026-03-03T14:22:01Z","event":"tdd_check","result":"pass","file":"auth.py","test":"test_auth.py","session":"abc123"}
{"ts":"2026-03-03T14:22:05Z","event":"lint_check","result":"fail","file":"auth.py","findings":3,"tool":"ruff"}
{"ts":"2026-03-03T14:22:10Z","event":"spec_transition","spec":"fix-auth","from":"IMPLEMENTING","to":"COMPLETE"}
{"ts":"2026-03-03T14:23:00Z","event":"verification","result":"pass","spec":"fix-auth","tests_passed":12}
```

Add a `log_event()` function to `utils.sh`:

```bash
log_event() {
  local event="$1" result="$2" extra="$3"
  local ts dir logfile
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  dir="${HOME}/.next-level/events"
  mkdir -p "$dir"
  logfile="${dir}/$(date -u +%Y-%m-%d).jsonl"
  printf '{"ts":"%s","event":"%s","result":"%s"%s}\n' \
    "$ts" "$event" "$result" "${extra:+,$extra}" >> "$logfile"
}
```

Add a `/stats` skill that reads event files and reports:

```text
next-level stats (last 7 days)
==============================
Specs:     3 completed, 1 in progress
Tasks:     12 completed, 2 failed
TDD:       89% compliance (47/53 checks passed)
Linting:   156 checks, 23 findings auto-fixed
Sessions:  8 total, avg 42min
```

### Files to modify
- `hooks/scripts/utils.sh` — add `log_event()`
- All hook scripts — add `log_event` calls at key decision points
- `hooks/scripts/file_checker.py` — add Python equivalent event logging
- New: `skills/stats/SKILL.md` — query and summarize event data

---

## Change 9: Convention Discovery (`/sync`)

### Problem

`/setup` detects languages and tools but doesn't understand the project's actual conventions — tab vs spaces, test file locations, import patterns, monorepo structure. Pilot Shell's `/sync` explores the codebase and generates project-specific rules.

### Design

`/sync` explores the codebase and writes discovered conventions to `~/.next-level/project-conventions.json`:

```json
{
  "project_root": "/Users/george/repos/myapp",
  "discovered_at": "2026-03-03T14:00:00Z",
  "conventions": {
    "indent": "spaces:2",
    "test_pattern": "__tests__/{name}.test.ts",
    "test_framework": "vitest",
    "import_style": "absolute",
    "monorepo": false,
    "ci": "github-actions",
    "package_manager": "bun"
  },
  "file_index": {
    "total_files": 234,
    "by_language": {"typescript": 180, "python": 40, "markdown": 14}
  }
}
```

This feeds into:
- `tdd-enforcer.sh` — knows the actual test file pattern, not guessing
- `file_checker.py` — knows which formatter config to use (prettier vs biome, ruff settings)
- `utils.sh` `find_test_file()` — uses discovered patterns instead of hardcoded guesses
- `/spec-plan` — understands project structure before designing solutions

**Not a search index.** Vexor builds a semantic search index — we don't need that (Claude Code has Glob/Grep/Read). We just need to know the project's conventions so hooks can be accurate.

### Files to create
- `skills/sync/SKILL.md` — convention discovery skill
- `lib/conventions.py` — convention detection logic (analyzes existing code patterns)

### Files to modify
- `hooks/scripts/utils.sh` — read conventions for test patterns
- `hooks/scripts/tdd-enforcer.sh` — use discovered test framework
- `lib/checkers/__init__.py` — respect discovered formatter config

---

## Summary: What Changes

| Component | v3 | v4 | Change |
|-----------|-----|-----|--------|
| Agents | 5 | 2 + template | Consolidated |
| Skills | 12 | 14 | +/sync, +/stats |
| Hooks | 10 | 10 | Enhanced (real linting, better test detection, event logging) |
| Rules | 8 | 8 | Same |
| Spec states | 7 | 9 | +PR_REVIEW, +MERGED |
| Spec modes | 1 (feature) | 2 (+bugfix) | Behavior contracts |
| Event logging | none | JSONL append log | Foundation for observability |
| External deps required | 0 | 0 | Still self-contained |
| External deps optional | 0 | 4 | Context7, pr-review-toolkit, CodeRabbit, AutoMem |

### Open issues addressed
- #5 (linting) — strict, not opt-in
- #8 (PR cycle) — spec state machine extended
- #9 (hooks vs prompts philosophy) — codified in three-tier design
- #12 (README) — documentation check in verify phase
- #13 (test evidence) — tool invocation parsing

### Open issues NOT addressed (defer — see GitHub issues)
- #4 (language test patterns) — incremental, can add anytime
- #6 (CLAUDE_SESSION_ID) — depends on Claude Code exposing env vars
- #7 (pluggable memory) — AutoMem works, file-based fallback is low priority
- #10 (/spec-reset) — quality of life, not architectural
- #11 (endless mode) — orchestrator concern, not plugin concern
- #16 (hook enforcement for agents) — partially solved in v3, needs more Claude Code API support

---

## Implementation Order

1. **Event logging foundation** (Change 8) — add `log_event()` to utils.sh first, all other hooks use it
2. **Agent consolidation** (Change 1) — reduces complexity before adding anything
3. **Test evidence detection** (Change 3) — foundation fix, small scope
4. **Convention discovery /sync** (Change 9) — informs linting and TDD hooks
5. **Strict linting** (Change 2) — biggest quality impact, uses conventions from /sync
6. **Context7 integration** (Change 4) — 5 lines in one file
7. **Documentation check** (Change 5) — small addition to verify phase
8. **Bugfix mode** (Change 7) — new capability, touches several files
9. **PR cycle** (Change 6) — final piece, extends the full workflow end-to-end
