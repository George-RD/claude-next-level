#!/usr/bin/env bash
# Configuration reader for next-level hooks
# Reads ~/.next-level/config.json using jq
set -euo pipefail

NEXT_LEVEL_CONFIG="${NEXT_LEVEL_CONFIG:-${HOME}/.next-level/config.json}"

# Check if config exists
config_exists() {
  [[ -f "$NEXT_LEVEL_CONFIG" ]]
}

# Read a top-level field from config
config_get() {
  local field="$1"
  if ! config_exists; then
    return 1
  fi
  jq -r ".$field // empty" "$NEXT_LEVEL_CONFIG"
}

# Check if setup is complete
config_setup_complete() {
  local val
  val=$(config_get "setup_complete" 2>/dev/null) || return 1
  [[ "$val" == "true" ]]
}

# Get detected languages (one per line)
config_languages() {
  if ! config_exists; then
    return 1
  fi
  jq -r '.languages_detected // [] | .[]' "$NEXT_LEVEL_CONFIG"
}

# Check if a feature is enabled
config_feature_enabled() {
  local feature="$1"
  if ! config_exists; then
    return 1
  fi
  local val
  val=$(jq -r --arg f "$feature" '.features_enabled[$f] // false' "$NEXT_LEVEL_CONFIG")
  [[ "$val" == "true" ]]
}

# Check if a plugin is available
config_plugin_available() {
  local plugin="$1"
  if ! config_exists; then
    return 1
  fi
  local val
  val=$(jq -r --arg p "$plugin" '.plugins_available[$p] // false' "$NEXT_LEVEL_CONFIG")
  [[ "$val" == "true" ]]
}

# Get config last_updated timestamp
config_last_updated() {
  config_get "last_updated"
}

# Write a full config file (atomic write with restrictive permissions)
config_write() {
  local json="$1"
  local dir
  dir=$(dirname "$NEXT_LEVEL_CONFIG")
  mkdir -p "$dir"
  # Validate JSON before writing
  if ! echo "$json" | jq empty 2>/dev/null; then
    echo "config_write: invalid JSON" >&2
    return 1
  fi
  local tmp
  tmp=$(mktemp "$dir/.config.XXXXXX")
  trap 'rm -f "$tmp"' EXIT INT TERM
  echo "$json" > "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$NEXT_LEVEL_CONFIG"
  trap - EXIT INT TERM
}
