#!/bin/bash
# Ralph Wiggum Toolkit v2 - Recipe-aware init
# Creates the file structure needed for spec-driven development loops.
# v2: auto-detects language, tools, and VCS; generates state.json with gate config.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RECIPES_DIR="$PLUGIN_ROOT/recipes"

# Track what was created vs skipped
CREATED=()
SKIPPED=()

create_if_missing() {
  local target="$1"
  local source="$2"
  local description="$3"

  if [[ -f "$target" ]]; then
    SKIPPED+=("$description ($target already exists)")
  else
    cp "$source" "$target"
    CREATED+=("$description → $target")
  fi
}

create_dir_if_missing() {
  local target="$1"
  local description="$2"

  if [[ -d "$target" ]]; then
    SKIPPED+=("$description ($target already exists)")
  else
    mkdir -p "$target"
    CREATED+=("$description → $target")
  fi
}

# Escape sed replacement metacharacters for delimiter '|'
escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'
}

# Escape a string for safe embedding in JSON values inside a heredoc
escape_json_value() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g' -e 's/`/\\`/g'
}

# ============================================================
# LANGUAGE DETECTION
# ============================================================
detect_language() {
  # Check for TypeScript/JavaScript (package.json)
  if [[ -f "package.json" ]]; then
    if jq -e '.devDependencies.typescript // .dependencies.typescript' package.json &>/dev/null || [[ -f "tsconfig.json" ]]; then
      echo "typescript"
    else
      echo "javascript"
    fi
    return
  fi

  # Check for Rust
  if [[ -f "Cargo.toml" ]]; then
    echo "rust"
    return
  fi

  # Check for Go
  if [[ -f "go.mod" ]]; then
    echo "go"
    return
  fi

  # Check for Python
  if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]]; then
    echo "python"
    return
  fi

  # Check for Swift
  if [[ -f "Package.swift" ]] || compgen -G "*.swift" >/dev/null 2>&1; then
    echo "swift"
    return
  fi

  echo "unknown"
}

# ============================================================
# TOOL DETECTION
# ============================================================

# Helper: check if a key exists in package.json devDependencies
_pkg_has_dev_dep() {
  [[ -f "package.json" ]] && jq -e --arg dep "$1" '.devDependencies[$dep] // empty' package.json &>/dev/null
}

# Detect tools for the given language. Sets global variables:
#   DETECTED_LINTER, DETECTED_FORMATTER, DETECTED_TEST_RUNNER, DETECTED_TYPE_CHECKER
detect_tools() {
  local lang="$1"
  DETECTED_LINTER=""
  DETECTED_FORMATTER=""
  DETECTED_TEST_RUNNER=""
  DETECTED_TYPE_CHECKER=""

  case "$lang" in
    typescript|javascript)
      # Linter detection
      if _pkg_has_dev_dep "@biomejs/biome" || [[ -f "biome.json" ]] || [[ -f "biome.jsonc" ]]; then
        DETECTED_LINTER="biome"
      elif _pkg_has_dev_dep "eslint" || compgen -G ".eslintrc*" >/dev/null 2>&1 || [[ -f "eslint.config.js" ]] || [[ -f "eslint.config.mjs" ]]; then
        DETECTED_LINTER="eslint"
      fi

      # Test runner detection
      if _pkg_has_dev_dep "vitest" || compgen -G "vitest.config.*" >/dev/null 2>&1; then
        DETECTED_TEST_RUNNER="vitest"
      elif _pkg_has_dev_dep "jest" || compgen -G "jest.config.*" >/dev/null 2>&1; then
        DETECTED_TEST_RUNNER="jest"
      elif _pkg_has_dev_dep "mocha"; then
        DETECTED_TEST_RUNNER="mocha"
      fi

      # Type checker
      if [[ "$lang" == "typescript" ]]; then
        DETECTED_TYPE_CHECKER="tsc"
      fi
      ;;

    rust)
      DETECTED_LINTER="clippy"
      DETECTED_TEST_RUNNER="cargo-test"
      ;;

    go)
      DETECTED_LINTER="go-vet"
      DETECTED_TEST_RUNNER="go-test"
      # Check for staticcheck
      if command -v staticcheck &>/dev/null; then
        DETECTED_FORMATTER="staticcheck"
      fi
      ;;

    python)
      # Linter detection
      if [[ -f "ruff.toml" ]] || [[ -f ".ruff.toml" ]]; then
        DETECTED_LINTER="ruff"
      elif command -v python3 &>/dev/null && python3 -c "
