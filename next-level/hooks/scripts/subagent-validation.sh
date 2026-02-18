#!/usr/bin/env bash
# Subagent Validation — SubagentStop hook
# Fires when any subagent finishes. Verifies the agent didn't leave broken state.
# Exit 2 = prevents subagent from stopping (sends feedback to continue working)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

INPUT=$(read_hook_input)
AGENT_TYPE=$(json_field "$INPUT" "agent_type")
AGENT_ID=$(json_field "$INPUT" "agent_id")
AGENT_TRANSCRIPT=$(json_field "$INPUT" "agent_transcript_path")

# Only validate coding agents — skip Explore, Plan, etc.
case "$AGENT_TYPE" in
  general-purpose|coding-agent) ;;
  *) exit 0 ;;
esac

# Collect all uncommitted impl files (both unstaged and staged)
HAS_UNCOMMITTED=false
CHANGED_FILES=()
while IFS= read -r changed_file; do
  [[ -z "$changed_file" ]] && continue
  CHANGED_FILES+=("$changed_file")
  if is_impl_file "$changed_file"; then
    HAS_UNCOMMITTED=true
  fi
done < <({ git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null; } | sort -u || true)

# Check 1: Did the agent leave uncommitted changes to impl files without tests?
if $HAS_UNCOMMITTED; then
  if [[ -n "$AGENT_TRANSCRIPT" && -f "$AGENT_TRANSCRIPT" ]]; then
    if ! has_test_evidence "$AGENT_TRANSCRIPT"; then
      echo "Subagent ${AGENT_ID} (${AGENT_TYPE}) has uncommitted impl changes without test evidence. Run tests before finishing." >&2
      exit 2
    fi
  fi
fi

# Check 2: Are there syntax errors in recently changed files?
for changed_file in "${CHANGED_FILES[@]}"; do
  [[ -f "$changed_file" ]] || continue
  ext="${changed_file##*.}"
  case "$ext" in
    py)
      if ! python3 -c "import ast; ast.parse(open('$changed_file').read())" 2>/dev/null; then
        echo "Subagent ${AGENT_ID} left syntax error in ${changed_file}. Fix before finishing." >&2
        exit 2
      fi
      ;;
    json)
      if ! python3 -c "import json; json.load(open('$changed_file'))" 2>/dev/null; then
        echo "Subagent ${AGENT_ID} left invalid JSON in ${changed_file}. Fix before finishing." >&2
        exit 2
      fi
      ;;
  esac
done

exit 0
