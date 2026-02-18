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

# Check for impl file edits in the transcript
has_impl_edits=false
while IFS= read -r filepath; do
  [[ -z "$filepath" ]] && continue
  if is_impl_file "$filepath"; then
    has_impl_edits=true
    break
  fi
done < <(grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' "$TRANSCRIPT" 2>/dev/null \
  | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//' \
  || true)

# If impl files were edited, require test evidence
if $has_impl_edits; then
  if ! has_test_evidence "$TRANSCRIPT"; then
    echo "Task '${TASK_SUBJECT}' (${TASK_ID}) has impl file edits but no test evidence. Run tests before marking complete." >&2
    exit 2
  fi
fi

exit 0