import sys
try:
    import toml; cfg = toml.load('pyproject.toml')
    sys.exit(0 if 'ruff' in cfg.get('tool', {}) else 1)
except: sys.exit(1)
" 2>/dev/null; then
        DETECTED_LINTER="ruff"
      elif [[ -f ".flake8" ]]; then
        DETECTED_LINTER="flake8"
      fi

      # Type checker
      if [[ -f "mypy.ini" ]] || [[ -f ".mypy.ini" ]]; then
        DETECTED_TYPE_CHECKER="mypy"
      elif command -v python3 &>/dev/null && python3 -c "
import sys
try:
    import toml; cfg = toml.load('pyproject.toml')
    sys.exit(0 if 'mypy' in cfg.get('tool', {}) else 1)
except: sys.exit(1)
" 2>/dev/null; then
        DETECTED_TYPE_CHECKER="mypy"
      fi

      # Test runner
      if [[ -f "pytest.ini" ]] || [[ -f "conftest.py" ]]; then
        DETECTED_TEST_RUNNER="pytest"
      elif command -v python3 &>/dev/null && python3 -c "
import sys
try:
    import toml; cfg = toml.load('pyproject.toml')
    sys.exit(0 if 'pytest' in cfg.get('tool', {}) else 1)
except: sys.exit(1)
" 2>/dev/null; then
        DETECTED_TEST_RUNNER="pytest"
      fi
      ;;
  esac
}

# ============================================================
# VCS DETECTION
# ============================================================
detect_vcs() {
  if jj root &>/dev/null; then
    echo "jj"
  elif git rev-parse --git-dir &>/dev/null; then
    echo "git"
  else
    echo "git"  # default
  fi
}

# ============================================================
# GATE CONFIG GENERATION
# ============================================================

# Helper: prefix with npx if tool is a devDependency
_npx_prefix() {
  local tool="$1"
  if _pkg_has_dev_dep "$tool"; then
    echo "npx $tool"
  else
    echo "$tool"
  fi
}

