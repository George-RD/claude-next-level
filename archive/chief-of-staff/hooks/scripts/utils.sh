#!/usr/bin/env bash
# Shared utilities for chief-of-staff hooks
#
# Provides: state directory management, JSON helpers (via jq),
# atomic file writes, and plugin detection.
#
# Sourced by init.sh and checkpoint.sh — not executed directly.

# ── State directory root ──────────────────────────────────────────────
COS_HOME="${CHIEF_OF_STAFF_HOME:-${HOME}/.chief-of-staff}"

# ── Directory helpers ─────────────────────────────────────────────────

# Ensure the session directory (and agents/ subdirectory) exists.
# Usage: ensure_session_dir <session_id>
# Prints the session directory path to stdout.
ensure_session_dir() {
  local session_id="$1"
  local dir="${COS_HOME}/sessions/${session_id}"
  mkdir -p "$dir/agents"
  echo "$dir"
}

# ── JSON helpers (require jq) ─────────────────────────────────────────

# Read JSON from stdin (hook input).
read_hook_input() {
  cat
}

# Extract a field from a JSON string.
# Usage: json_field "$json_string" "field_name"
# Returns empty string (not "null") if the field is missing.
json_field() {
  local json="$1" field="$2"
  echo "$json" | jq -r ".$field // empty"
}

# ── Atomic file writes ───────────────────────────────────────────────

# Atomically write content to a file (write to temp, then mv).
# Usage: write_json <filepath> <content>
write_json() {
  local filepath="$1"
  local content="$2"
  local tmpfile="${filepath}.tmp.$$"
  echo "$content" > "$tmpfile"
  mv "$tmpfile" "$filepath"
}

# ── State file helpers ────────────────────────────────────────────────

# Read state.json for a session directory. Returns "{}" if missing.
# Usage: read_state <session_dir>
read_state() {
  local session_dir="$1"
  local state_file="${session_dir}/state.json"
  if [[ -f "$state_file" ]]; then
    cat "$state_file"
  else
    echo "{}"
  fi
}

# Update state.json by applying a jq filter.
# Usage: update_state <session_dir> <jq_filter>
update_state() {
  local session_dir="$1"
  local jq_filter="$2"
  local state_file="${session_dir}/state.json"
  local current updated
  current=$(read_state "$session_dir")
  updated=$(echo "$current" | jq "$jq_filter")
  write_json "$state_file" "$updated"
}

# ── Plugin detection ──────────────────────────────────────────────────

# Check if a Claude Code plugin is installed by looking for its directory
# in common plugin locations.
# Usage: claude_has_plugin <plugin_name>
# Returns 0 if found, 1 if not.
claude_has_plugin() {
  local plugin_name="$1"
  local plugin_root="${CLAUDE_PLUGIN_ROOT:-}"

  # If we know our own plugin root, check siblings
  if [[ -n "$plugin_root" ]]; then
    local parent
    parent=$(dirname "$plugin_root")
    [[ -d "${parent}/${plugin_name}" ]] && return 0
  fi

  # Check .claude/plugins in project root
  local project_root
  project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  [[ -d "${project_root}/.claude/plugins/${plugin_name}" ]] && return 0

  return 1
}
