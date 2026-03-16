#!/usr/bin/env bash
# SessionStart hook — detects cross-plugin hook conflicts
# Scans all */hooks/hooks.json in the marketplace for overlapping lifecycle events.
# Warns to stderr if multiple plugins register for the same event.
# Non-blocking: always exits 0.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Marketplace root is three levels up from hooks/scripts/
MARKETPLACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Collect all hooks.json files across plugin directories
declare -A event_plugins  # event -> space-separated plugin names

for hooks_file in "$MARKETPLACE_ROOT"/*/hooks/hooks.json; do
  [[ -f "$hooks_file" ]] || continue

  # Extract plugin name from path: <root>/<plugin>/hooks/hooks.json
  plugin_dir="$(dirname "$(dirname "$hooks_file")")"
  plugin_name="$(basename "$plugin_dir")"

  # Extract lifecycle event names from .hooks keys
  events=$(jq -r '.hooks // {} | keys[]' "$hooks_file" 2>/dev/null) || continue

  for event in $events; do
    if [[ -n "${event_plugins[$event]:-}" ]]; then
      event_plugins[$event]="${event_plugins[$event]} $plugin_name"
    else
      event_plugins[$event]="$plugin_name"
    fi
  done
done

# Check for conflicts (multiple plugins on same event)
conflicts=()
for event in "${!event_plugins[@]}"; do
  plugins="${event_plugins[$event]}"
  # Count words (plugin names)
  count=$(echo "$plugins" | wc -w | tr -d ' ')
  if (( count > 1 )); then
    # Format plugin list: "next-level, ralph-wiggum"
    formatted=$(echo "$plugins" | tr ' ' '\n' | sort | paste -sd ',' - | sed 's/,/, /g')
    conflicts+=("$count plugins register $event hooks ($formatted)")
  fi
done

if (( ${#conflicts[@]} > 0 )); then
  echo "Hook audit:" >&2
  for conflict in "${conflicts[@]}"; do
    echo "  - $conflict" >&2
  done
fi

# Never block — always exit 0
exit 0
