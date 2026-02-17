---
name: setup
description: Configure next-level for your project — detects languages, installs linters/formatters, writes config
user_invocable: true
---

# /next-level:setup

You are running the next-level setup wizard. Your job is to detect the project's languages, check for required tooling, install what's missing, and write the configuration file.

## Step 1: Detect Project

Run the dependency detection engine to analyze the current project:

```bash
python3 -c "
import sys
sys.path.insert(0, '${CLAUDE_PLUGIN_ROOT}/lib')
import json
from dependencies import full_dependency_check
result = full_dependency_check('$(pwd)')
print(json.dumps(result, indent=2))
"
```

Parse the output. Report to the user:
- **Languages detected**: list them
- **Tools found**: list available tools per language with versions
- **Tools missing**: list missing tools with install commands
- **Plugins**: omega-memory and coderabbit status

## Step 2: Install Missing Tools

For each missing tool, ask the user if they want to install it. Group by language.

Install commands by language:
- **TypeScript/JS**: `npm install -g prettier eslint`
- **Python**: `uv tool install ruff` and `uv tool install basedpyright`
- **Swift**: `brew install swiftformat swiftlint`
- **Rust**: `rustup component add rustfmt clippy rust-analyzer`
- **Go**: `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest` and `go install golang.org/x/tools/gopls@latest`

Run each install command the user approves. If an install fails, report the error but continue with remaining tools.

## Step 3: Write LSP Configuration

If any LSP servers are available, write `.lsp.json` to the project root:

```json
{
  "lspServers": {
    "basedpyright": { "command": "basedpyright-langserver", "args": ["--stdio"] },
    "vtsls": { "command": "vtsls", "args": ["--stdio"] },
    "sourcekit-lsp": { "command": "sourcekit-lsp" },
    "rust-analyzer": { "command": "rust-analyzer" },
    "gopls": { "command": "gopls", "args": ["serve"] }
  }
}
```

Only include entries for LSP servers that are actually installed. Skip this step if no LSP servers are available.

## Step 4: Write Configuration

Write `~/.next-level/config.json` using the Python config module:

```bash
python3 -c "
import sys
sys.path.insert(0, '${CLAUDE_PLUGIN_ROOT}/lib')
import json
from config import write

config = {
    'setup_complete': True,
    'project_root': '$(pwd)',
    'languages_detected': $LANGUAGES_JSON,
    'features_enabled': {
        'file_checker': True,
        'comment_stripping': True,
        'tdd_enforcement': True,
    },
    'plugins_available': $PLUGINS_JSON,
    'linters': $LINTERS_JSON,
}
write(config)
print('Config written successfully')
"
```

Replace the `$VARIABLES` with actual JSON values from the detection results.

The `linters` field should map each language to its available tools by role:
```json
{
  "python": {"formatter": "ruff", "linter": "ruff", "type_checker": "basedpyright"},
  "typescript": {"formatter": "prettier", "linter": "eslint"}
}
```

Only include tools that are actually installed.

## Step 5: Report

Show the user a summary:

```text
next-level setup complete!

Languages: python, typescript
Features: file_checker, comment_stripping, tdd_enforcement
Linters:
  python: ruff (format+lint), basedpyright (types)
  typescript: prettier (format), eslint (lint)
Plugins:
  omega-memory: not installed (optional — enhanced memory across sessions)
  coderabbit: not installed (optional — AI code review in /spec-verify)

Config: ~/.next-level/config.json
LSP: .lsp.json (written to project root)

Run /next-level:doctor anytime to check health.
```

## Notes

- This skill is idempotent — safe to run multiple times
- If config already exists, it will be overwritten with fresh detection
- Plugin warnings are informational only — next-level works without them
- If `jq` is not installed, warn the user (needed for bash hook scripts)
