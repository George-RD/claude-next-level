#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for s in swarm-improve simplify request-code-review deep-review apply-review-feedback workflow-closeout; do
  echo "== static: $s =="
  "$ROOT/$s/scripts/validate.sh"
done
echo "== behavior evals =="
"$ROOT/.workflow-evals/scripts/eval-workflow-skills.py"
echo "== evidence and maturity =="
"$ROOT/.workflow-evals/scripts/validate-evidence.py"