# Generate gate config JSON for state.json
# Sets TIER1_CMDS, TIER2_CMDS, TIER3_CMDS as arrays
generate_gate_config() {
  local lang="$1"
  TIER1_CMDS=()
  TIER2_CMDS=()
  TIER3_CMDS=()

  case "$lang" in
    typescript)
      local tsc_cmd
      tsc_cmd="$(_npx_prefix tsc) --noEmit"
      local tsc_strict_cmd
      tsc_strict_cmd="$(_npx_prefix tsc) --noEmit --strict"

      if [[ "$DETECTED_LINTER" == "biome" ]]; then
        local biome_cmd
        biome_cmd="$(_npx_prefix biome)"
        TIER1_CMDS=("$tsc_cmd" "$biome_cmd check {changed_files}")
        TIER2_CMDS=("$tsc_cmd" "$biome_cmd check ." "$(_build_test_cmd_related)")
        TIER3_CMDS=("$tsc_strict_cmd" "$biome_cmd check ." "$(_build_test_cmd_full)")
      elif [[ "$DETECTED_LINTER" == "eslint" ]]; then
        local eslint_cmd
        eslint_cmd="$(_npx_prefix eslint)"
        TIER1_CMDS=("$tsc_cmd" "$eslint_cmd --cache {changed_files}")
        TIER2_CMDS=("$tsc_cmd" "$eslint_cmd ." "$(_build_test_cmd_related)")
        TIER3_CMDS=("$tsc_strict_cmd" "$eslint_cmd --max-warnings 0 ." "$(_build_test_cmd_full)")
      else
        # No linter detected
        TIER1_CMDS=("$tsc_cmd")
        TIER2_CMDS=("$tsc_cmd" "$(_build_test_cmd_related)")
        TIER3_CMDS=("$tsc_strict_cmd" "$(_build_test_cmd_full)")
      fi
      ;;

    javascript)
      if [[ "$DETECTED_LINTER" == "biome" ]]; then
        local biome_cmd
        biome_cmd="$(_npx_prefix biome)"
        TIER1_CMDS=("$biome_cmd check {changed_files}")
        TIER2_CMDS=("$biome_cmd check ." "$(_build_test_cmd_related)")
        TIER3_CMDS=("$biome_cmd check ." "$(_build_test_cmd_full)")
      elif [[ "$DETECTED_LINTER" == "eslint" ]]; then
        local eslint_cmd
        eslint_cmd="$(_npx_prefix eslint)"
        TIER1_CMDS=("$eslint_cmd --cache {changed_files}")
        TIER2_CMDS=("$eslint_cmd ." "$(_build_test_cmd_related)")
        TIER3_CMDS=("$eslint_cmd --max-warnings 0 ." "$(_build_test_cmd_full)")
      else
        TIER1_CMDS=()
        TIER2_CMDS=("$(_build_test_cmd_related)")
        TIER3_CMDS=("$(_build_test_cmd_full)")
      fi
      ;;

    rust)
      TIER1_CMDS=("cargo check")
      TIER2_CMDS=("cargo clippy" "cargo test")
      TIER3_CMDS=("cargo clippy -- -D warnings" "cargo test")
      ;;

    go)
      TIER1_CMDS=("go vet ./...")
      if [[ "$DETECTED_FORMATTER" == "staticcheck" ]]; then
        TIER2_CMDS=("go vet ./..." "staticcheck ./..." "go test ./...")
        TIER3_CMDS=("go vet ./..." "staticcheck ./..." "go test ./..." "go build ./...")
      else
        TIER2_CMDS=("go vet ./..." "go test ./...")
        TIER3_CMDS=("go vet ./..." "go test ./..." "go build ./...")
      fi
      ;;

    python)
      local linter_cmd=""
      local linter_strict_cmd=""
      local linter_select_cmd=""
      if [[ "$DETECTED_LINTER" == "ruff" ]]; then
        linter_select_cmd="ruff check --select=E {changed_files}"
        linter_cmd="ruff check"
        linter_strict_cmd="ruff check --strict"
      elif [[ "$DETECTED_LINTER" == "flake8" ]]; then
        linter_select_cmd="flake8 --select=E {changed_files}"
        linter_cmd="flake8"
        linter_strict_cmd="flake8 --max-line-length=120"
      fi

      local type_cmd=""
      local type_strict_cmd=""
      if [[ "$DETECTED_TYPE_CHECKER" == "mypy" ]]; then
        type_cmd="mypy"
        type_strict_cmd="mypy --strict"
      fi

      local test_collect_cmd=""
      local test_full_cmd=""
      if [[ "$DETECTED_TEST_RUNNER" == "pytest" ]]; then
        test_collect_cmd="pytest --co -q"
        test_full_cmd="pytest"
      fi

      # Build tiers
      if [[ -n "$linter_select_cmd" ]]; then
        TIER1_CMDS=("$linter_select_cmd")
      fi

      if [[ -n "$linter_cmd" ]]; then
        TIER2_CMDS+=("$linter_cmd")
      fi
      if [[ -n "$type_cmd" ]]; then
        TIER2_CMDS+=("$type_cmd")
      fi
      if [[ -n "$test_collect_cmd" ]]; then
        TIER2_CMDS+=("$test_collect_cmd")
      fi

      if [[ -n "$linter_strict_cmd" ]]; then
        TIER3_CMDS+=("$linter_strict_cmd")
      fi
      if [[ -n "$type_strict_cmd" ]]; then
        TIER3_CMDS+=("$type_strict_cmd")
      fi
      if [[ -n "$test_full_cmd" ]]; then
        TIER3_CMDS+=("$test_full_cmd")
      fi
      ;;

    *)
      # Unknown language - empty gate config, user must configure manually
      ;;
  esac
}

