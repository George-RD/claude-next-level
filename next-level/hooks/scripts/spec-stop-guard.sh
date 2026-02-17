#!/usr/bin/env bash
# Spec Stop Guard — Stop event hook
# Blocks session end if an active spec is in PLANNING, IMPLEMENTING, or COMPLETE state.
# 60-second escape hatch: stop twice within 60s to force exit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

SPECS_DIR=$(ensure_specs_dir)
ESCAPE_FILE="${NEXT_LEVEL_STATE}/last_stop_attempt"

# --- Escape hatch: stop twice within 60s to force exit ---
now=$(date +%s)
if [[ -f "$ESCAPE_FILE" ]]; then
  last_attempt=$(cat "$ESCAPE_FILE")
  elapsed=$((now - last_attempt))
  if [[ "$elapsed" -lt 60 ]]; then
    rm -f "$ESCAPE_FILE"
    exit 0  # Allow stop — user confirmed by stopping twice
  fi
fi

# --- Check for active specs ---
active_specs=()
for spec_file in "$SPECS_DIR"/*.json; do
  [[ -f "$spec_file" ]] || continue

  status=$(jq -r '.status // empty' "$spec_file" 2>/dev/null) || continue

  case "$status" in
    PLANNING|IMPLEMENTING|COMPLETE)
      name=$(jq -r '.name // "unknown"' "$spec_file" 2>/dev/null)
      active_specs+=("${name} (${status})")
      ;;
  esac
done

if [[ ${#active_specs[@]} -eq 0 ]]; then
  rm -f "$ESCAPE_FILE"
  exit 0  # No active specs — allow stop
fi

# Record this stop attempt for escape hatch
echo "$now" > "$ESCAPE_FILE"

# Build message listing active specs
spec_list=$(printf ', %s' "${active_specs[@]}")
spec_list="${spec_list:2}"  # Remove leading comma+space

jq -n --arg specs "$spec_list" '{"result":"Active spec(s) in progress: \($specs). Complete or pause the spec before stopping. To force exit, stop again within 60 seconds."}'
exit 2
