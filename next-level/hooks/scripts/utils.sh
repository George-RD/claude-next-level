#!/usr/bin/env bash
# Shared utilities for next-level hooks

NEXT_LEVEL_STATE="${NEXT_LEVEL_STATE:-${HOME}/.next-level}"

ensure_state_dir() {
  local session_id="$1"
  local dir="${NEXT_LEVEL_STATE}/sessions/${session_id}"
  mkdir -p "$dir"
  echo "$dir"
}

ensure_specs_dir() {
  mkdir -p "${NEXT_LEVEL_STATE}/specs"
  echo "${NEXT_LEVEL_STATE}/specs"
}

# Read JSON from stdin
read_hook_input() {
  cat
}

# Get field from JSON string using jq
json_field() {
  local json="$1" field="$2"
  echo "$json" | jq -r ".$field // empty"
}

# Check if file is an implementation file (not test, not config, not docs)
is_impl_file() {
  local filepath="$1"
  local basename
  basename=$(basename "$filepath")
  local ext="${basename##*.}"

  # Skip non-code files
  case "$ext" in
    md|json|yaml|yml|toml|ini|cfg|lock|txt|csv|svg|png|jpg|gif) return 1 ;;
  esac

  # Skip test files
  case "$basename" in
    test_*|*_test.*|*.test.*|*.spec.*|*_test.go) return 1 ;;
  esac

  # Skip common non-impl paths
  case "$filepath" in
    */migrations/*|*/fixtures/*|*/__mocks__/*|*/node_modules/*|*/.git/*) return 1 ;;
  esac

  return 0
}

# Find corresponding test file for an implementation file
find_test_file() {
  local filepath="$1"
  local dir basename name ext
  dir=$(dirname "$filepath")
  basename=$(basename "$filepath")
  name="${basename%.*}"
  ext="${basename##*.}"

  local candidates=()

  case "$ext" in
    py)
      candidates=(
        "${dir}/test_${name}.py"
        "${dir}/${name}_test.py"
        "${dir}/tests/test_${name}.py"
        "${dir}/../tests/test_${name}.py"
      )
      ;;
    ts|tsx)
      candidates=(
        "${dir}/${name}.test.ts"
        "${dir}/${name}.spec.ts"
        "${dir}/${name}.test.tsx"
        "${dir}/${name}.spec.tsx"
        "${dir}/__tests__/${name}.test.ts"
        "${dir}/__tests__/${name}.spec.ts"
      )
      ;;
    js|jsx)
      candidates=(
        "${dir}/${name}.test.js"
        "${dir}/${name}.spec.js"
        "${dir}/${name}.test.jsx"
        "${dir}/${name}.spec.jsx"
        "${dir}/__tests__/${name}.test.js"
        "${dir}/__tests__/${name}.spec.js"
      )
      ;;
    go)
      candidates=(
        "${dir}/${name}_test.go"
      )
      ;;
  esac

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

# Check transcript for test runner evidence
# Detects language-specific test runner output patterns
# Optional second arg: byte offset to start scanning from
has_test_evidence() {
  local transcript_path="$1"
  local offset="${2:-0}"
  [[ -f "$transcript_path" ]] || return 1

  local test_pattern='(PASS|FAIL|passed|failed|test[s]? ran|pytest|jest|vitest|mocha|go test|cargo test|swift test|test session starts|Test Suites:|test result:|running [0-9]+ test|Executed [0-9]+ test|--- PASS|--- FAIL|ok[[:space:]]+[a-z]|Tests:|✓|✗)'

  if [[ "$offset" -gt 0 ]]; then
    tail -c +$((offset + 1)) "$transcript_path" 2>/dev/null | grep -qE "$test_pattern"
  else
    grep -qE "$test_pattern" "$transcript_path"
  fi
}

# Check if a transcript contains edits to implementation files.
# Returns 0 (true) if impl files were edited, 1 (false) otherwise.
# Usage: transcript_has_impl_edits <transcript_path>
transcript_has_impl_edits() {
  local transcript="$1"
  [[ -n "$transcript" && -f "$transcript" ]] || return 1

  local filepath
  while IFS= read -r filepath; do
    [[ -z "$filepath" ]] && continue
    if is_impl_file "$filepath"; then
      return 0
    fi
  done < <(
    {
      jq -r '.. | objects | .file_path? // empty' "$transcript" 2>/dev/null \
        || grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' "$transcript" 2>/dev/null \
           | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//' \
        || true
    } | sort -u
  )
  return 1
}
