#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$(cd "$SCRIPT_DIR/../.." && pwd)/.validate-skill.sh" "$(cd "$SCRIPT_DIR/.." && pwd)"
