#!/bin/bash
# bump-version.sh — Bump plugin version in both plugin.json and marketplace.json
#
# Usage:
#   ./scripts/bump-version.sh <plugin-name> <new-version>
#   ./scripts/bump-version.sh ralph-wiggum-toolkit 0.2.0
#   ./scripts/bump-version.sh --check   # Verify all versions match
#
# This ensures plugin.json and marketplace.json never diverge, which
# causes the plugin cache to serve stale versions.

set -euo pipefail

MARKETPLACE=".claude-plugin/marketplace.json"

die() { echo "Error: $1" >&2; exit 1; }

# ── Check mode: verify all plugin.json versions match marketplace.json ──
if [[ "${1:-}" == "--check" ]]; then
  errors=0
  for plugin_json in */plugin.json; do
    dir=$(dirname "$plugin_json")
    name=$(jq -r '.name' "$plugin_json")
    pv=$(jq -r '.version' "$plugin_json")
    mv=$(jq -r --arg n "$name" '.plugins[] | select(.name == $n) | .version // empty' "$MARKETPLACE" 2>/dev/null || echo "")

    if [[ -z "$mv" ]]; then
      continue  # Plugin not in marketplace (dev-only, archived, etc.)
    fi

    if [[ "$pv" != "$mv" ]]; then
      echo "MISMATCH: $name — plugin.json=$pv, marketplace.json=$mv"
      errors=$((errors + 1))
    else
      echo "OK: $name v$pv"
    fi
  done

  if [[ $errors -gt 0 ]]; then
    echo ""
    echo "$errors version mismatch(es) found."
    echo "Run: ./scripts/bump-version.sh <plugin-name> <version>"
    exit 1
  else
    echo ""
    echo "All versions in sync."
    exit 0
  fi
fi

# ── Bump mode ──
[[ $# -ge 2 ]] || die "Usage: $0 <plugin-name> <new-version>"

PLUGIN_NAME="$1"
NEW_VERSION="$2"

# Validate semver-ish format
[[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Version must be semver (e.g., 0.2.0), got: $NEW_VERSION"

# Find plugin.json
PLUGIN_JSON=""
for candidate in "$PLUGIN_NAME/plugin.json" "$PLUGIN_NAME/.claude-plugin/plugin.json"; do
  [[ -f "$candidate" ]] && PLUGIN_JSON="$candidate" && break
done
[[ -n "$PLUGIN_JSON" ]] || die "No plugin.json found for '$PLUGIN_NAME'"

# Read current versions
OLD_PV=$(jq -r '.version' "$PLUGIN_JSON")
OLD_MV=$(jq -r --arg n "$PLUGIN_NAME" '.plugins[] | select(.name == $n) | .version' "$MARKETPLACE" 2>/dev/null || echo "NOT_FOUND")

echo "Plugin:      $PLUGIN_NAME"
echo "plugin.json: $OLD_PV → $NEW_VERSION"
[[ "$OLD_MV" != "NOT_FOUND" ]] && echo "marketplace:  $OLD_MV → $NEW_VERSION"

# Update plugin.json
tmp=$(mktemp)
jq --arg v "$NEW_VERSION" '.version = $v' "$PLUGIN_JSON" > "$tmp" && mv "$tmp" "$PLUGIN_JSON"

# Update marketplace.json
if [[ "$OLD_MV" != "NOT_FOUND" ]]; then
  tmp=$(mktemp)
  jq --arg n "$PLUGIN_NAME" --arg v "$NEW_VERSION" \
    '(.plugins[] | select(.name == $n)).version = $v' "$MARKETPLACE" > "$tmp" && mv "$tmp" "$MARKETPLACE"
fi

echo ""
echo "Done. Both files updated to v$NEW_VERSION."
echo "Commit with: git add $PLUGIN_JSON $MARKETPLACE && git commit -m 'chore(release): bump $PLUGIN_NAME v$NEW_VERSION'"
