#!/usr/bin/env bash
# SessionStart hook — checks if next-level is configured
# Quick check: config exists with setup_complete: true
# If not: suggest running /next-level:setup
# If yes: check for stale config (languages changed since setup)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Check 1: Does config exist and is setup complete?
if ! config_exists; then
  cat <<'EOF'
{"result":"next-level is not configured. Run /next-level:setup to detect your project's languages and install linters/formatters."}
EOF
  exit 2
fi

if ! config_setup_complete; then
  cat <<'EOF'
{"result":"next-level setup is incomplete. Run /next-level:setup to finish configuration."}
EOF
  exit 2
fi

# Check 2: Is config stale? Compare project root against cwd
config_root=$(config_get "project_root")
current_dir="$(pwd)"
real_config_root="$(cd "$config_root" 2>/dev/null && pwd -P || echo "$config_root")"
real_current_dir="$(pwd -P)"

# Allow cwd to be the config root or a subdirectory of it
if [[ -n "$config_root" && "$real_current_dir" != "$real_config_root" && "$real_current_dir" != "$real_config_root"/* ]]; then
  jq -n --arg root "$config_root" '{"result":"next-level was configured for a different project (\($root)). Run /next-level:setup to reconfigure for this project."}'
  exit 2
fi

# Check 3: Quick staleness check — look for new language config files
# that weren't present at setup time (always scan from config root)
config_langs=$(config_get "languages_detected" 2>/dev/null || echo "[]")
scan_dir="${real_config_root:-$real_current_dir}"

stale=false
# Check for new language indicators not in config
for indicator in package.json tsconfig.json Cargo.toml Package.swift pyproject.toml go.mod; do
  if [[ -f "$scan_dir/$indicator" ]]; then
    case "$indicator" in
      package.json|tsconfig.json)
        if ! echo "$config_langs" | jq -e 'index("typescript") or index("javascript")' > /dev/null 2>&1; then
          stale=true
        fi
        ;;
      Cargo.toml)
        if ! echo "$config_langs" | jq -e 'index("rust")' > /dev/null 2>&1; then
          stale=true
        fi
        ;;
      Package.swift)
        if ! echo "$config_langs" | jq -e 'index("swift")' > /dev/null 2>&1; then
          stale=true
        fi
        ;;
      pyproject.toml)
        if ! echo "$config_langs" | jq -e 'index("python")' > /dev/null 2>&1; then
          stale=true
        fi
        ;;
      go.mod)
        if ! echo "$config_langs" | jq -e 'index("go")' > /dev/null 2>&1; then
          stale=true
        fi
        ;;
    esac
  fi
done

if [[ "$stale" == "true" ]]; then
  cat <<'EOF'
{"result":"next-level config may be stale — new languages detected since last setup. Run /next-level:setup to refresh."}
EOF
  exit 2
fi

# All good — silent exit
exit 0
