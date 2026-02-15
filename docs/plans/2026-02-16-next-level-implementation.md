# next-level Plugin Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Claude Code plugin that enforces workflow discipline — context monitoring, spec-driven development, TDD enforcement, and verification guards.

**Architecture:** Single Claude Code plugin with bash hook scripts, markdown skills/agents/rules. Runtime state in `~/.next-level/`. No external dependencies beyond bash and jq.

**Tech Stack:** Bash (hooks), Markdown (skills/agents/rules), jq (JSON parsing), Claude Code plugin API

---

### Task 1: Plugin Scaffold

**Files:**
- Create: `next-level/plugin.json`

**Step 1: Create plugin manifest**

```json
{
  "name": "next-level",
  "description": "Workflow discipline for Claude Code: context monitoring, spec-driven development, TDD enforcement, and verification guards.",
  "version": "0.1.0",
  "author": {
    "name": "George-RD"
  },
  "keywords": ["workflow", "tdd", "spec", "context", "verification", "discipline"]
}
```

**Step 2: Create directory structure**

```bash
mkdir -p next-level/{hooks/scripts,skills/{spec,spec-plan,spec-implement,spec-verify,context-status},agents,rules}
```

**Step 3: Verify plugin loads**

```bash
claude --plugin-dir ./next-level --print 2>&1 | head -5
```

Expected: No errors about invalid plugin.

**Step 4: Commit**

```bash
git add next-level/plugin.json
git commit -m "feat(next-level): scaffold plugin structure"
```

---

### Task 2: Utils Script

**Files:**
- Create: `next-level/hooks/scripts/utils.sh`

Shared helpers for all hook scripts — state directory management, JSON reading, transcript parsing.

**Step 1: Write utils.sh**

```bash
#!/usr/bin/env bash
# Shared utilities for next-level hooks

NEXT_LEVEL_STATE="${HOME}/.next-level"

ensure_state_dir() {
  local session_id="$1"
  local dir="${NEXT_LEVEL_STATE}/sessions/${session_id}"
  mkdir -p "$dir"
  echo "$dir"
}

ensure_specs_dir() {
  mkdir -p "${NEXT_LEVEL_STATE}/specs"
  echo "${NEXT_LEVEL_STATE}/specs"
}

# Read JSON field from stdin hook input
read_hook_input() {
  cat
}

# Get field from JSON string
json_field() {
  local json="$1" field="$2"
  echo "$json" | jq -r ".$field // empty"
}

# Check if file is an implementation file (not test, not config, not docs)
is_impl_file() {
  local filepath="$1"
  local basename
  basename=$(basename "$filepath")
  local ext="${basename##*.}"

  # Skip non-code files
  case "$ext" in
    md|json|yaml|yml|toml|ini|cfg|lock|txt|csv|svg|png|jpg|gif) return 1 ;;
  esac

  # Skip test files
  case "$basename" in
    test_*|*_test.*|*.test.*|*.spec.*|*_test.go) return 1 ;;
  esac

  # Skip common non-impl paths
  case "$filepath" in
    */migrations/*|*/fixtures/*|*/__mocks__/*|*/node_modules/*|*/.git/*) return 1 ;;
  esac

  return 0
}

# Find corresponding test file for an implementation file
find_test_file() {
  local filepath="$1"
  local dir basename name ext
  dir=$(dirname "$filepath")
  basename=$(basename "$filepath")
  name="${basename%.*}"
  ext="${basename##*.}"

  local candidates=()

  case "$ext" in
    py)
      candidates=(
        "${dir}/test_${name}.py"
        "${dir}/${name}_test.py"
        "${dir}/tests/test_${name}.py"
        "${dir}/../tests/test_${name}.py"
      )
      ;;
    ts|tsx)
      candidates=(
        "${dir}/${name}.test.ts"
        "${dir}/${name}.spec.ts"
        "${dir}/${name}.test.tsx"
        "${dir}/${name}.spec.tsx"
        "${dir}/__tests__/${name}.test.ts"
        "${dir}/__tests__/${name}.spec.ts"
      )
      ;;
    js|jsx)
      candidates=(
        "${dir}/${name}.test.js"
        "${dir}/${name}.spec.js"
        "${dir}/${name}.test.jsx"
        "${dir}/${name}.spec.jsx"
        "${dir}/__tests__/${name}.test.js"
        "${dir}/__tests__/${name}.spec.js"
      )
      ;;
    go)
      candidates=(
        "${dir}/${name}_test.go"
      )
      ;;
  esac

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

# Check transcript for test runner evidence
has_test_evidence() {
  local transcript_path="$1"
  if [[ ! -f "$transcript_path" ]]; then
    return 1
  fi
  # Look for common test runner output patterns
  grep -qE '(PASS|FAIL|passed|failed|test[s]? ran|pytest|jest|vitest|go test|✓|✗|Tests:)' "$transcript_path"
}
```

