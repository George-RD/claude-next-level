#!/usr/bin/env bash
# Diagnostic Report — analyzes hook-events.jsonl to show hook propagation behavior
# Run after a /batch session to see what fired where
set -euo pipefail

LOG_FILE="${HOME}/.next-level/diagnostic/hook-events.jsonl"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "No diagnostic log found at $LOG_FILE"
  echo "Add the diagnostic hook to ~/.claude/settings.json first, then run /batch."
  exit 1
fi

TOTAL=$(wc -l < "$LOG_FILE" | tr -d ' ')
echo "=== Hook Diagnostic Report ==="
echo "Total events logged: $TOTAL"
echo ""

echo "--- By agent context ---"
python3 -c "
import json, sys
from collections import Counter
contexts = Counter()
repos = Counter()
branches = Counter()
worktree_events = 0
main_events = 0
for line in open('$LOG_FILE'):
    line = line.strip()
    if not line: continue
    d = json.loads(line)
    ctx = d.get('agent_context', 'unknown')
    contexts[ctx] += 1
    repos[d.get('repo', 'unknown')] += 1
    branches[d.get('branch', 'unknown')] += 1
    if d.get('is_worktree'): worktree_events += 1
    else: main_events += 1

print('  Main session events:', main_events)
print('  Worktree (batch) events:', worktree_events)
print()
print('--- By repo ---')
for repo, count in repos.most_common():
    print(f'  {repo}: {count}')
print()
print('--- By branch ---')
for branch, count in branches.most_common():
    print(f'  {branch}: {count}')
print()
print('--- By tool ---')
tools = Counter()
for line in open('$LOG_FILE'):
    line = line.strip()
    if not line: continue
    d = json.loads(line)
    tools[d.get('tool', 'unknown')] += 1
for tool, count in tools.most_common():
    print(f'  {tool}: {count}')
print()

# Key finding
if worktree_events > 0:
    print('RESULT: Global hooks DO fire in /batch worktree agents!')
    print(f'  Evidence: {worktree_events} events from worktree sessions')
else:
    print('RESULT: No worktree events detected.')
    if main_events > 0:
        print('  Hooks fired in main session only — they may NOT propagate to /batch agents.')
    else:
        print('  No events at all — check hook installation.')
"

echo ""
echo "--- Raw last 10 events ---"
tail -10 "$LOG_FILE" | python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    d = json.loads(line)
    print(f\"  {d['ts']} | {d['agent_context']:20s} | {d['tool']:10s} | {d['branch']:30s} | {d.get('file','')[:50]}\")
"
