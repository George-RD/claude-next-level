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
if ! transcript_has_impl_edits "$TRANSCRIPT"; then
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
