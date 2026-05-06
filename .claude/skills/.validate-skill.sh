#!/usr/bin/env bash
set -euo pipefail
skill_dir="$1"
name="$(basename "$skill_dir")"
pass=0; fail=0
check() { if bash -c "$2"; then echo "PASS: $1"; pass=$((pass+1)); else echo "FAIL: $1"; fail=$((fail+1)); fi; }
check "SKILL.md exists" "[ -f '$skill_dir/SKILL.md' ]"
check "frontmatter opens" "head -1 '$skill_dir/SKILL.md' | grep -q '^---$'"
check "name matches directory" "grep -q '^name: $name$' '$skill_dir/SKILL.md'"
check "description exists" "grep -q '^description:' '$skill_dir/SKILL.md'"
check "context funnel section exists" "grep -qi 'context funnel' '$skill_dir/SKILL.md'"
check "references mentioned when present" "[ ! -d '$skill_dir/references' ] || grep -q 'references/' '$skill_dir/SKILL.md'"
check "assets mentioned when present" "[ ! -d '$skill_dir/assets' ] || grep -q 'assets/' '$skill_dir/SKILL.md'"
check "no huge entrypoint" "[ \$(wc -l < '$skill_dir/SKILL.md') -le 120 ]"
for ref in "$skill_dir"/references/* "$skill_dir"/assets/*; do
  [ -e "$ref" ] || continue
  b="$(basename "$ref")"
  check "linked artifact $b" "grep -q '$b' '$skill_dir/SKILL.md'"
done
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
