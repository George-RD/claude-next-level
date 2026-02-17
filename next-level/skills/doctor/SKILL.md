---
name: doctor
description: Health check for next-level — verifies config, dependencies, hooks, and state directories
user_invocable: true
---

# /next-level:doctor

You are running the next-level health check. Verify everything is properly configured and report status.

## Checks to Run

Run each check and collect results. Use these status indicators:
- `OK` — check passed
- `WARN` — non-critical issue, things will work but not optimally
- `FAIL` — critical issue, feature will not work

### Check 1: Configuration File

```bash
python3 -c "
import sys
sys.path.insert(0, '${CLAUDE_PLUGIN_ROOT}/lib')
from config import exists, read
if not exists():
    print('FAIL: No config found at ~/.next-level/config.json')
    print('FIX: Run /next-level:setup')
else:
    cfg = read()
    if not cfg.get('setup_complete'):
        print('FAIL: Config exists but setup_complete is false')
        print('FIX: Run /next-level:setup')
    else:
        print('OK: Config found, setup complete')
        print('Last updated: ' + cfg.get('last_updated', 'unknown'))
        print('Languages: ' + ', '.join(cfg.get('languages_detected', [])))
"
```

### Check 2: Dependencies Still Present

```bash
python3 -c "
import sys
sys.path.insert(0, '${CLAUDE_PLUGIN_ROOT}/lib')
from dependencies import full_dependency_check, check_binary
from config import read

cfg = read()
project_root = cfg.get('project_root', '.')
result = full_dependency_check(project_root)

if result['missing_tools']:
    for t in result['missing_tools']:
        print(f\"WARN: {t['language']}/{t['tool']} not found — {t['install']}\")
else:
    print('OK: All language tools available')

if not check_binary('jq'):
    print('WARN: jq not installed (needed for bash hooks)')
    print('FIX: brew install jq')
else:
    print('OK: jq available')
"
```

### Check 3: Hook Scripts Executable

Check that all hook scripts in `${CLAUDE_PLUGIN_ROOT}/hooks/scripts/` are executable:

```bash
for script in ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/*.sh ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/*.py; do
  if [ -f "$script" ] && [ ! -x "$script" ]; then
    echo "WARN: $script is not executable"
    echo "FIX: chmod +x $script"
  fi
done
echo "OK: Hook scripts checked"
```

### Check 4: State Directories

```bash
state_dir="${HOME}/.next-level"
if [ -d "$state_dir" ]; then
  echo "OK: State directory exists at $state_dir"
  if [ -w "$state_dir" ]; then
    echo "OK: State directory is writable"
  else
    echo "FAIL: State directory is not writable"
    echo "FIX: chmod u+w $state_dir"
  fi
else
  echo "WARN: State directory does not exist (will be created on first use)"
fi

# Check specs and sessions subdirs
for subdir in specs sessions; do
  if [ -d "$state_dir/$subdir" ]; then
    echo "OK: $state_dir/$subdir exists"
  else
    echo "WARN: $state_dir/$subdir does not exist (will be created on first use)"
  fi
done
```

### Check 5: Stale Config Detection

```bash
python3 -c "
import sys, os
sys.path.insert(0, '${CLAUDE_PLUGIN_ROOT}/lib')
from config import read
from dependencies import detect_languages

cfg = read()
project_root = cfg.get('project_root', '.')
current_langs = detect_languages(project_root)
config_langs = cfg.get('languages_detected', [])

if set(current_langs) != set(config_langs):
    print(f'WARN: Language mismatch — config has {config_langs}, project has {current_langs}')
    print('FIX: Run /next-level:setup to refresh')
else:
    print('OK: Config languages match project')
"
```

### Check 6: Plugin Status

```bash
python3 -c "
import sys
sys.path.insert(0, '${CLAUDE_PLUGIN_ROOT}/lib')
from dependencies import detect_plugins

plugins = detect_plugins()
for name, available in plugins.items():
    status = 'OK' if available else 'WARN'
    state = 'installed' if available else 'not installed (optional)'
    print(f'{status}: {name} — {state}')
"
```

## Report Format

After running all checks, present a summary:

```
next-level doctor report
========================

Configuration:  OK
Dependencies:   OK (2 warnings)
Hook Scripts:   OK
State Dirs:     OK
Config Fresh:   OK
Plugins:        WARN (omega-memory not installed)

Warnings:
  - omega-memory not installed (optional — enhanced session memory)
  - coderabbit not installed (optional — AI code review)

Overall: HEALTHY (2 optional warnings)
```

Use `HEALTHY` if no FAIL results. Use `DEGRADED` if any WARN results exist. Use `UNHEALTHY` if any FAIL results exist.

For each FAIL or WARN, include the fix command or action.
