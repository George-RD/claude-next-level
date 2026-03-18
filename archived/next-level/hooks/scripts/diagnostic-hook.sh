#!/usr/bin/env bash
# Diagnostic Hook — logs PostToolUse events to understand hook propagation
# Install as a GLOBAL hook in ~/.claude/settings.json to test if hooks fire
# inside /batch agent sessions, subagent sessions, and normal sessions.
#
# Usage: Add to ~/.claude/settings.json under hooks.PostToolUse
# Log output: /private/tmp/claude-next-level-diagnostic/hook-events.jsonl
set -euo pipefail

LOG_DIR="/private/tmp/claude-next-level-diagnostic"
LOG_FILE="${LOG_DIR}/hook-events.jsonl"
mkdir -p "$LOG_DIR"

# Read hook input from stdin
INPUT=$(cat)

# Extract what we can from the environment and input
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null || echo "unknown")
TOOL_INPUT_FILE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SESSION_ID="${CLAUDE_SESSION_ID:-no-session-id}"
PID="$$"
PPID_VAL="${PPID:-unknown}"
CWD="$(pwd)"
REPO_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$CWD")
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
IS_WORKTREE="false"
if git rev-parse --git-common-dir &>/dev/null; then
  GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo "")
  GIT_COMMON=$(git rev-parse --git-common-dir 2>/dev/null || echo "")
  if [[ "$GIT_DIR" != "$GIT_COMMON" ]]; then
    IS_WORKTREE="true"
  fi
fi

AGENT_CONTEXT="main-session"
if [[ "$IS_WORKTREE" == "true" ]]; then
  AGENT_CONTEXT="worktree-session"
fi

# Write structured log entry — no locking, diagnostic only
printf '{"ts":"%s","tool":"%s","file":"%s","repo":"%s","branch":"%s","cwd":"%s","is_worktree":%s,"agent_context":"%s","session_id":"%s","pid":%s,"ppid":%s}\n' \
  "$TIMESTAMP" \
  "$TOOL_NAME" \
  "$TOOL_INPUT_FILE" \
  "$REPO_NAME" \
  "$BRANCH" \
  "$CWD" \
  "$IS_WORKTREE" \
  "$AGENT_CONTEXT" \
  "$SESSION_ID" \
  "$PID" \
  "$PPID_VAL" \
  >> "$LOG_FILE"

exit 0
