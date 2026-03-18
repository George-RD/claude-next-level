#!/usr/bin/env bash
# Task Completion Guard — TaskCompleted hook
# Fires when a task is being marked as completed.
# Enforces that tests have been run before a task can close.
# Exit 2 = prevents task completion, sends feedback.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

INPUT=$(read_hook_input)
TASK_ID=$(json_field "$INPUT" "task_id")
TASK_SUBJECT=$(json_field "$INPUT" "task_subject")
TRANSCRIPT=$(json_field "$INPUT" "transcript_path")

# If no transcript available, allow completion
[[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]] || exit 0

# If impl files were edited, require test evidence
if transcript_has_impl_edits "$TRANSCRIPT"; then
  if ! has_test_evidence "$TRANSCRIPT"; then
    echo "Task '${TASK_SUBJECT}' (${TASK_ID}) has impl file edits but no test evidence. Run tests before marking complete." >&2
    exit 2
  fi
fi

exit 0
