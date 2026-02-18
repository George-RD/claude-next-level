#!/usr/bin/env bash
# Bash Guard — PreToolUse[Bash] hook
# Blocks destructive commands during active spec execution.
# Exit 2 = blocks the bash command.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

INPUT=$(read_hook_input)
TOOL_NAME=$(json_field "$INPUT" "tool_name")

# Only guard Bash tool
[[ "$TOOL_NAME" == "Bash" ]] || exit 0

COMMAND=$(json_field "$INPUT" "tool_input.command")
[[ -n "$COMMAND" ]] || exit 0

# Check for destructive commands
BLOCKED_PATTERNS=(
  'rm -rf /'
  'rm -rf ~'
  'rm -rf \.'
  'git reset --hard'
  'git clean -fd'
  'git checkout \.'
  'git restore \.'
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if printf '%s' "$COMMAND" | grep -qE "$pattern"; then
    echo "Blocked destructive command: ${COMMAND}" >&2
    echo '{"decision":"block","reason":"Destructive command blocked by bash-guard. Use explicit flags or ask the user to confirm."}'
    exit 2
  fi
done

# Block any force-push (flags can appear anywhere in the command)
if printf '%s' "$COMMAND" | grep -qE 'git push.*(--force|-f)'; then
  echo "Blocked force-push" >&2
  echo '{"decision":"block","reason":"Force-push is blocked by bash-guard. Use a normal push or ask the user to confirm."}'
  exit 2
fi

exit 0