# Helper: build test command for --related mode
_build_test_cmd_related() {
  case "$DETECTED_TEST_RUNNER" in
    vitest)  echo "$(_npx_prefix vitest) --related {changed_files}" ;;
    jest)    echo "$(_npx_prefix jest) --findRelatedTests {changed_files}" ;;
    mocha)   echo "$(_npx_prefix mocha)" ;;
    *)       echo "" ;;
  esac
}

# Helper: build full test command
_build_test_cmd_full() {
  case "$DETECTED_TEST_RUNNER" in
    vitest)  echo "$(_npx_prefix vitest)" ;;
    jest)    echo "$(_npx_prefix jest)" ;;
    mocha)   echo "$(_npx_prefix mocha)" ;;
    *)       echo "" ;;
  esac
}

# ============================================================
# JSON ARRAY BUILDER
# ============================================================
# Converts a bash array into a JSON array string
_json_array() {
  local arr=("$@")
  local result="["
  local first=true
  for item in "${arr[@]}"; do
    # Skip empty strings
    [[ -z "$item" ]] && continue
    if [[ "$first" == "true" ]]; then
      first=false
    else
      result+=", "
    fi
    local escaped
    escaped="$(escape_json_value "$item")"
    result+="\"$escaped\""
  done
  result+="]"
  echo "$result"
}

# ============================================================
# SHARED INIT (common to all recipes)
# ============================================================
init_common() {
  create_dir_if_missing "specs" "Specs directory"
  create_dir_if_missing "ralph" "Ralph state directory"

  # Create empty IMPLEMENTATION_PLAN.md
  if [[ ! -f "IMPLEMENTATION_PLAN.md" ]]; then
    echo "<!-- Generated by Ralph Wiggum Toolkit - will be populated during planning phase -->" > IMPLEMENTATION_PLAN.md
    CREATED+=("IMPLEMENTATION_PLAN.md")
  else
    SKIPPED+=("IMPLEMENTATION_PLAN.md (already exists)")
  fi

  # Copy loop.sh from core
  if [[ ! -f "loop.sh" ]]; then
    cp "$PLUGIN_ROOT/core/scripts/loop.sh" "loop.sh"
    chmod +x "loop.sh"
    CREATED+=("loop.sh (executable)")
  else
    SKIPPED+=("loop.sh (already exists)")
  fi
}