**Step 2: Make executable**

```bash
chmod +x next-level/hooks/scripts/utils.sh
```

**Step 3: Verify sourcing works**

```bash
bash -c 'source next-level/hooks/scripts/utils.sh && echo "STATE_DIR: $NEXT_LEVEL_STATE" && is_impl_file "src/app.ts" && echo "impl=yes" || echo "impl=no"'
```

Expected: `STATE_DIR: /Users/george/.next-level` and `impl=yes`

**Step 4: Commit**

```bash
git add next-level/hooks/scripts/utils.sh
git commit -m "feat(next-level): add shared utils for hook scripts"
```

---

### Task 3: TDD Enforcer Hook

**Files:**
- Create: `next-level/hooks/scripts/tdd-enforcer.sh`

**Step 1: Write the test script**

Create a simple test harness that pipes mock hook input:

```bash
# File: next-level/hooks/scripts/test-tdd-enforcer.sh
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Test 1: Impl file without test should exit 2
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/auth.ts","old_string":"x","new_string":"y"}}' \
  | "$SCRIPT_DIR/tdd-enforcer.sh" /tmp/test-project
EXIT=$?
if [[ $EXIT -eq 2 ]]; then
  echo "PASS: impl file without test -> exit 2"
else
  echo "FAIL: expected exit 2, got $EXIT"
  exit 1
fi

# Test 2: Test file edit should exit 0 (pass through)
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/auth.test.ts","old_string":"x","new_string":"y"}}' \
  | "$SCRIPT_DIR/tdd-enforcer.sh" /tmp/test-project
EXIT=$?
if [[ $EXIT -eq 0 ]]; then
  echo "PASS: test file edit -> exit 0"
else
  echo "FAIL: expected exit 0, got $EXIT"
  exit 1
fi

# Test 3: Markdown file should exit 0 (skip)
echo '{"tool_name":"Edit","tool_input":{"file_path":"docs/README.md","old_string":"x","new_string":"y"}}' \
  | "$SCRIPT_DIR/tdd-enforcer.sh" /tmp/test-project
EXIT=$?
if [[ $EXIT -eq 0 ]]; then
  echo "PASS: markdown edit -> exit 0"
else
  echo "FAIL: expected exit 0, got $EXIT"
  exit 1
fi

# Test 4: Non-Edit tool should exit 0 (skip)
echo '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' \
  | "$SCRIPT_DIR/tdd-enforcer.sh" /tmp/test-project
EXIT=$?
if [[ $EXIT -eq 0 ]]; then
  echo "PASS: non-Edit tool -> exit 0"
else
  echo "FAIL: expected exit 0, got $EXIT"
  exit 1
fi

echo "All TDD enforcer tests passed"
```

**Step 2: Run test to verify it fails**

```bash
chmod +x next-level/hooks/scripts/test-tdd-enforcer.sh
bash next-level/hooks/scripts/test-tdd-enforcer.sh
```

