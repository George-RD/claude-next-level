#!/usr/bin/env bash
# Teammate Quality Gate — TeammateIdle hook
# Fires when an agent team teammate is about to go idle.
# Enforces quality checks before allowing idle state.
# Exit 2 = prevents idle, sends feedback to continue working.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

INPUT=$(read_hook_input)
TEAMMATE_NAME=$(json_field "$INPUT" "teammate_name")
TRANSCRIPT=$(json_field "$INPUT" "transcript_path")

# Skip review agents and team leads — only gate coding agents
case "$TEAMMATE_NAME" in
  reviewer*|lead*|team-lead*) exit 0 ;;
esac

# Check: Did this teammate edit impl files without test evidence?
if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
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

  if $has_impl_edits; then
    if ! has_test_evidence "$TRANSCRIPT"; then
      echo "Teammate ${TEAMMATE_NAME} edited implementation files but has no test evidence. Run tests before going idle." >&2
      exit 2
    fi
  fi
fi

exit 0
