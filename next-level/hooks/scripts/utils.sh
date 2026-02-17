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
has_test_evidence() {
  local transcript_path="$1"
  if [[ ! -f "$transcript_path" ]]; then
    return 1
  fi
  # Language-specific patterns:
  # Python: pytest, unittest, "passed", "failed", "ERROR", "test session starts"
  # JS/TS: jest, vitest, mocha, "Tests:", "Test Suites:", "PASS", "FAIL"
  # Go: "go test", "ok ", "FAIL", "--- PASS", "--- FAIL"
  # Rust: "cargo test", "test result:", "running N test"
  # Swift: "swift test", "Test Suite", "Executed N test"
  grep -qE '(PASS|FAIL|passed|failed|test[s]? ran|pytest|jest|vitest|mocha|go test|cargo test|swift test|test session starts|Test Suites:|test result:|running [0-9]+ test|Executed [0-9]+ test|--- PASS|--- FAIL|ok\s+[a-z]|Tests:|✓|✗)' "$transcript_path"
}

# Detect test runner command for a language
detect_test_command() {
  local ext="$1"
  case "$ext" in
    py)    echo "pytest" ;;
    ts|tsx|js|jsx)
      if [[ -f "package.json" ]]; then
        # Check for vitest or jest in package.json
        if grep -q '"vitest"' package.json 2>/dev/null; then
          echo "npx vitest run"
        elif grep -q '"jest"' package.json 2>/dev/null; then
          echo "npx jest"
        else
          echo "npx vitest run"
        fi
      else
        echo "npx vitest run"
      fi
      ;;
    go)    echo "go test ./..." ;;
    rs)    echo "cargo test" ;;
    swift) echo "swift test" ;;
    *)     echo "" ;;
  esac
}
