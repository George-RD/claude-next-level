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

# Check for destructive commands and force-push (single grep)
BLOCKED_PATTERN='rm -rf /|rm -rf ~|rm -rf \.|git reset --hard|git clean -fd|git checkout \.|git restore \.|git push.*(--force|-f)'

if printf '%s' "$COMMAND" | grep -qE "$BLOCKED_PATTERN"; then
  echo "Blocked dangerous command: ${COMMAND}" >&2
  echo '{"decision":"block","reason":"Dangerous command blocked by bash-guard. Use explicit flags or ask the user to confirm."}'
  exit 2
fi

exit 0
