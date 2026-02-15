#!/usr/bin/env bash
# TDD Enforcer — PostToolUse hook for Edit|Write
# Reminds about missing test files (exit 2 = non-blocking)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

INPUT=$(read_hook_input)
TOOL_NAME=$(json_field "$INPUT" "tool_name")
FILE_PATH=$(json_field "$INPUT" "tool_input.file_path")

# Only check Edit and Write tools
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

[[ -z "$FILE_PATH" ]] && exit 0

if ! is_impl_file "$FILE_PATH"; then
  exit 0
fi

if find_test_file "$FILE_PATH" > /dev/null 2>&1; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")
cat <<EOF
{"result":"No test file found for ${BASENAME}. TDD: write a failing test before implementing."}
EOF
exit 2