Expected: FAIL (tdd-enforcer.sh doesn't exist yet)

**Step 3: Write tdd-enforcer.sh**

```bash
#!/usr/bin/env bash
# TDD Enforcer — PostToolUse hook for Edit|Write
# Reminds about missing test files (exit 2 = non-blocking)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Read hook input from stdin
INPUT=$(read_hook_input)
TOOL_NAME=$(json_field "$INPUT" "tool_name")
FILE_PATH=$(json_field "$INPUT" "tool_input.file_path")

# Only check Edit and Write tools
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

# Skip if no file path
[[ -z "$FILE_PATH" ]] && exit 0

# Skip non-implementation files
if ! is_impl_file "$FILE_PATH"; then
  exit 0
fi

# Check for corresponding test file
if find_test_file "$FILE_PATH" > /dev/null 2>&1; then
  exit 0
fi

# No test file found — non-blocking reminder
BASENAME=$(basename "$FILE_PATH")
cat <<EOF
{"result":"No test file found for ${BASENAME}. TDD: write a failing test before implementing."}
EOF
exit 2
```

**Step 4: Run tests to verify they pass**

```bash
chmod +x next-level/hooks/scripts/tdd-enforcer.sh
bash next-level/hooks/scripts/test-tdd-enforcer.sh
```

Expected: All 4 tests pass.

**Step 5: Commit**

```bash
git add next-level/hooks/scripts/tdd-enforcer.sh next-level/hooks/scripts/test-tdd-enforcer.sh
git commit -m "feat(next-level): add TDD enforcer hook with tests"
```

---

### Task 4: Context Monitor Hook

**Files:**
- Create: `next-level/hooks/scripts/context-monitor.sh`

**Step 1: Write the test script**

```bash
# File: next-level/hooks/scripts/test-context-monitor.sh
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Use temp state dir for testing
export NEXT_LEVEL_STATE=$(mktemp -d)
trap "rm -rf $NEXT_LEVEL_STATE" EXIT

# Test 1: Normal context (< 80%) should exit 0 silently
echo '{"session_id":"test-123","transcript_path":"/tmp/fake-transcript.jsonl"}' \
  | MOCK_CONTEXT_PCT=50 "$SCRIPT_DIR/context-monitor.sh"
EXIT=$?
if [[ $EXIT -eq 0 ]]; then
  echo "PASS: 50% context -> exit 0"
else
  echo "FAIL: expected exit 0, got $EXIT"
  exit 1
fi

# Test 2: 80% should produce a warning (exit 0 with message)
OUTPUT=$(echo '{"session_id":"test-456","transcript_path":"/tmp/fake-transcript.jsonl"}' \
  | MOCK_CONTEXT_PCT=82 "$SCRIPT_DIR/context-monitor.sh" 2>&1)
EXIT=$?
if [[ $EXIT -eq 0 ]] && echo "$OUTPUT" | grep -q "80%"; then
  echo "PASS: 82% context -> warning message"
else
  echo "FAIL: expected warning at 82%, got exit=$EXIT output=$OUTPUT"
  exit 1
fi

# Test 3: 92% should produce handoff instruction (exit 0 with handoff message)
OUTPUT=$(echo '{"session_id":"test-789","transcript_path":"/tmp/fake-transcript.jsonl"}' \
  | MOCK_CONTEXT_PCT=92 "$SCRIPT_DIR/context-monitor.sh" 2>&1)
EXIT=$?
if echo "$OUTPUT" | grep -qi "handoff\|continuation"; then
  echo "PASS: 92% context -> handoff instruction"
else
  echo "FAIL: expected handoff at 92%, got exit=$EXIT output=$OUTPUT"
  exit 1
fi

# Test 4: State file should be created
if [[ -f "${NEXT_LEVEL_STATE}/sessions/test-789/context-pct.json" ]]; then
  echo "PASS: state file created"
else
  echo "FAIL: state file not created"
  exit 1
fi

echo "All context monitor tests passed"
```

**Step 2: Run test to verify it fails**

```bash
chmod +x next-level/hooks/scripts/test-context-monitor.sh
bash next-level/hooks/scripts/test-context-monitor.sh
```

Expected: FAIL (context-monitor.sh doesn't exist)

**Step 3: Write context-monitor.sh**

```bash
#!/usr/bin/env bash
# Context Monitor — PostToolUse hook (async)
# Tracks context usage and triggers handoff at thresholds
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

INPUT=$(read_hook_input)
SESSION_ID=$(json_field "$INPUT" "session_id")
TRANSCRIPT_PATH=$(json_field "$INPUT" "transcript_path")

[[ -z "$SESSION_ID" ]] && exit 0

STATE_DIR=$(ensure_state_dir "$SESSION_ID")
PCT_FILE="${STATE_DIR}/context-pct.json"
CONTINUATION_FILE="${STATE_DIR}/continuation.md"

# Throttle: skip if checked recently and was under 80%
if [[ -f "$PCT_FILE" ]]; then
  LAST_CHECK=$(json_field "$(cat "$PCT_FILE")" "timestamp")
  LAST_PCT=$(json_field "$(cat "$PCT_FILE")" "pct")
  NOW=$(date +%s)
  if [[ -n "$LAST_CHECK" && -n "$LAST_PCT" ]]; then
    ELAPSED=$(( NOW - LAST_CHECK ))
    if [[ $ELAPSED -lt 30 && $LAST_PCT -lt 80 ]]; then
      exit 0
    fi
  fi
fi

# Get context percentage
# In production: parse from transcript or Claude Code internals
# MOCK_CONTEXT_PCT env var for testing
if [[ -n "${MOCK_CONTEXT_PCT:-}" ]]; then
  CONTEXT_PCT="$MOCK_CONTEXT_PCT"
elif [[ -f "$TRANSCRIPT_PATH" ]]; then
  # Estimate from transcript file size (rough heuristic)
  # Claude Code context ~200k tokens, transcript ~4 bytes/token
  FILE_SIZE=$(wc -c < "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)
  MAX_SIZE=800000  # ~200k tokens * 4 bytes
  CONTEXT_PCT=$(( FILE_SIZE * 100 / MAX_SIZE ))
  [[ $CONTEXT_PCT -gt 100 ]] && CONTEXT_PCT=100
else
  CONTEXT_PCT=0
fi

# Save state
cat > "$PCT_FILE" <<EOF
{"pct":${CONTEXT_PCT},"timestamp":$(date +%s),"session_id":"${SESSION_ID}"}
EOF

# Threshold actions
if [[ $CONTEXT_PCT -ge 95 ]]; then
  cat <<EOF
{"result":"CRITICAL: Context at ${CONTEXT_PCT}%. STOP immediately. Run /context-status for handoff, then start a new session.","suppressOutput":false}
EOF
elif [[ $CONTEXT_PCT -ge 90 ]]; then
  # Write continuation file
  cat > "$CONTINUATION_FILE" <<CONT
# Session Continuation

**Previous session**: ${SESSION_ID}
**Context at exit**: ${CONTEXT_PCT}%
**Timestamp**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Handoff Notes

<!-- The previous session should fill this in before ending -->
- Current task:
- Progress:
- Next steps:
- Blockers:
CONT

  cat <<EOF
{"result":"Context at ${CONTEXT_PCT}%. Time to handoff. Write your continuation notes:\n1. Summarize current progress\n2. List next steps\n3. Note any blockers\nThen start a fresh session — it will pick up from continuation.md","suppressOutput":false}
EOF
elif [[ $CONTEXT_PCT -ge 80 ]]; then
  cat <<EOF
{"result":"Context at ${CONTEXT_PCT}%. Approaching limit. Start wrapping up your current task and prepare handoff notes.","suppressOutput":false}
EOF
fi

exit 0
```

**Step 4: Run tests to verify they pass**

```bash
chmod +x next-level/hooks/scripts/context-monitor.sh
bash next-level/hooks/scripts/test-context-monitor.sh
```

Expected: All 4 tests pass.

**Step 5: Commit**

```bash
git add next-level/hooks/scripts/context-monitor.sh next-level/hooks/scripts/test-context-monitor.sh
git commit -m "feat(next-level): add context monitor hook with tests"
```

---

### Task 5: Verification Guard Hook

**Files:**
- Create: `next-level/hooks/scripts/verification-guard.sh`

**Step 1: Write the test script**

```bash
# File: next-level/hooks/scripts/test-verification-guard.sh
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Test 1: Session with impl edits but no test evidence -> exit 2
TRANSCRIPT="$TMPDIR/transcript-no-tests.jsonl"
cat > "$TRANSCRIPT" <<'EOF'
{"type":"tool_use","tool_name":"Edit","tool_input":{"file_path":"src/auth.ts"}}
{"type":"tool_result","content":"file edited"}
EOF
echo "{\"session_id\":\"test-1\",\"transcript_path\":\"$TRANSCRIPT\"}" \
  | "$SCRIPT_DIR/verification-guard.sh"
EXIT=$?
if [[ $EXIT -eq 2 ]]; then
  echo "PASS: impl edits without tests -> exit 2"
else
  echo "FAIL: expected exit 2, got $EXIT"
  exit 1
fi

# Test 2: Session with impl edits AND test evidence -> exit 0
TRANSCRIPT="$TMPDIR/transcript-with-tests.jsonl"
cat > "$TRANSCRIPT" <<'EOF'
{"type":"tool_use","tool_name":"Edit","tool_input":{"file_path":"src/auth.ts"}}
{"type":"tool_use","tool_name":"Bash","tool_input":{"command":"npm test"}}
{"type":"tool_result","content":"Tests: 5 passed, 0 failed"}
EOF
echo "{\"session_id\":\"test-2\",\"transcript_path\":\"$TRANSCRIPT\"}" \
  | "$SCRIPT_DIR/verification-guard.sh"
EXIT=$?
if [[ $EXIT -eq 0 ]]; then
  echo "PASS: impl edits with tests -> exit 0"
else
  echo "FAIL: expected exit 0, got $EXIT"
  exit 1
fi

# Test 3: Docs-only session -> exit 0
TRANSCRIPT="$TMPDIR/transcript-docs.jsonl"
cat > "$TRANSCRIPT" <<'EOF'
{"type":"tool_use","tool_name":"Edit","tool_input":{"file_path":"docs/README.md"}}
EOF
echo "{\"session_id\":\"test-3\",\"transcript_path\":\"$TRANSCRIPT\"}" \
  | "$SCRIPT_DIR/verification-guard.sh"
EXIT=$?
if [[ $EXIT -eq 0 ]]; then
  echo "PASS: docs-only session -> exit 0"
else
  echo "FAIL: expected exit 0, got $EXIT"
  exit 1
fi

echo "All verification guard tests passed"
```

**Step 2: Run test to verify it fails**

```bash
chmod +x next-level/hooks/scripts/test-verification-guard.sh
bash next-level/hooks/scripts/test-verification-guard.sh
```

Expected: FAIL

**Step 3: Write verification-guard.sh**

```bash
#!/usr/bin/env bash
# Verification Guard — Stop hook
# Blocks session end if impl files were edited but no tests were run
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

INPUT=$(read_hook_input)
TRANSCRIPT_PATH=$(json_field "$INPUT" "transcript_path")

# No transcript = nothing to check
[[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]] && exit 0

# Check if any implementation files were edited
HAS_IMPL_EDITS=false
while IFS= read -r line; do
  TOOL=$(echo "$line" | jq -r '.tool_name // empty' 2>/dev/null)
  FILE=$(echo "$line" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  if [[ "$TOOL" == "Edit" || "$TOOL" == "Write" ]] && [[ -n "$FILE" ]]; then
    if is_impl_file "$FILE"; then
      HAS_IMPL_EDITS=true
      break
    fi
  fi
done < "$TRANSCRIPT_PATH"

# No impl edits = no verification needed
if ! $HAS_IMPL_EDITS; then
  exit 0
fi

# Check for test runner evidence in transcript
if has_test_evidence "$TRANSCRIPT_PATH"; then
  exit 0
fi

# Impl edits without test evidence — block
cat <<EOF
{"result":"Implementation files were modified but no tests were run. Please run your test suite before finishing."}
EOF
exit 2
```

**Step 4: Run tests to verify they pass**

```bash
chmod +x next-level/hooks/scripts/verification-guard.sh
bash next-level/hooks/scripts/test-verification-guard.sh
```

Expected: All 3 tests pass.

**Step 5: Commit**

```bash
git add next-level/hooks/scripts/verification-guard.sh next-level/hooks/scripts/test-verification-guard.sh
git commit -m "feat(next-level): add verification guard hook with tests"
```

---

### Task 6: hooks.json Configuration

**Files:**
- Create: `next-level/hooks/hooks.json`

**Step 1: Write hooks.json**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/tdd-enforcer.sh",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/context-monitor.sh",
            "timeout": 10,
            "async": true
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/verification-guard.sh",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

**Step 2: Verify JSON is valid**

```bash
jq . next-level/hooks/hooks.json
```

Expected: Pretty-printed JSON with no errors.

**Step 3: Commit**

```bash
git add next-level/hooks/hooks.json
git commit -m "feat(next-level): wire hook scripts in hooks.json"
```

---

### Task 7: Rules

**Files:**
- Create: `next-level/rules/tdd-enforcement.md`
- Create: `next-level/rules/verification-before-completion.md`
- Create: `next-level/rules/context-continuation.md`
- Create: `next-level/rules/coding-standards.md`

**Step 1: Write all four rules**

`tdd-enforcement.md`:
```markdown
# TDD Enforcement

- Write a failing test BEFORE writing implementation code
- Follow RED → GREEN → REFACTOR cycle strictly
- Never skip tests "to save time" or "just this once"
- If editing an implementation file, check that a corresponding test file exists
- If no test file exists, create one first with a failing test
```

`verification-before-completion.md`:
```markdown
# Verification Before Completion

- Never claim work is "done" or "complete" without running the test suite
- Show actual test output — don't just say "tests pass"
- If tests fail, fix them before claiming completion
- Evidence before assertions: run the command, show the output, then state the conclusion
```

`context-continuation.md`:
```markdown
# Context Continuation

- When context reaches 80%, start wrapping up your current subtask
- At 90%, write handoff notes: current progress, next steps, blockers
- At 95%, stop immediately and hand off — do not start new work
- When starting a fresh session, check for ~/.next-level/sessions/*/continuation.md
- If a continuation file exists, read it and resume from where the previous session left off
```

`coding-standards.md`:
```markdown
# Coding Standards

- YAGNI: Don't build what isn't needed yet
- DRY: Don't repeat yourself, but don't prematurely abstract either
- Minimal changes: Only modify what's needed for the current task
- No gold-plating: Don't improve adjacent code unless asked
- Commit frequently: Small, focused commits with clear messages
```

**Step 2: Verify files exist and are valid markdown**

```bash
ls next-level/rules/*.md | wc -l
```

Expected: 4

**Step 3: Commit**

```bash
git add next-level/rules/
git commit -m "feat(next-level): add workflow rules"
```

---

### Task 8: Spec Workflow Skills

**Files:**
- Create: `next-level/skills/spec/SKILL.md`
- Create: `next-level/skills/spec-plan/SKILL.md`
- Create: `next-level/skills/spec-implement/SKILL.md`
- Create: `next-level/skills/spec-verify/SKILL.md`
- Create: `next-level/skills/context-status/SKILL.md`

**Step 1: Write /spec dispatcher**

`next-level/skills/spec/SKILL.md`:
```markdown
---
name: spec
description: Start or continue a spec-driven development workflow. Orchestrates plan → implement → verify cycle with approval gates.
user-invocable: true
argument-hint: "[task description]"
---

# Spec-Driven Development

Orchestrate structured development through three phases: **plan**, **implement**, **verify**.

## Usage

`/next-level:spec <task description>`

## Workflow

1. Check for existing spec state in `~/.next-level/specs/`
2. Route to the correct phase based on status:

| Status | Action |
|--------|--------|
| No spec | Create new spec, run /next-level:spec-plan |
| PLANNING | Continue /next-level:spec-plan |
| APPROVED | Run /next-level:spec-implement |
| IMPLEMENTING | Continue /next-level:spec-implement |
| COMPLETE | Run /next-level:spec-verify |
| VERIFYING | Continue /next-level:spec-verify |
| VERIFIED | Done — report success |
| FAILED | Back to /next-level:spec-implement with feedback |

## Starting a New Spec

1. Create spec file at `~/.next-level/specs/<slug>.json`:
```json
{
  "name": "<slug>",
  "description": "$ARGUMENTS",
  "status": "PLANNING",
  "created": "<timestamp>",
  "plan": null,
  "feedback": []
}
```
2. Invoke /next-level:spec-plan with the description

## Continuing an Existing Spec

1. Read the spec file
2. Check current status
3. Route to the appropriate skill

## Context Check

Before starting any phase, check context usage. If above 80%, write continuation notes instead of starting a new phase.
```

**Step 2: Write /spec-plan**

`next-level/skills/spec-plan/SKILL.md`:
```markdown
---
name: spec-plan
description: Design phase of spec workflow. Explores codebase, designs solution, gets user approval.
user-invocable: true
argument-hint: "[task description]"
---

# Spec Plan Phase

Design a solution for the task. Output a plan document for user approval.

## Process

1. **Understand the task**: Read $ARGUMENTS or the spec file description
2. **Explore the codebase**: Find relevant files, understand existing patterns
3. **Design the solution**: Consider 2-3 approaches, recommend one
4. **Write the plan**: Concrete steps with file paths, code changes, test strategy
5. **Challenge the plan**: Invoke the plan-challenger agent to find weaknesses
6. **Present to user**: Show the plan with challenger feedback, ask for approval

## Plan Document Format

Write the plan to the project's `docs/plans/` directory:

```
### Goal
One sentence.

### Approach
Which approach and why.

### Steps
1. Step with exact file paths
2. Step with exact file paths
...

### Test Strategy
What to test and how.

### Risks
What could go wrong.
```

## After Approval

Update spec status to `APPROVED`:
```json
{"status": "APPROVED", "plan": "<path-to-plan-doc>"}
```

Then invoke /next-level:spec-implement.

## If Rejected

Incorporate feedback and re-plan. Do not move to implementation without explicit approval.
```

**Step 3: Write /spec-implement**

`next-level/skills/spec-implement/SKILL.md`:
```markdown
---
name: spec-implement
description: Implementation phase of spec workflow. TDD execution of the approved plan.
user-invocable: true
---

# Spec Implement Phase

Execute the approved plan using strict TDD.

## Process

1. **Read the plan**: Load from spec file's `plan` path
2. **For each step in the plan**:
   a. Write a failing test (RED)
   b. Run the test — confirm it fails
   c. Write minimal implementation (GREEN)
   d. Run the test — confirm it passes
   e. Refactor if needed — tests still pass
   f. Commit with clear message
3. **After all steps**: Update spec status to `COMPLETE`

## Rules

- NEVER write implementation before the failing test
- NEVER skip running tests between steps
- Keep commits small and focused — one step per commit
- If the plan is wrong, note the issue but follow it. Flag for /spec-verify.

## On Completion

Update spec status:
```json
{"status": "COMPLETE"}
```

Then invoke /next-level:spec-verify.
```

**Step 4: Write /spec-verify**

`next-level/skills/spec-verify/SKILL.md`:
```markdown
---
name: spec-verify
description: Verification phase of spec workflow. Validates implementation against plan.
user-invocable: true
---

# Spec Verify Phase

Validate the implementation is correct, complete, and clean.

## Checks

1. **Tests pass**: Run the full test suite, show output
2. **Plan coverage**: Every plan step has corresponding code and tests
3. **Code review**: Invoke spec-reviewer agent for quality + compliance
4. **Lint clean**: Run any configured linters
5. **No regressions**: Existing tests still pass

## If All Checks Pass

Update spec status:
```json
{"status": "VERIFIED"}
```

Report success to the user.

## If Checks Fail

Update spec status with feedback:
```json
{"status": "FAILED", "feedback": ["specific issue 1", "specific issue 2"]}
```

Route back to /next-level:spec-implement with the specific feedback.
```

**Step 5: Write /context-status**

`next-level/skills/context-status/SKILL.md`:
```markdown
---
name: context-status
description: Show current context usage, active spec status, and continuation state.
user-invocable: true
---

# Context Status

Show the current session state at a glance.

## Display

1. **Context usage**: Read from `~/.next-level/sessions/{session-id}/context-pct.json`
2. **Active spec**: Check `~/.next-level/specs/` for non-VERIFIED specs
3. **Continuation**: Check for any `continuation.md` files from previous sessions

## Format

```
CONTEXT STATUS
──────────────
Context:      67% (OK)
Active spec:  "add-user-auth" — IMPLEMENTING (step 3/7)
Continuation: None pending

RECENT SESSIONS
──────────────
Session abc123: 45% (completed)
Session def456: 92% (handed off → continuation.md exists)
```

If continuation.md exists from a previous session, display its contents and ask if the user wants to resume that work.
```

**Step 6: Verify all skills exist**

```bash
find next-level/skills -name "SKILL.md" | sort
```

Expected: 5 SKILL.md files.

**Step 7: Commit**

```bash
git add next-level/skills/
git commit -m "feat(next-level): add spec workflow and context-status skills"
```

---

### Task 9: Agents

**Files:**
- Create: `next-level/agents/plan-challenger.md`
- Create: `next-level/agents/spec-reviewer.md`

**Step 1: Write plan-challenger agent**

```markdown
---
name: plan-challenger
description: Adversarial review of implementation plans. Finds holes, missing edge cases, security issues, and over-engineering.
tools: Read, Grep, Glob
model: haiku
maxTurns: 10
---

# Plan Challenger

You are an adversarial reviewer. Your job is to find problems with the plan, NOT to praise it.

## Review Checklist

For each plan you review, check:

1. **Missing edge cases**: What inputs or scenarios aren't covered?
2. **Security**: Any injection, auth bypass, data exposure risks?
3. **Over-engineering**: Is anything more complex than needed? YAGNI violations?
4. **Under-engineering**: Is anything too simple and will break under real use?
5. **Test gaps**: What's not being tested that should be?
6. **Dependencies**: Any missing prerequisites or ordering issues?
7. **Rollback**: How do you undo this if it goes wrong?

## Output Format

```
PLAN REVIEW
───────────
Issues found: N

CRITICAL (must fix):
- Issue description → suggested fix

WARNINGS (should fix):
- Issue description → suggested fix

NITPICKS (optional):
- Issue description
```

Be specific. Reference exact plan steps. Don't pad with praise.
```

**Step 2: Write spec-reviewer agent**

```markdown
---
name: spec-reviewer
description: Quality and compliance review of implementations. Checks code quality, test coverage, and adherence to the spec plan.
tools: Read, Grep, Glob, Bash
model: sonnet
maxTurns: 20
---

# Spec Reviewer

Review the implementation against the approved plan.

## Review Process

1. **Read the plan** from the spec file path
2. **Check each plan step** has corresponding implementation
3. **Review code quality**:
   - No dead code or commented-out blocks
   - Clear naming and structure
   - Appropriate error handling (not over-handled)
   - Follows existing codebase patterns
4. **Check test quality**:
   - Tests actually test behavior, not implementation details
   - Edge cases covered
   - Tests are readable and maintainable
5. **Run the test suite** to confirm everything passes

## Output Format

```
SPEC REVIEW
───────────
Plan steps completed: X/Y

ISSUES:
- [file:line] Issue description

TEST COVERAGE:
- [gap] What's not tested

VERDICT: PASS | FAIL
```

If FAIL, list exactly what needs to be fixed. Be specific with file paths and line numbers.
```

**Step 3: Commit**

```bash
git add next-level/agents/
git commit -m "feat(next-level): add plan-challenger and spec-reviewer agents"
```

---

### Task 10: Integration Test

**Step 1: Test plugin loads in Claude Code**

```bash
cd /Users/george/repos/claude-next-level
claude --plugin-dir ./next-level --print 2>&1 | grep -i "next-level\|error\|warn"
```

Expected: Plugin loads without errors.

**Step 2: Verify all hooks are wired**

```bash
jq '.hooks | keys' next-level/hooks/hooks.json
```

Expected: `["PostToolUse", "Stop"]`

**Step 3: Run all hook test suites**

```bash
bash next-level/hooks/scripts/test-tdd-enforcer.sh && \
bash next-level/hooks/scripts/test-context-monitor.sh && \
bash next-level/hooks/scripts/test-verification-guard.sh
```

Expected: All tests pass.

**Step 4: Final commit**

```bash
git add -A next-level/
git commit -m "feat(next-level): complete v0.1.0 plugin — workflow discipline"
```

---

## Execution Summary

| Task | Description | Est. Complexity |
|------|-------------|-----------------|
| 1 | Plugin scaffold | Trivial |
| 2 | Utils script | Small |
| 3 | TDD enforcer hook + tests | Medium |
| 4 | Context monitor hook + tests | Medium |
| 5 | Verification guard hook + tests | Medium |
| 6 | hooks.json wiring | Small |
| 7 | Rules (4 markdown files) | Small |
| 8 | Skills (5 SKILL.md files) | Medium |
| 9 | Agents (2 definitions) | Small |
| 10 | Integration test | Small |

Total: 10 tasks, ~20 files to create.
