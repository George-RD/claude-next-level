#!/usr/bin/env bash
# Verification Guard — Stop event hook
# Blocks session end if impl files were edited but no test evidence found.
# Passes through for docs-only sessions.
# Exit 2 = blocking (must run tests before stopping)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

INPUT=$(read_hook_input)

# The stop hook receives the transcript path
TRANSCRIPT=$(json_field "$INPUT" "transcript_path")

# Allow override for testing
TRANSCRIPT="${TRANSCRIPT:-${MOCK_TRANSCRIPT:-}}"

if [[ -z "$TRANSCRIPT" || ! -f "$TRANSCRIPT" ]]; then
  # No transcript available — can't verify, allow stop
  exit 0
fi

# --- Scan transcript for edited impl files ---
# Look for Edit/Write tool calls with file paths
has_impl_edits=false

# Extract file paths from Edit/Write tool uses in the transcript
# Patterns: "file_path": "..." or file_path in tool_input
while IFS= read -r filepath; do
  [[ -z "$filepath" ]] && continue
  if is_impl_file "$filepath"; then
    has_impl_edits=true
    break
  fi
done < <(grep -oE '"file_path"\s*:\s*"[^"]+"' "$TRANSCRIPT" 2>/dev/null \
  | sed 's/"file_path"\s*:\s*"//;s/"$//' \
  || true)

if ! $has_impl_edits; then
  # Docs-only session or no edits detected — allow stop
  exit 0
fi

# --- Check for test evidence ---
if has_test_evidence "$TRANSCRIPT"; then
  exit 0
fi

cat <<EOF
{"result":"Implementation files were edited but no test execution found in this session. Please run tests before ending the session."}
EOF
exit 2