# ============================================================
# REPORT RESULTS
# ============================================================
report_results() {
  echo ""
  if [[ ${#CREATED[@]} -gt 0 ]]; then
    echo "Created:"
    for item in "${CREATED[@]}"; do
      echo "  + $item"
    done
  fi

  if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    echo ""
    echo "Skipped (already exist):"
    for item in "${SKIPPED[@]}"; do
      echo "  - $item"
    done
  fi
}

# ============================================================
# GENERATE STATE.JSON (shared between greenfield and port)
# ============================================================
# Usage: generate_state_json <recipe_fields_json>
#   recipe_fields_json: a JSON object with recipe-specific top-level fields
#   (e.g., {"recipe":"greenfield","language":"typescript","goal":"...",...})
#   These fields are merged into the base state template.
generate_state_json() {
  local recipe_fields="$1"

  if [[ -f "ralph/state.json" ]]; then
    SKIPPED+=("ralph/state.json (already exists)")
    return 0
  fi

  local tier1_json tier2_json tier3_json
  tier1_json="$(_json_array "${TIER1_CMDS[@]+"${TIER1_CMDS[@]}"}")"
  tier2_json="$(_json_array "${TIER2_CMDS[@]+"${TIER2_CMDS[@]}"}")"
  tier3_json="$(_json_array "${TIER3_CMDS[@]+"${TIER3_CMDS[@]}"}")"

  cat > ralph/state.json <<STATE_EOF
{
  "version": "2.0.0",
  "model": "opus",
  "created": "$(date +%Y-%m-%d)",
  "currentTaskId": null,
  "iteration": 0,
  "maxIterations": 100,
  "taskIteration": 1,
  "maxTaskIterations": 5,
  "maxFixTasksPerOriginal": 3,
  "phase": "spec",
  "awaitingApproval": false,
  "tasks": [],
  "gateConfig": {
    "tier1": {
      "commands": $tier1_json,
      "timeout": 30
    },
    "tier2": {
      "commands": $tier2_json,
      "timeout": 120
    },
    "tier3": {
      "commands": $tier3_json,
      "timeout": 300
    }
  },
  "allowlist": [],
  "gateHistory": [],
  "cycleThreshold": 3
}
STATE_EOF

  # Merge recipe-specific fields into state.json using jq
  local tmp
  tmp=$(mktemp)
  jq --argjson extra "$recipe_fields" '. + $extra' ralph/state.json > "$tmp" && mv "$tmp" ralph/state.json

  CREATED+=("ralph/state.json")
}

# ============================================================
# GREENFIELD INIT (v2)
# ============================================================
init_greenfield() {
  # Parse greenfield-specific args
  local SRC_DIR="src"
  local GOAL=""

  set -- "${REMAINING_ARGS[@]}"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --src-dir)
        if [[ -z "${2:-}" ]] || [[ "${2:-}" == -* ]]; then
          echo "Error: --src-dir requires a path argument" >&2
          exit 1
        fi
        SRC_DIR="$2"
        shift 2
        ;;
      --goal)
        if [[ -z "${2:-}" ]] || [[ "${2:-}" == -* ]]; then
          echo "Error: --goal requires a text argument" >&2
          exit 1
        fi
        GOAL="$2"
        shift 2
        ;;
      -h|--help)
        cat << 'EOF'
Ralph Wiggum Toolkit v2 - Greenfield Init

USAGE:
  /ralph init [--recipe greenfield] [OPTIONS]

OPTIONS:
  --src-dir <path>   Source code directory (default: src)
  --goal <text>      Project goal for PROMPT_plan.md placeholder
  -h, --help         Show this help

CREATES:
  ralph/state.json        Project state with auto-detected gate config
  specs/                  Requirement specs directory
  AGENTS.md               Operational guide (build/test commands)
  IMPLEMENTATION_PLAN.md  Task tracking (initially empty)
  PROMPT_plan.md          Planning mode prompt
  PROMPT_build.md         Build mode prompt
  loop.sh                 External autonomous loop runner

AUTO-DETECTS:
  - Language (from project files)
  - Tools (linters, test runners, formatters)
  - VCS (git or jj)
  - Gate commands (tier 1/2/3 quality gates)
EOF
        exit 0
        ;;
      *)
        echo "Warning: Unknown argument '$1' ignored" >&2
        shift
        ;;
    esac
  done

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Ralph Wiggum Toolkit v2: Initializing (greenfield)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Auto-detect configuration
  echo ""
  echo "Detecting project configuration..."

  local DETECTED_LANG
  DETECTED_LANG="$(detect_language)"
  detect_tools "$DETECTED_LANG"
  local VCS
  VCS="$(detect_vcs)"
  generate_gate_config "$DETECTED_LANG"

  # Print detected configuration
  echo ""
  echo "Detected configuration:"
  echo "  Language: $DETECTED_LANG"
  echo "  VCS: $VCS"
  if [[ ${#TIER1_CMDS[@]} -gt 0 ]]; then
    local tier1_display
    tier1_display="$(IFS=", "; echo "${TIER1_CMDS[*]}")"
    echo "  Tier 1: $tier1_display"
  else
    echo "  Tier 1: (none detected)"
  fi
  if [[ ${#TIER2_CMDS[@]} -gt 0 ]]; then
    local tier2_display
    tier2_display="$(IFS=", "; echo "${TIER2_CMDS[*]}")"
    echo "  Tier 2: $tier2_display"
  else
    echo "  Tier 2: (none detected)"
  fi
  if [[ ${#TIER3_CMDS[@]} -gt 0 ]]; then
    local tier3_display
    tier3_display="$(IFS=", "; echo "${TIER3_CMDS[*]}")"
    echo "  Tier 3: $tier3_display"
  else
    echo "  Tier 3: (none detected)"
  fi

  # Shared setup
  init_common

  # Create files from templates
  create_if_missing "AGENTS.md" "$TEMPLATES/AGENTS.md" "AGENTS.md"
  create_if_missing "PROMPT_plan.md" "$TEMPLATES/PROMPT_plan.md" "PROMPT_plan.md"
  create_if_missing "PROMPT_build.md" "$TEMPLATES/PROMPT_build.md" "PROMPT_build.md"

  # Generate state.json (v2 - replaces manifest.json)
  local SAFE_GOAL
  SAFE_GOAL="$(escape_json_value "${GOAL:-}")"
  local SAFE_SRC_DIR
  SAFE_SRC_DIR="$(escape_json_value "$SRC_DIR")"

  generate_state_json "$(jq -n \
    --arg recipe "greenfield" \
    --arg vcs "$VCS" \
    --arg lang "$DETECTED_LANG" \
    --arg goal "$SAFE_GOAL" \
    --arg src_dir "$SAFE_SRC_DIR" \
    '{recipe: $recipe, vcs: $vcs, language: $lang, goal: $goal, src_dir: $src_dir}'
  )"

  # If source dir is not "src", update prompt templates to use the right path
  if [[ "$SRC_DIR" != "src" ]]; then
    ESCAPED_SRC_DIR="$(escape_sed_replacement "$SRC_DIR")"
    for f in PROMPT_plan.md PROMPT_build.md; do
      if [[ -f "$f" ]]; then
        sed -i '' "s|src/lib/\*|${ESCAPED_SRC_DIR}/lib/*|g; s|src/\*|${ESCAPED_SRC_DIR}/*|g" "$f" 2>/dev/null || \
        sed -i "s|src/lib/\*|${ESCAPED_SRC_DIR}/lib/*|g; s|src/\*|${ESCAPED_SRC_DIR}/*|g" "$f"
      fi
    done
    echo ""
    echo "Updated prompts to use '$SRC_DIR' as source directory"
  fi

  # If goal provided, substitute in PROMPT_plan.md
  if [[ -n "$GOAL" ]] && [[ -f "PROMPT_plan.md" ]]; then
    ESCAPED_GOAL="$(escape_sed_replacement "$GOAL")"
    sed -i '' "s|\[project-specific goal\]|${ESCAPED_GOAL}|g" "PROMPT_plan.md" 2>/dev/null || \
    sed -i "s|\[project-specific goal\]|${ESCAPED_GOAL}|g" "PROMPT_plan.md"
    echo "Set project goal in PROMPT_plan.md"
  fi

  # Report
  report_results

  echo ""
  echo "Override: edit ralph/state.json directly if defaults are wrong."
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Next steps:"
  echo "  1. Verify detected gate config in ralph/state.json"
  echo "  2. Write specs: /ralph spec"
  echo "  3. Run planning: /ralph plan"
  echo "  4. Run building: /ralph build"
  echo ""
  echo "For autonomous (external) loop:"
  echo "  ./loop.sh plan     # Planning mode"
  echo "  ./loop.sh           # Build mode"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================
# PORT INIT
# ============================================================
init_port() {
  # Parse port-specific args (positional: source-lang target-lang, or --src/--tgt flags)
  local SOURCE_LANG=""
  local TARGET_LANG=""
  local positionals=()

  set -- "${REMAINING_ARGS[@]}"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --src)
        if [[ -z "${2:-}" ]] || [[ "${2:-}" == -* ]]; then
          echo "Error: --src requires a language name" >&2
          exit 1
        fi
        SOURCE_LANG="$2"; shift 2
        ;;
      --tgt)
        if [[ -z "${2:-}" ]] || [[ "${2:-}" == -* ]]; then
          echo "Error: --tgt requires a language name" >&2
          exit 1
        fi
        TARGET_LANG="$2"; shift 2
        ;;
      -h|--help)
        cat << 'EOF'
Ralph Wiggum Toolkit v2 - Port Init

USAGE:
  /ralph init --recipe port <source-lang> <target-lang>
  /ralph init --recipe port --src <source-lang> --tgt <target-lang>

EXAMPLES:
  /ralph init --recipe port dart typescript
  /ralph init --recipe port --src rust --tgt go

CREATES:
  ralph/state.json          Project state with gate config (recipe: port)
  specs/tests/              Test spec extraction output directory
  specs/src/                Source spec extraction output directory
  AGENTS.md                 Operational guide with language substitutions
  IMPLEMENTATION_PLAN.md    Task tracking (initially empty)
  PROMPT_extract_tests.md   Test extraction loop prompt
  PROMPT_extract_src.md     Source extraction loop prompt
  PROMPT_port.md            Port plan+build loop prompt
  ralph/SEMANTIC_MISMATCHES.md  Known language divergences
  ralph/PORT_STATE.md       Human-readable manifest view
  loop.sh                   External autonomous loop runner
EOF
        exit 0
        ;;
      -*)
        echo "Warning: Unknown flag '$1' ignored" >&2
        shift
        ;;
      *)
        positionals+=("$1")
        shift
        ;;
    esac
  done

  # Assign positional args
  if [[ -z "$SOURCE_LANG" ]] && [[ ${#positionals[@]} -ge 1 ]]; then
    SOURCE_LANG="${positionals[0]}"
  fi
  if [[ -z "$TARGET_LANG" ]] && [[ ${#positionals[@]} -ge 2 ]]; then
    TARGET_LANG="${positionals[1]}"
  fi

  # Normalize to lowercase
  SOURCE_LANG=$(echo "$SOURCE_LANG" | tr '[:upper:]' '[:lower:]')
  TARGET_LANG=$(echo "$TARGET_LANG" | tr '[:upper:]' '[:lower:]')

  if [[ -z "$SOURCE_LANG" ]] || [[ -z "$TARGET_LANG" ]]; then
    echo "Error: Port recipe requires source and target languages." >&2
    echo "Usage: /ralph init --recipe port <source-lang> <target-lang>" >&2
    exit 1
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Ralph Wiggum Toolkit v2: Initializing (port)"
  echo "  Source: $SOURCE_LANG → Target: $TARGET_LANG"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Auto-detect VCS
  local VCS
  VCS="$(detect_vcs)"

  # Detect tools for target language (gate config applies to target)
  detect_tools "$TARGET_LANG"
  generate_gate_config "$TARGET_LANG"

  echo ""
  echo "Port recipe initialization requires interactive setup"
  echo "(scanning source files, selecting roots, building manifest)."
  echo ""
  echo "The /ralph command will handle the interactive init."
  echo "This script validates the recipe and sets up the directory structure."

  # Shared setup
  init_common

  # Port-specific directories
  create_dir_if_missing "specs/tests" "Test specs directory"
  create_dir_if_missing "specs/src" "Source specs directory"

  # Copy PROMPT files from recipe templates
  create_if_missing "PROMPT_extract_tests.md" "$TEMPLATES/PROMPT_extract_tests.md" "PROMPT_extract_tests.md"
  create_if_missing "PROMPT_extract_src.md" "$TEMPLATES/PROMPT_extract_src.md" "PROMPT_extract_src.md"
  create_if_missing "PROMPT_port.md" "$TEMPLATES/PROMPT_port.md" "PROMPT_port.md"

  # Copy AGENTS.md template unchanged -- ralph.md handles all placeholder substitutions
  # (it has access to all detected values: roots, test/build commands, etc.)
  create_if_missing "AGENTS.md" "$TEMPLATES/AGENTS.md" "AGENTS.md"

  # Generate state.json for port recipe
  generate_state_json "$(jq -n \
    --arg recipe "port" \
    --arg vcs "$VCS" \
    --arg source_language "$SOURCE_LANG" \
    --arg target_language "$TARGET_LANG" \
    '{recipe: $recipe, vcs: $vcs, source_language: $source_language, target_language: $target_language}'
  )"

  # Report
  report_results

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Directory structure created."
  echo "The /ralph command will complete the interactive init"
  echo "(scan source files, build manifest, create PORT_STATE.md,"
  echo " substitute AGENTS.md placeholders)."
  echo ""
  echo "Override: edit ralph/state.json directly if gate defaults are wrong."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================
# RETROSPECTIVE INIT
# Intentionally skips init_common -- retrospective runs against
# an existing project that already has specs/, ralph/,
# IMPLEMENTATION_PLAN.md, and loop.sh.
# ============================================================
init_retrospective() {
  # -- Consistency Contract -----------------------------------------
  # Files referenced by PROMPT templates that must exist at runtime.
  # If you add a new "0x. Read ..." step to any PROMPT, add it here
  # and add a create_if_missing call below.
  #
  # Referenced by all 6 PROMPTs:
  #   retro/retro_state.md       (written by /ralph retro init)
  #   AGENTS.md                  (copied below)
  #   retro/CROSS_REF_STANDARD.md (copied below)
  # -----------------------------------------------------------------
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Ralph Wiggum Toolkit: Initializing (retrospective)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Retrospective output directory
  create_dir_if_missing "retro" "Retrospective output directory"

  # Copy PROMPT files from recipe templates
  create_if_missing "PROMPT_codegap.md" "$TEMPLATES/PROMPT_codegap.md" "PROMPT_codegap.md"
  create_if_missing "PROMPT_implgap.md" "$TEMPLATES/PROMPT_implgap.md" "PROMPT_implgap.md"
  create_if_missing "PROMPT_plugingap.md" "$TEMPLATES/PROMPT_plugingap.md" "PROMPT_plugingap.md"
  create_if_missing "PROMPT_synthesis.md" "$TEMPLATES/PROMPT_synthesis.md" "PROMPT_synthesis.md"
  create_if_missing "PROMPT_explanations.md" "$TEMPLATES/PROMPT_explanations.md" "PROMPT_explanations.md"
  create_if_missing "PROMPT_todo.md" "$TEMPLATES/PROMPT_todo.md" "PROMPT_todo.md"
  create_if_missing "AGENTS.md" "$TEMPLATES/AGENTS.md" "AGENTS.md"
  create_if_missing "retro/CROSS_REF_STANDARD.md" "$RECIPE_DIR/references/cross-ref-standard.md" "CROSS_REF_STANDARD.md"

  # retro_state.md populated by /ralph command (needs interactive detection)

  # Report
  report_results

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Directory structure created."
  echo "The /ralph retro command will complete the interactive init"
  echo "(detect source recipe, build retro_state.md, run phases)."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================
# MAIN: Parse arguments and dispatch
# ============================================================

# Single-pass argument parsing: extract --recipe and build REMAINING_ARGS
RECIPE="greenfield"
REMAINING_ARGS=()

prev=""
for arg in "$@"; do
  if [[ "$prev" == "--recipe" ]]; then
    RECIPE="$arg"
    prev=""
    continue
  fi
  if [[ "$arg" == "--recipe" ]]; then
    prev="$arg"
    continue
  fi
  REMAINING_ARGS+=("$arg")
  prev=""
done

# Validate recipe
RECIPE_DIR="$RECIPES_DIR/$RECIPE"
if [[ ! -d "$RECIPE_DIR" ]]; then
  # Check user recipes
  USER_RECIPES="${HOME}/.claude/ralph-recipes/$RECIPE"
  if [[ -d "$USER_RECIPES" ]]; then
    RECIPE_DIR="$USER_RECIPES"
  else
    echo "Error: Unknown recipe '$RECIPE'." >&2
    echo "Available: $(ls "$RECIPES_DIR/" | tr '\n' ' ')" >&2
    exit 1
  fi
fi

TEMPLATES="$RECIPE_DIR/templates"

# Dispatch to recipe-specific init
case "$RECIPE" in
  greenfield)     init_greenfield ;;
  port)           init_port ;;
  retrospective)  init_retrospective ;;
  *)
    echo "Error: Recipe '$RECIPE' has no init handler." >&2
    echo "Custom recipes require manual init." >&2
    exit 1
    ;;
esac
