# Ralph Wiggum Toolkit — Architecture Spec

**Date:** 2026-03-18
**Status:** Draft
**Author:** George-RD
**Scope:** Merge ralph-wiggum v1.0.0 and repo-clone v2.0.0 into ralph-wiggum-toolkit v1.0.0

---

## Design Principles

### The Unifying Insight

Both plugins are the same machine with different fuel:

- **Loop infrastructure** (loop.sh, stop-hook.sh, setup-loop.sh, AGENTS.md, IMPLEMENTATION_PLAN.md) is identical across both plugins and 100% reusable.
- **Recipes** (what `init` scaffolds, which PROMPT files exist, how many phases there are) are the only real difference between greenfield and port.

The architecture is: one shared loop engine, pluggable recipes.

### What Does Not Change

Geoffrey's simple prompt style is proven. The stop hook mechanics are correct. The loop.sh/setup-loop.sh pairing is the right abstraction. The manifest from repo-clone is the right universal state tracker. None of these change — they consolidate.

### What Changes

1. One plugin instead of two.
2. `init` accepts `--recipe` to select which recipe to scaffold.
3. The manifest generalizes to cover all recipes (greenfield phases become `plan` and `build` in the manifest).
4. A recipe is a directory with a `recipe.json` contract — discoverable and extensible.
5. The command namespace shortens to `/ralph`.

---

## 1. Directory Structure

```text
ralph-wiggum-toolkit/
├── plugin.json
├── commands/
│   ├── ralph.md              # Unified entry: init, plan, build, status, cancel, help
│   ├── spec.md               # Phase 1 for greenfield (interactive JTBD session)
│   └── help.md               # Full methodology + recipe guide
├── core/
│   ├── scripts/
│   │   ├── init.sh           # Recipe-aware init
│   │   ├── setup-loop.sh     # In-session loop state setup (from ralph-wiggum + --prompt-file flag)
│   │   └── loop.sh           # External bash loop runner (from ralph-wiggum + manifest model reading)
│   └── hooks/
│       ├── hooks.json        # Stop hook registration
│       └── stop-hook.sh      # Stop hook implementation (unchanged from ralph-wiggum)
├── recipes/
│   ├── greenfield/
│   │   ├── recipe.json
│   │   ├── templates/
│   │   │   ├── AGENTS.md
│   │   │   ├── PROMPT_plan.md
│   │   │   ├── PROMPT_build.md
│   │   │   └── PROMPT_plan_work.md
│   │   └── references/
│   │       └── methodology.md
│   └── port/
│       ├── recipe.json
│       ├── templates/
│       │   ├── AGENTS.md             (was AGENTS_port.md in repo-clone)
│       │   ├── PROMPT_extract_tests.md
│       │   ├── PROMPT_extract_src.md
│       │   ├── PROMPT_port.md
│       │   └── manifest-template.json
│       ├── agents/
│       │   ├── spec-extractor.md
│       │   └── parity-checker.md
│       └── references/
│           ├── methodology.md
│           └── semantic-mappings.md
└── skills/
    └── ralph/
        └── SKILL.md
```

---

## 2. File Inventory

### Files to Create (New Content Required)

| File | Description |
|------|-------------|
| `plugin.json` | Plugin manifest |
| `recipes/greenfield/recipe.json` | Greenfield recipe contract (see schema below) |
| `recipes/port/recipe.json` | Port recipe contract (see schema below) |
| `skills/ralph/SKILL.md` | Combined skill trigger file (merged from repo-clone skill) |
| `commands/ralph.md` | Unified dispatcher with recipe detection and legacy migration |
| `commands/help.md` | Combined methodology + recipe guide (merged from both plugins) |
| `core/scripts/init.sh` | Recipe-aware init (replaces both init-project.sh and repo-clone init logic) |

### Files Copied Unchanged or Near-Unchanged

| Source | Destination | Changes |
|--------|-------------|---------|
| `ralph-wiggum/hooks/stop-hook.sh` | `core/hooks/stop-hook.sh` | None |
| `ralph-wiggum/hooks/hooks.json` | `core/hooks/hooks.json` | Update CLAUDE_PLUGIN_ROOT path depth |
| `ralph-wiggum/commands/spec.md` | `commands/spec.md` | Update plugin name references |
| `ralph-wiggum/references/templates/AGENTS.md` | `recipes/greenfield/templates/AGENTS.md` | None |
| `ralph-wiggum/references/templates/PROMPT_plan.md` | `recipes/greenfield/templates/PROMPT_plan.md` | None |
| `ralph-wiggum/references/templates/PROMPT_build.md` | `recipes/greenfield/templates/PROMPT_build.md` | None |
| `ralph-wiggum/references/templates/PROMPT_plan_work.md` | `recipes/greenfield/templates/PROMPT_plan_work.md` | None |
| `ralph-wiggum/references/methodology.md` | `recipes/greenfield/references/methodology.md` | None |
| `repo-clone/data/templates/AGENTS_port.md` | `recipes/port/templates/AGENTS.md` | Rename only |
| `repo-clone/data/templates/PROMPT_extract_tests.md` | `recipes/port/templates/PROMPT_extract_tests.md` | None |
| `repo-clone/data/templates/PROMPT_extract_src.md` | `recipes/port/templates/PROMPT_extract_src.md` | None |
| `repo-clone/data/templates/PROMPT_port.md` | `recipes/port/templates/PROMPT_port.md` | None |
| `repo-clone/data/templates/manifest-template.json` | `recipes/port/templates/manifest-template.json` | Add `"recipe"` and `"version": "3.0.0"` fields |
| `repo-clone/agents/spec-extractor.md` | `recipes/port/agents/spec-extractor.md` | None |
| `repo-clone/agents/parity-checker.md` | `recipes/port/agents/parity-checker.md` | None |
| `repo-clone/references/methodology.md` | `recipes/port/references/methodology.md` | None |
| `repo-clone/references/semantic-mappings.md` | `recipes/port/references/semantic-mappings.md` | None |

### Files Modified (Non-Trivial Changes)

| File | Modification |
|------|-------------|
| `core/scripts/setup-loop.sh` | Add `--prompt-file <path>` optional flag; when provided, use it instead of mode-derived default. Validate file exists. |
| `core/scripts/loop.sh` | After parsing MODE, check `ralph/manifest.json` for `default_model`; pass as `--model` to `claude -p`. Fall back to `opus` if manifest absent. |

### Files Deprecated (Keep Until v2.0.0)

| Directory | Status |
|-----------|--------|
| `ralph-wiggum/` (entire) | Deprecated — keep in marketplace.json with deprecation notice |
| `repo-clone/` (entire) | Deprecated — keep in marketplace.json with deprecation notice |

### Marketplace Update

| File | Change |
|------|--------|
| `.claude-plugin/marketplace.json` | Add `ralph-wiggum-toolkit` entry; mark `ralph-wiggum` and `repo-clone` as deprecated |

---

## 3. Command Design

### Namespace

`/ralph` — single namespace. Recipe selection happens once at `init`; all subsequent commands operate on the initialized project.

Deprecated aliases `/ralph-wiggum:*` and `/repo-clone:*` are not implemented in the new plugin. The old plugins remain installed and functional until users migrate.

### Full Command Table

| Command | Argument Hint | Description |
|---------|--------------|-------------|
| `/ralph init` | `[--recipe <name>] [recipe args]` | Initialize project with chosen recipe |
| `/ralph spec` | `[topic description]` | Phase 1: JTBD interview and spec writing (greenfield only) |
| `/ralph plan` | `[--max-iterations N] [--completion-promise TEXT]` | Run planning loop |
| `/ralph build` | `[--max-iterations N] [--completion-promise TEXT]` | Run build loop |
| `/ralph status` | — | Show project state from manifest |
| `/ralph cancel` | — | Cancel active in-session loop |
| `/ralph help` | — | Full guide: methodology + all recipes |

### Init Command Argument Signatures

```
/ralph init                                          # greenfield (default recipe)
/ralph init --recipe greenfield                      # explicit greenfield
/ralph init --recipe greenfield --src-dir app        # custom source dir
/ralph init --recipe greenfield --goal "build X"     # inject goal into PROMPT_plan.md
/ralph init --recipe port dart typescript            # port recipe, positional lang args
/ralph init --recipe port --src dart --tgt typescript # port recipe, named lang args
```

### plan and build Command Behavior

After init, `/ralph plan` and `/ralph build` work identically for all recipes. They read `ralph/manifest.json` to detect the active recipe, then:

- **Greenfield**: call `setup-loop.sh --mode plan` (uses `PROMPT_plan.md`) or `--mode build` (uses `PROMPT_build.md`)
- **Port**: call `setup-loop.sh --mode plan --prompt-file PROMPT_port.md` or `--mode build --prompt-file PROMPT_port.md`

The extraction phases (`extract-tests`, `extract-src`) of the port recipe have no in-session command. They are external headless loops only, with instructions shown during `init` and in `help`.

### status Command Behavior

`/ralph status` reads `ralph/manifest.json`. It detects the recipe from the `"recipe"` field and renders phases accordingly. It also detects legacy paths:

- If `porting/manifest.json` exists (repo-clone legacy): offer migration to `ralph/manifest.json`
- If neither `ralph/manifest.json` nor `porting/manifest.json` exists but ralph-wiggum files do (specs/, AGENTS.md, etc.): treat as uninitialized greenfield and show status based on file presence

---

## 4. Recipe Interface Contract

A recipe is a directory under `recipes/` containing:

### recipe.json Schema

```json
{
  "name": "string",
  "description": "string",
  "version": "string",
  "phases": ["array of phase names in order"],
  "loop_phases": ["subset of phases that use the stop hook / loop.sh"],
  "headless_phases": ["subset of phases that are external-loop-only"],
  "init_args": [
    {
      "name": "string",
      "flag": "--flag-name (optional, for named args)",
      "positional": 0,
      "description": "string",
      "default": "string (optional)",
      "required": true
    }
  ],
  "default_model": "haiku | sonnet | opus",
  "prompt_map": {
    "phase-name": "PROMPT_file.md"
  },
  "manifest_template": "manifest-template.json | null"
}
```

### Greenfield recipe.json

```json
{
  "name": "greenfield",
  "description": "User-written specs to plan to build. For new features and greenfield projects.",
  "version": "1.0.0",
  "phases": ["spec", "plan", "build"],
  "loop_phases": ["plan", "build"],
  "headless_phases": [],
  "init_args": [
    {
      "name": "src-dir",
      "flag": "--src-dir",
      "description": "Source code directory",
      "default": "src",
      "required": false
    },
    {
      "name": "goal",
      "flag": "--goal",
      "description": "Project goal for PROMPT_plan.md placeholder",
      "required": false
    }
  ],
  "default_model": "opus",
  "prompt_map": {
    "plan": "PROMPT_plan.md",
    "build": "PROMPT_build.md"
  },
  "manifest_template": null
}
```

### Port recipe.json

```json
{
  "name": "port",
  "description": "Extract behavioral specs from an existing codebase, then port to target language.",
  "version": "1.0.0",
  "phases": ["extract-tests", "extract-src", "plan", "build", "audit"],
  "loop_phases": ["plan", "build"],
  "headless_phases": ["extract-tests", "extract-src"],
  "init_args": [
    {
      "name": "source-lang",
      "positional": 0,
      "description": "Source language (e.g. dart, rust, python)",
      "required": true
    },
    {
      "name": "target-lang",
      "positional": 1,
      "description": "Target language (e.g. typescript, python, go)",
      "required": true
    }
  ],
  "default_model": "haiku",
  "prompt_map": {
    "extract-tests": "PROMPT_extract_tests.md",
    "extract-src": "PROMPT_extract_src.md",
    "plan": "PROMPT_port.md",
    "build": "PROMPT_port.md"
  },
  "manifest_template": "manifest-template.json"
}
```

### What a Recipe Must Provide

| Artifact | Location | Required |
|----------|----------|----------|
| `recipe.json` | `recipes/<name>/recipe.json` | Yes |
| PROMPT templates | `recipes/<name>/templates/PROMPT_*.md` | Yes (one per loop phase) |
| `AGENTS.md` template | `recipes/<name>/templates/AGENTS.md` | Yes |
| `manifest-template.json` | `recipes/<name>/templates/` | Only if manifest_template is set |
| Agents | `recipes/<name>/agents/*.md` | No |
| References | `recipes/<name>/references/*.md` | No |

### Adding a Custom Recipe

Users can place a recipe at `~/.claude/ralph-recipes/<name>/` with the same directory structure. `init.sh` checks built-in recipes first, then user recipes. This is the extensibility hook for future `refactor`, `migrate-framework`, and `test-backfill` recipes.

---

## 5. Universal Manifest (ralph/manifest.json)

Every `/ralph init` creates `ralph/manifest.json`. The `"recipe"` field enables recipe-aware status rendering.

### Greenfield Manifest

```json
{
  "version": "3.0.0",
  "recipe": "greenfield",
  "src_dir": "src",
  "goal": "[project-specific goal]",
  "default_model": "opus",
  "created": "YYYY-MM-DD",
  "phases": {
    "plan": { "status": "pending" },
    "build": { "status": "pending" }
  }
}
```

No file-level tracking for greenfield — specs are human-written. The manifest exists for status display and recipe identification.

### Port Manifest

```json
{
  "version": "3.0.0",
  "recipe": "port",
  "source_lang": "dart",
  "target_lang": "typescript",
  "source_root": "lib",
  "target_root": "src-ts",
  "test_command": "npm test",
  "build_command": "npm run build",
  "default_model": "haiku",
  "created": "YYYY-MM-DD",
  "phases": {
    "extract-tests": { "status": "pending", "files": {} },
    "extract-src":   { "status": "pending", "files": {} },
    "plan":          { "status": "pending" },
    "build":         { "status": "pending" },
    "audit":         { "status": "pending" }
  }
}
```

This is repo-clone's existing `manifest-template.json` extended with `"recipe"` and `"version": "3.0.0"`. Per-file tracking is unchanged.

### Manifest Location Change (repo-clone migration)

Old path: `porting/manifest.json`
New path: `ralph/manifest.json`

Supporting files move accordingly:
- `porting/PORT_STATE.md` → `ralph/PORT_STATE.md`
- `porting/SEMANTIC_MISMATCHES.md` → `ralph/SEMANTIC_MISMATCHES.md`

---

## 6. Shared State File Conventions

All recipes write to these locations in the project root. The loop infrastructure expects them here.

| File | Purpose | Created by | Recipe |
|------|---------|-----------|--------|
| `ralph/manifest.json` | Universal progress tracker | `/ralph init` | All |
| `AGENTS.md` | Operational guide (~60 lines) | `/ralph init` | All |
| `IMPLEMENTATION_PLAN.md` | Shared state between iterations | Planning loop | All |
| `specs/` | Source of truth | User (greenfield) or extraction loops (port) | All |
| `specs/tests/` | Extracted test behavioral specs | Extraction loop | Port |
| `specs/src/` | Extracted source behavioral specs | Extraction loop | Port |
| `PROMPT_plan.md` | Planning loop prompt | `/ralph init` | Greenfield |
| `PROMPT_build.md` | Build loop prompt | `/ralph init` | Greenfield |
| `PROMPT_extract_tests.md` | Test extraction loop prompt | `/ralph init --recipe port` | Port |
| `PROMPT_extract_src.md` | Source extraction loop prompt | `/ralph init --recipe port` | Port |
| `PROMPT_port.md` | Port plan + build loop prompt | `/ralph init --recipe port` | Port |
| `ralph/PORT_STATE.md` | Human-readable manifest view | `/ralph status` | Port |
| `ralph/SEMANTIC_MISMATCHES.md` | Known language divergences | `/ralph init --recipe port` | Port |
| `loop.sh` | External loop runner | `/ralph init` | All |
| `.claude/ralph-wiggum.local.md` | In-session loop state | `setup-loop.sh` | All |

The `.claude/ralph-wiggum.local.md` filename is preserved for backward compatibility. Renaming it to `.claude/ralph.local.md` is a v2.0.0 breaking change.

---

## 7. Loop Mechanism Availability

| Phase | In-Session (`/ralph plan`, `/ralph build`) | External (`./loop.sh`) |
|-------|------------------------------------------|----------------------|
| greenfield: plan | Yes | Yes |
| greenfield: build | Yes | Yes |
| port: extract-tests | No — headless only | Yes (via `while :; do cat PROMPT_extract_tests.md \| claude -p --model haiku`) |
| port: extract-src | No — headless only | Yes |
| port: plan | Yes | Yes |
| port: build | Yes | Yes |
| port: audit | No — interactive review | No |

Extraction phases are headless-only because they use Haiku for throughput, are inherently file-parallel, and the stop hook adds no value for stateless single-file extraction. The `loop.sh` scaffolded for port recipe projects includes the extraction commands in its header comment for reference.

---

## 8. Data Flow

### Greenfield Recipe

```
/ralph init [--recipe greenfield] [--src-dir app] [--goal "build X"]
  core/scripts/init.sh --recipe greenfield
    Creates: specs/, ralph/manifest.json, AGENTS.md, IMPLEMENTATION_PLAN.md
    Copies:  PROMPT_plan.md, PROMPT_build.md, PROMPT_plan_work.md
    Copies:  core/scripts/loop.sh -> ./loop.sh

/ralph spec [topic]
  commands/spec.md
    Interactive JTBD session
    Writes: specs/TOPIC.md (user-driven, no loop)

/ralph plan [--max-iterations 3]
  commands/ralph.md detects recipe=greenfield from ralph/manifest.json
  core/scripts/setup-loop.sh --mode plan
    Reads:  PROMPT_plan.md
    Writes: .claude/ralph-wiggum.local.md
    Loop:   reads specs/*, writes IMPLEMENTATION_PLAN.md

/ralph build [--completion-promise "all tests pass"]
  commands/ralph.md detects recipe=greenfield
  core/scripts/setup-loop.sh --mode build
    Loop:   reads specs/*, IMPLEMENTATION_PLAN.md
            implements -> tests -> commits -> updates plan
```

### Port Recipe

```
/ralph init --recipe port dart typescript
  core/scripts/init.sh --recipe port dart typescript
    Scans source repo, categorizes files (test/source/config/asset/doc)
    Creates: specs/tests/, specs/src/, ralph/manifest.json
    Writes:  AGENTS.md (with {LANG} substitutions from AGENTS.md template)
    Copies:  PROMPT_extract_tests.md, PROMPT_extract_src.md, PROMPT_port.md
    Creates: ralph/SEMANTIC_MISMATCHES.md (from semantic-mappings.md for dart-ts pair)
    Creates: ralph/PORT_STATE.md (human-readable view)
    Creates: IMPLEMENTATION_PLAN.md (empty placeholder)
    Copies:  core/scripts/loop.sh -> ./loop.sh

[External — no in-session command]
while :; do cat PROMPT_extract_tests.md | claude -p --model haiku \
  --dangerously-skip-permissions; sleep 5; done
  Each iteration: reads ralph/manifest.json -> next pending test file
    -> extracts behavioral spec -> writes specs/tests/{file}_spec.md
    -> updates manifest (file.status = "done") -> commits

while :; do cat PROMPT_extract_src.md | claude -p --model haiku \
  --dangerously-skip-permissions; sleep 5; done
  Same pattern: specs/src/{file}_spec.md

/ralph plan [--max-iterations 2]
  commands/ralph.md detects recipe=port
  core/scripts/setup-loop.sh --mode plan --prompt-file PROMPT_port.md
    Loop:   reads specs/*, writes IMPLEMENTATION_PLAN.md

/ralph build
  commands/ralph.md detects recipe=port
  core/scripts/setup-loop.sh --mode build --prompt-file PROMPT_port.md
    Loop:   reads specs/*, IMPLEMENTATION_PLAN.md, follows citations
            implements in target lang -> runs target tests -> commits

/ralph status
  commands/ralph.md reads ralph/manifest.json
    Renders phase table with per-file progress counts
    Shows next action recommendation
    Regenerates ralph/PORT_STATE.md
```

---

## 9. Migration Path

### Existing ralph-wiggum Users

1. Install `ralph-wiggum-toolkit` — it coexists with `ralph-wiggum`
2. No project file migration needed: the greenfield recipe uses the same files (`specs/`, `AGENTS.md`, `IMPLEMENTATION_PLAN.md`, `PROMPT_plan.md`, `PROMPT_build.md`, `loop.sh`)
3. Run `/ralph status` in any existing ralph-wiggum project. The command detects existing ralph-wiggum files (no `ralph/manifest.json`) and synthesizes status from file presence
4. The only workflow change: use `/ralph plan` and `/ralph build` instead of `/ralph-wiggum:plan` and `/ralph-wiggum:build`
5. After validation: mark `ralph-wiggum` deprecated in marketplace.json

### Existing repo-clone Users

1. Install `ralph-wiggum-toolkit` — it coexists with `repo-clone`
2. Run `/ralph status` in any existing repo-clone project
3. The command detects `porting/manifest.json` and prompts: "Found porting/manifest.json from repo-clone v2. Migrate to ralph/manifest.json? [y/N]"
4. Migration adds `"recipe": "port"` and `"version": "3.0.0"` to the manifest, moves it to `ralph/manifest.json`, moves `porting/PORT_STATE.md` and `porting/SEMANTIC_MISMATCHES.md` to `ralph/`
5. In-progress ports continue immediately — all PROMPT files and specs are untouched
6. The only workflow change: use `/ralph status` instead of `/repo-clone status`
7. After validation: mark `repo-clone` deprecated in marketplace.json

### Backward Compatibility Guarantees

- `IMPLEMENTATION_PLAN.md`, `AGENTS.md`, `specs/`, `loop.sh` are content-identical between old and new. No content migration.
- `.claude/ralph-wiggum.local.md` state file name is preserved. Active loops continue working.
- `porting/manifest.json` is detected as a legacy location. Manual migration is offered, not forced.

---

## 10. plugin.json

```json
{
  "name": "ralph-wiggum-toolkit",
  "description": "Recipe-based autonomous development loops. Greenfield recipe: JTBD specs to plan to build. Port recipe: extract behavioral specs from existing codebase, port to target language. Implements Geoffrey Huntley's Ralph methodology with manifest-driven progress tracking.",
  "version": "1.0.0",
  "author": {
    "name": "George-RD"
  },
  "keywords": [
    "ralph", "loop", "autonomous", "spec-driven", "jtbd",
    "porting", "migration", "manifest-driven", "recipe"
  ]
}
```

---

## 11. Critical Implementation Details

### setup-loop.sh: --prompt-file Flag

Add after existing flag parsing (before the mode validation block):

```bash
--prompt-file)
  if [[ -z "${2:-}" ]] || [[ "${2:-}" == -* ]]; then
    echo "Error: --prompt-file requires a path" >&2
    exit 1
  fi
  PROMPT_FILE_OVERRIDE="$2"
  shift 2
  ;;
```

After the `case "$MODE"` block that sets `PROMPT_FILE`, override if provided:

```bash
if [[ -n "${PROMPT_FILE_OVERRIDE:-}" ]]; then
  PROMPT_FILE="$PROMPT_FILE_OVERRIDE"
fi
```

This is a 10-line addition to an otherwise unchanged script.

### loop.sh: Manifest Model Reading

Add before the `while true` loop:

```bash
# Read model from manifest if present
CLAUDE_MODEL="opus"
if [[ -f "ralph/manifest.json" ]]; then
  MANIFEST_MODEL=$(python3 -c "
import json, sys
try:
  d = json.load(open('ralph/manifest.json'))
  print(d.get('default_model', 'opus'))
except:
  print('opus')
" 2>/dev/null || echo "opus")
  CLAUDE_MODEL="$MANIFEST_MODEL"
fi
```

In the `claude -p` invocation, add `--model "$CLAUDE_MODEL"`. This replaces the current hardcoded `--model opus`.

### commands/ralph.md: Recipe Detection Logic

The command needs to detect which recipe is active. Detection order:

1. Check `ralph/manifest.json` — read `"recipe"` field
2. Check `porting/manifest.json` — treat as recipe=port (legacy)
3. Neither exists but `PROMPT_plan.md` / `PROMPT_build.md` are present — treat as greenfield (uninitialized with no manifest)
4. Nothing — uninitialized project, show init instructions

This detection is used by `plan`, `build`, and `status` to select the correct PROMPT file and render the correct status view.

### core/scripts/init.sh Structure

```bash
#!/bin/bash
# Ralph Wiggum Toolkit - Recipe-aware init

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RECIPES_DIR="$PLUGIN_ROOT/recipes"

# Parse --recipe flag (first pass)
RECIPE="greenfield"
for i in "$@"; do
  if [[ "$prev" == "--recipe" ]]; then RECIPE="$i"; fi
  prev="$i"
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

# Dispatch to recipe-specific init
case "$RECIPE" in
  greenfield) init_greenfield "$@" ;;
  port)       init_port "$@" ;;
  *)
    # Generic init using recipe.json metadata
    init_generic "$RECIPE" "$RECIPE_DIR" "$@"
    ;;
esac
```

The `init_greenfield` function is the existing `init-project.sh` logic refactored to read templates from `$RECIPE_DIR/templates/` and write `ralph/manifest.json`. The `init_port` function is the repo-clone init logic refactored similarly.

### Manifest Path: ralph/ Not porting/

The `ralph/` directory must be created during init:

```bash
mkdir -p ralph
```

All state files (manifest.json, PORT_STATE.md, SEMANTIC_MISMATCHES.md) go there. The `specs/` directory remains at project root (not inside `ralph/`) — this is consistent with ralph-wiggum's convention and avoids path changes in prompt files.

### Stop Hook: No Changes Needed

The stop hook reads `.claude/ralph-wiggum.local.md` and operates on the PROMPT text stored there. It has zero recipe awareness — it just feeds the prompt back. This is its virtue. Do not modify it.

---

## 12. Implementation Phases

### Phase 1: Scaffold and Copy (no logic changes)

- [ ] Create `ralph-wiggum-toolkit/` directory structure
- [ ] Write `plugin.json`
- [ ] Copy `core/hooks/stop-hook.sh` from ralph-wiggum (chmod +x)
- [ ] Write `core/hooks/hooks.json` (update CLAUDE_PLUGIN_ROOT path depth from `..` to `../..`)
- [ ] Copy `recipes/greenfield/templates/` from `ralph-wiggum/references/templates/`
- [ ] Copy `recipes/greenfield/references/methodology.md`
- [ ] Write `recipes/greenfield/recipe.json`
- [ ] Copy `recipes/port/templates/` from `repo-clone/data/templates/` (rename AGENTS_port.md to AGENTS.md)
- [ ] Copy `recipes/port/agents/` from `repo-clone/agents/`
- [ ] Copy `recipes/port/references/` from `repo-clone/references/`
- [ ] Write `recipes/port/recipe.json`
- [ ] Update `recipes/port/templates/manifest-template.json` — add `"recipe": "port"` and `"version": "3.0.0"` fields
- [ ] Copy `commands/spec.md` from `ralph-wiggum/commands/spec.md` (update plugin name)

### Phase 2: Core Scripts

- [ ] Write `core/scripts/init.sh` (recipe-aware, dispatches to greenfield and port init functions)
  - Greenfield path: replicate `ralph-wiggum/scripts/init-project.sh` using new template paths, write `ralph/manifest.json`
  - Port path: replicate `repo-clone/commands/repo-clone.md` init logic, write `ralph/manifest.json`
  - Both paths: copy `loop.sh` from core to project root
- [ ] Copy `core/scripts/setup-loop.sh` from ralph-wiggum + add `--prompt-file` flag (10 lines)
- [ ] Copy `core/scripts/loop.sh` from ralph-wiggum + add manifest model reading (10 lines)
- [ ] Make all scripts executable (`chmod +x`)

### Phase 3: Commands

- [ ] Write `commands/ralph.md` (unified dispatcher):
  - `init` dispatch with `--recipe` parsing
  - Recipe detection logic (reads `ralph/manifest.json` or `porting/manifest.json`)
  - `plan` / `build` dispatch with prompt-file selection based on recipe
  - `status` with recipe-aware manifest rendering
  - `cancel` (read + delete `.claude/ralph-wiggum.local.md`)
  - Legacy detection: offer `porting/manifest.json` migration
- [ ] Write `commands/help.md` (merged from both plugins, includes recipe guide and extraction loop commands)

### Phase 4: Skills and Marketplace

- [ ] Write `skills/ralph/SKILL.md` (merged trigger phrases: "port", "clone to", "migrate", "rewrite in", "build feature", "spec-driven", "ralph loop")
- [ ] Update `.claude-plugin/marketplace.json`:
  - Add `ralph-wiggum-toolkit` entry with `"source": "./ralph-wiggum-toolkit"`
  - Add `"deprecated": true` and `"deprecation_message": "Replaced by ralph-wiggum-toolkit"` to `ralph-wiggum` and `repo-clone` entries

### Phase 5: Validation

- [ ] Test greenfield: `/ralph init` in scratch project; verify `ralph/manifest.json` created, PROMPT files copied, `loop.sh` present
- [ ] Test greenfield loop: `/ralph plan --max-iterations 2` in scratch project; verify stop hook iterates
- [ ] Test port init: `/ralph init --recipe port dart typescript` in scratch project with dart source; verify manifest populated with files, AGENTS.md has substitutions, SEMANTIC_MISMATCHES.md created
- [ ] Test port loop: `./loop.sh plan 2` in port-init'd project; verify `--model haiku` passed to claude
- [ ] Test legacy detection (ralph-wiggum): run `/ralph status` in existing ralph-wiggum project (no `ralph/manifest.json`); verify status synthesized from file presence
- [ ] Test legacy detection (repo-clone): run `/ralph status` in existing repo-clone project (has `porting/manifest.json`); verify migration offer appears
- [ ] Test recipe validation: run `/ralph init --recipe nonexistent`; verify error lists available recipes

---

## 13. Open Questions (Deferred)

**Q1: State file rename.** Should `.claude/ralph-wiggum.local.md` become `.claude/ralph.local.md`?
Recommendation: defer to v2.0.0. Rename is breaking for active loops. The toolkit can detect both names as a v2.0.0 migration.

**Q2: Custom recipe path.** `~/.claude/ralph-recipes/<name>/` for user recipes?
Recommendation: yes, implement in Phase 2 of init.sh. Document in help.md. Low priority for v1.0.0.

**Q3: plan-work mode for port recipe.** The greenfield recipe supports `plan-work "scope"` for feature-branch scoped planning. Port equivalent: porting a single module.
Recommendation: defer. Add `--scope <module>` to `/ralph plan` in v1.1.0.

**Q4: Deprecation timeline.** When to remove `ralph-wiggum` and `repo-clone` from marketplace?
Recommendation: deprecate in toolkit v1.0.0 (still installable, show notice), remove from marketplace in toolkit v2.0.0 (30+ days after v1.0.0).

**Q5: loop.sh python3 dependency for manifest reading.** The proposed manifest model reading uses python3.
Recommendation: use shell-only JSON parsing via `grep` + `sed` for the single `default_model` field — avoids python3 dependency. Example: `grep '"default_model"' ralph/manifest.json | sed 's/.*": *"\([^"]*\)".*/\1/'`.
```

---

Now I'll write this to the file. Since I don't have a Write tool in this context, I need to produce the spec as my response clearly. Let me do one final check of the file path before presenting:

The spec document goes to `/Users/george/repos/claude-next-level/docs/plans/ralph-toolkit-spec.md`.

Since I can only read files (no write tool is available in this session), I'll present the complete spec content here, fully formatted and ready to write to disk. The user or an implementation agent can write it.

---

Here is the complete architecture blueprint. The spec document ready to write to `/Users/george/repos/claude-next-level/docs/plans/ralph-toolkit-spec.md`:

---

# Ralph Wiggum Toolkit — Architecture Spec

**Date:** 2026-03-18
**Status:** Draft
**Author:** George-RD
**Scope:** Merge ralph-wiggum v1.0.0 and repo-clone v2.0.0 into ralph-wiggum-toolkit v1.0.0

---

## Design Principles

### The Unifying Insight

Both plugins are the same machine with different fuel. The loop infrastructure (loop.sh, stop-hook.sh, setup-loop.sh, AGENTS.md, IMPLEMENTATION_PLAN.md) is 100% recipe-agnostic — identical across both plugins. The recipe (what `init` scaffolds, which PROMPT files exist, how many phases there are) is the only real difference between greenfield and port. The architecture is: one shared loop engine, pluggable recipes.

### What Does Not Change

Geoffrey's simple prompt style is proven. The stop hook mechanics are correct. The loop.sh/setup-loop.sh pairing is the right abstraction. The manifest from repo-clone is the right universal state tracker. None of these change — they consolidate.

### What Changes

1. One plugin instead of two.
2. `init` accepts `--recipe` to select which recipe to scaffold.
3. The manifest generalizes to cover all recipes.
4. A recipe is a directory with a `recipe.json` contract — discoverable and extensible.
5. The command namespace shortens to `/ralph`.

---

## 1. Directory Structure

```text
ralph-wiggum-toolkit/
├── plugin.json
├── commands/
│   ├── ralph.md              # Unified entry: init, plan, build, status, cancel, help
│   ├── spec.md               # Phase 1 for greenfield (interactive JTBD session)
│   └── help.md               # Full methodology + recipe guide
├── core/
│   ├── scripts/
│   │   ├── init.sh           # Recipe-aware init (replaces init-project.sh + repo-clone init)
│   │   ├── setup-loop.sh     # In-session loop state setup (from ralph-wiggum + --prompt-file flag)
│   │   └── loop.sh           # External bash loop runner (from ralph-wiggum + manifest model reading)
│   └── hooks/
│       ├── hooks.json        # Stop hook registration
│       └── stop-hook.sh      # Stop hook implementation (unchanged from ralph-wiggum)
├── recipes/
│   ├── greenfield/
│   │   ├── recipe.json
│   │   ├── templates/
│   │   │   ├── AGENTS.md
│   │   │   ├── PROMPT_plan.md
│   │   │   ├── PROMPT_build.md
│   │   │   └── PROMPT_plan_work.md
│   │   └── references/
│   │       └── methodology.md
│   └── port/
│       ├── recipe.json
│       ├── templates/
│       │   ├── AGENTS.md                    (was AGENTS_port.md in repo-clone)
│       │   ├── PROMPT_extract_tests.md
│       │   ├── PROMPT_extract_src.md
│       │   ├── PROMPT_port.md
│       │   └── manifest-template.json
│       ├── agents/
│       │   ├── spec-extractor.md
│       │   └── parity-checker.md
│       └── references/
│           ├── methodology.md
│           └── semantic-mappings.md
└── skills/
    └── ralph/
        └── SKILL.md
```

---

## 2. File Inventory

### Files to Create (New Content Required)

| File | Description |
|------|-------------|
| `plugin.json` | Plugin manifest |
| `recipes/greenfield/recipe.json` | Greenfield recipe contract |
| `recipes/port/recipe.json` | Port recipe contract |
| `skills/ralph/SKILL.md` | Combined skill trigger file |
| `commands/ralph.md` | Unified dispatcher with recipe detection and legacy migration |
| `commands/help.md` | Combined methodology + recipe guide |
| `core/scripts/init.sh` | Recipe-aware init (replaces init-project.sh and repo-clone init logic) |

### Files Copied Unchanged or Near-Unchanged

| Source | Destination | Changes |
|--------|-------------|---------|
| `ralph-wiggum/hooks/stop-hook.sh` | `core/hooks/stop-hook.sh` | None |
| `ralph-wiggum/hooks/hooks.json` | `core/hooks/hooks.json` | Update CLAUDE_PLUGIN_ROOT path depth (`../..`) |
| `ralph-wiggum/commands/spec.md` | `commands/spec.md` | Update plugin name references |
| `ralph-wiggum/references/templates/AGENTS.md` | `recipes/greenfield/templates/AGENTS.md` | None |
| `ralph-wiggum/references/templates/PROMPT_plan.md` | `recipes/greenfield/templates/PROMPT_plan.md` | None |
| `ralph-wiggum/references/templates/PROMPT_build.md` | `recipes/greenfield/templates/PROMPT_build.md` | None |
| `ralph-wiggum/references/templates/PROMPT_plan_work.md` | `recipes/greenfield/templates/PROMPT_plan_work.md` | None |
| `ralph-wiggum/references/methodology.md` | `recipes/greenfield/references/methodology.md` | None |
| `repo-clone/data/templates/AGENTS_port.md` | `recipes/port/templates/AGENTS.md` | Rename only |
| `repo-clone/data/templates/PROMPT_extract_tests.md` | `recipes/port/templates/PROMPT_extract_tests.md` | None |
| `repo-clone/data/templates/PROMPT_extract_src.md` | `recipes/port/templates/PROMPT_extract_src.md` | None |
| `repo-clone/data/templates/PROMPT_port.md` | `recipes/port/templates/PROMPT_port.md` | None |
| `repo-clone/data/templates/manifest-template.json` | `recipes/port/templates/manifest-template.json` | Add `"recipe": "port"` and `"version": "3.0.0"` |
| `repo-clone/agents/spec-extractor.md` | `recipes/port/agents/spec-extractor.md` | None |
| `repo-clone/agents/parity-checker.md` | `recipes/port/agents/parity-checker.md` | None |
| `repo-clone/references/methodology.md` | `recipes/port/references/methodology.md` | None |
| `repo-clone/references/semantic-mappings.md` | `recipes/port/references/semantic-mappings.md` | None |

### Files Modified (Non-Trivial Logic Changes)

| File | Modification |
|------|-------------|
| `core/scripts/setup-loop.sh` | Add `--prompt-file <path>` optional flag. When provided, override the mode-derived PROMPT_FILE. Validate file exists before writing state. ~10 lines. |
| `core/scripts/loop.sh` | Read `ralph/manifest.json`'s `default_model` field using shell grep/sed; pass as `--model` to `claude -p`. Fall back to `opus` if manifest absent. ~8 lines. |

### Files Deprecated (Keep Until v2.0.0)

`ralph-wiggum/` (entire) and `repo-clone/` (entire) remain in the repo but are marked deprecated in marketplace.json.

### Marketplace Change

`.claude-plugin/marketplace.json`: add `ralph-wiggum-toolkit` entry; add `"deprecated": true` and deprecation message to `ralph-wiggum` and `repo-clone` entries.

---

## 3. Command Design

### Namespace

`/ralph` — single namespace for all commands. Recipe selection happens once at `init`. All subsequent commands operate on the initialized project.

The old namespaces (`/ralph-wiggum:*`, `/repo-clone:*`) are not re-implemented in the new plugin. Both old plugins remain installed and functional until users migrate.

### Command Table

| Command | Argument Hint | Description |
|---------|--------------|-------------|
| `/ralph init` | `[--recipe <name>] [recipe-specific args]` | Initialize project with chosen recipe |
| `/ralph spec` | `[topic description]` | Phase 1: JTBD interview and spec writing (greenfield only) |
| `/ralph plan` | `[--max-iterations N] [--completion-promise TEXT]` | Run planning loop |
| `/ralph build` | `[--max-iterations N] [--completion-promise TEXT]` | Run build loop |
| `/ralph status` | — | Show project state from manifest |
| `/ralph cancel` | — | Cancel active in-session loop |
| `/ralph help` | — | Full guide: methodology + all recipes |

### Init Argument Signatures

```
/ralph init                                          # greenfield (default)
/ralph init --recipe greenfield                      # explicit greenfield
/ralph init --recipe greenfield --src-dir app --goal "build X"
/ralph init --recipe port dart typescript            # port, positional lang args
/ralph init --recipe port --src dart --tgt typescript
```

### plan and build Behavior After Init

Both commands read `ralph/manifest.json` to detect the active recipe, then:

- Greenfield: `setup-loop.sh --mode plan` (uses `PROMPT_plan.md`) or `--mode build` (uses `PROMPT_build.md`)
- Port: `setup-loop.sh --mode plan --prompt-file PROMPT_port.md` or `--mode build --prompt-file PROMPT_port.md`

The extraction phases (`extract-tests`, `extract-src`) of the port recipe have no in-session command. They are external headless-only loops, with commands shown during `init` and in `help`.

---

## 4. Recipe Interface Contract

### recipe.json Schema

```json
{
  "name": "string",
  "description": "string",
  "version": "string",
  "phases": ["ordered array of phase names"],
  "loop_phases": ["phases that support stop hook + loop.sh"],
  "headless_phases": ["phases that are external-loop-only"],
  "init_args": [
    {
      "name": "arg-name",
      "flag": "--flag (for named args)",
      "positional": 0,
      "description": "string",
      "default": "optional default value",
      "required": true
    }
  ],
  "default_model": "haiku | sonnet | opus",
  "prompt_map": { "phase-name": "PROMPT_file.md" },
  "manifest_template": "filename.json | null"
}
```

### Greenfield recipe.json

```json
{
  "name": "greenfield",
  "description": "User-written specs to plan to build. For new features and greenfield projects.",
  "version": "1.0.0",
  "phases": ["spec", "plan", "build"],
  "loop_phases": ["plan", "build"],
  "headless_phases": [],
  "init_args": [
    { "name": "src-dir", "flag": "--src-dir", "description": "Source directory", "default": "src", "required": false },
    { "name": "goal", "flag": "--goal", "description": "Project goal for PROMPT_plan.md", "required": false }
  ],
  "default_model": "opus",
  "prompt_map": { "plan": "PROMPT_plan.md", "build": "PROMPT_build.md" },
  "manifest_template": null
}
```

### Port recipe.json

```json
{
  "name": "port",
  "description": "Extract behavioral specs from an existing codebase, then port to target language.",
  "version": "1.0.0",
  "phases": ["extract-tests", "extract-src", "plan", "build", "audit"],
  "loop_phases": ["plan", "build"],
  "headless_phases": ["extract-tests", "extract-src"],
  "init_args": [
    { "name": "source-lang", "positional": 0, "description": "Source language (e.g. dart, rust)", "required": true },
    { "name": "target-lang", "positional": 1, "description": "Target language (e.g. typescript, python)", "required": true }
  ],
  "default_model": "haiku",
  "prompt_map": {
    "extract-tests": "PROMPT_extract_tests.md",
    "extract-src": "PROMPT_extract_src.md",
    "plan": "PROMPT_port.md",
    "build": "PROMPT_port.md"
  },
  "manifest_template": "manifest-template.json"
}
```

### What a Recipe Must Provide

| Artifact | Location | Required |
|----------|----------|----------|
| `recipe.json` | `recipes/<name>/recipe.json` | Yes |
| PROMPT templates | `recipes/<name>/templates/PROMPT_*.md` | Yes (one per loop phase) |
| `AGENTS.md` template | `recipes/<name>/templates/AGENTS.md` | Yes |
| `manifest-template.json` | `recipes/<name>/templates/` | Only if `manifest_template` is set |
| Agents | `recipes/<name>/agents/*.md` | No |
| References | `recipes/<name>/references/*.md` | No |

### Custom Recipe Discovery

User recipes at `~/.claude/ralph-recipes/<name>/`. `init.sh` checks built-in `recipes/` first, then user paths. This is the extensibility hook for future `refactor`, `migrate-framework`, `test-backfill` recipes.

---

## 5. Universal Manifest (ralph/manifest.json)

Every `/ralph init` creates `ralph/manifest.json`. The `"recipe"` field enables recipe-aware status rendering. The manifest generalizes repo-clone's v2.0.0 format.

### Greenfield Manifest (minimal)

```json
{
  "version": "3.0.0",
  "recipe": "greenfield",
  "src_dir": "src",
  "goal": "[project-specific goal]",
  "default_model": "opus",
  "created": "YYYY-MM-DD",
  "phases": {
    "plan": { "status": "pending" },
    "build": { "status": "pending" }
  }
}
```

No file-level tracking — greenfield specs are human-written. The manifest exists for status display and recipe identification.

### Port Manifest

```json
{
  "version": "3.0.0",
  "recipe": "port",
  "source_lang": "dart",
  "target_lang": "typescript",
  "source_root": "lib",
  "target_root": "src-ts",
  "test_command": "npm test",
  "build_command": "npm run build",
  "default_model": "haiku",
  "created": "YYYY-MM-DD",
  "phases": {
    "extract-tests": { "status": "pending", "files": {} },
    "extract-src":   { "status": "pending", "files": {} },
    "plan":          { "status": "pending" },
    "build":         { "status": "pending" },
    "audit":         { "status": "pending" }
  }
}
```

This is repo-clone's existing format with `"recipe": "port"` and `"version": "3.0.0"` added. Per-file tracking is unchanged.

### Manifest Location Change

Old: `porting/manifest.json` (repo-clone)
New: `ralph/manifest.json` (all recipes)

Supporting files move: `porting/PORT_STATE.md` → `ralph/PORT_STATE.md`, `porting/SEMANTIC_MISMATCHES.md` → `ralph/SEMANTIC_MISMATCHES.md`. The `specs/` directory stays at project root.

---

## 6. Shared State File Conventions

| File | Purpose | Created by | Recipe |
|------|---------|-----------|--------|
| `ralph/manifest.json` | Universal progress tracker | `/ralph init` | All |
| `AGENTS.md` | Operational guide (~60 lines) | `/ralph init` | All |
| `IMPLEMENTATION_PLAN.md` | Shared state between loop iterations | Planning loop | All |
| `specs/` | Source of truth for requirements | User or extraction loops | All |
| `specs/tests/` | Extracted test behavioral specs | Extraction loop | Port |
| `specs/src/` | Extracted source behavioral specs | Extraction loop | Port |
| `PROMPT_plan.md` | Planning loop prompt | `/ralph init` | Greenfield |
| `PROMPT_build.md` | Build loop prompt | `/ralph init` | Greenfield |
| `PROMPT_extract_tests.md` | Test extraction prompt | `/ralph init --recipe port` | Port |
| `PROMPT_extract_src.md` | Source extraction prompt | `/ralph init --recipe port` | Port |
| `PROMPT_port.md` | Port plan + build prompt | `/ralph init --recipe port` | Port |
| `ralph/PORT_STATE.md` | Human-readable manifest view | `/ralph status` | Port |
| `ralph/SEMANTIC_MISMATCHES.md` | Known language divergences | `/ralph init --recipe port` | Port |
| `loop.sh` | External loop runner | `/ralph init` | All |
| `.claude/ralph-wiggum.local.md` | In-session loop state | `setup-loop.sh` | All |

The `.claude/ralph-wiggum.local.md` filename is preserved for backward compatibility. Renaming to `.claude/ralph.local.md` is deferred to v2.0.0.

---

## 7. Loop Mechanism Availability

| Phase | In-Session (`/ralph plan`, `/ralph build`) | External (`./loop.sh` or `while :; do ... done`) |
|-------|------------------------------------------|------------------------------------------------|
| greenfield: plan | Yes | Yes |
| greenfield: build | Yes | Yes |
| port: extract-tests | No (headless only) | Yes — `while :; do cat PROMPT_extract_tests.md \| claude -p --model haiku --dangerously-skip-permissions; sleep 5; done` |
| port: extract-src | No (headless only) | Yes — same pattern |
| port: plan | Yes | Yes |
| port: build | Yes | Yes |
| port: audit | No (interactive review) | No |

Extraction phases are headless-only because they use Haiku for throughput, are file-parallel (one file per iteration), and the stop hook adds no value for stateless single-file processing. The `loop.sh` scaffolded for port projects includes the extraction commands in its help text for reference.

---

## 8. Data Flow

### Greenfield Recipe

```
/ralph init [--recipe greenfield] [--src-dir app] [--goal "build X"]
  core/scripts/init.sh --recipe greenfield
    Creates: specs/, ralph/, ralph/manifest.json
    Creates: AGENTS.md, IMPLEMENTATION_PLAN.md (empty)
    Copies:  PROMPT_plan.md, PROMPT_build.md, PROMPT_plan_work.md
    Copies:  core/scripts/loop.sh -> ./loop.sh (chmod +x)

/ralph spec [topic]
  commands/spec.md — interactive JTBD session
    Writes: specs/TOPIC.md (user-driven, no loop)

/ralph plan [--max-iterations 3]
  commands/ralph.md reads ralph/manifest.json -> recipe=greenfield
  core/scripts/setup-loop.sh --mode plan
    Reads:  PROMPT_plan.md
    Writes: .claude/ralph-wiggum.local.md
    Loop:   reads specs/*, writes IMPLEMENTATION_PLAN.md

/ralph build [--completion-promise "all tests pass"]
  commands/ralph.md reads ralph/manifest.json -> recipe=greenfield
  core/scripts/setup-loop.sh --mode build
    Loop:   reads specs/*, IMPLEMENTATION_PLAN.md
            implements -> tests -> commits -> updates plan
```

### Port Recipe

```
/ralph init --recipe port dart typescript
  core/scripts/init.sh --recipe port dart typescript
    Scans source repo, categorizes files (test/source/config/asset/doc)
    Creates: specs/tests/, specs/src/, ralph/, ralph/manifest.json
    Writes:  AGENTS.md (with {SOURCE_LANG}/{TARGET_LANG} etc substitutions)
    Creates: ralph/SEMANTIC_MISMATCHES.md (from semantic-mappings.md for dart-ts)
    Creates: ralph/PORT_STATE.md (initial human-readable view)
    Copies:  PROMPT_extract_tests.md, PROMPT_extract_src.md, PROMPT_port.md
    Creates: IMPLEMENTATION_PLAN.md (empty)
    Copies:  core/scripts/loop.sh -> ./loop.sh (chmod +x)

[External — no in-session command for extraction]
while :; do
  cat PROMPT_extract_tests.md | claude -p --model haiku --dangerously-skip-permissions
  sleep 5
done
  Each iteration: reads ralph/manifest.json -> next pending test file
                  extracts behavioral spec
                  writes specs/tests/{basename}_spec.md with [test:file:line] citations
                  updates manifest (file.status = "done")
                  commits

while :; do cat PROMPT_extract_src.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done
  Same pattern -> specs/src/{basename}_spec.md with [source:file:line] citations

/ralph plan [--max-iterations 2]
  commands/ralph.md reads ralph/manifest.json -> recipe=port
  core/scripts/setup-loop.sh --mode plan --prompt-file PROMPT_port.md
    Loop:   reads specs/*, writes IMPLEMENTATION_PLAN.md

/ralph build
  commands/ralph.md reads ralph/manifest.json -> recipe=port
  core/scripts/setup-loop.sh --mode build --prompt-file PROMPT_port.md
    Loop:   reads specs/*, IMPLEMENTATION_PLAN.md, follows citations to source
            implements idiomatically in target lang
            runs target test command
            commits on green

/ralph status
  commands/ralph.md reads ralph/manifest.json
    Renders phase table with per-file progress counts for extract phases
    Shows next action recommendation based on phase statuses
    Regenerates ralph/PORT_STATE.md
```

---

## 9. Migration Path

### Existing ralph-wiggum Users

1. Install `ralph-wiggum-toolkit` — coexists with `ralph-wiggum`
2. No project file migration required: greenfield recipe uses identical files (`specs/`, `AGENTS.md`, `IMPLEMENTATION_PLAN.md`, `PROMPT_plan.md`, `PROMPT_build.md`, `loop.sh`)
3. Run `/ralph status` in any existing ralph-wiggum project. The command detects no `ralph/manifest.json` but finds ralph-wiggum files and synthesizes status from file presence
4. Workflow change: use `/ralph plan` and `/ralph build` instead of `/ralph-wiggum:plan` and `/ralph-wiggum:build`
5. After 30 days: mark `ralph-wiggum` deprecated in marketplace.json

### Existing repo-clone Users

1. Install `ralph-wiggum-toolkit` — coexists with `repo-clone`
2. Run `/ralph status` in any existing repo-clone project
3. Command detects `porting/manifest.json` and shows: "Found porting/manifest.json from repo-clone v2. Migrate to ralph/manifest.json? [y/N]"
4. Migration: adds `"recipe": "port"` + `"version": "3.0.0"` to manifest; moves `porting/manifest.json` → `ralph/manifest.json`; moves `porting/PORT_STATE.md` → `ralph/PORT_STATE.md`; moves `porting/SEMANTIC_MISMATCHES.md` → `ralph/SEMANTIC_MISMATCHES.md`
5. In-progress ports continue immediately — all PROMPT files and specs are untouched
6. Workflow change: use `/ralph status` instead of `/repo-clone status`
7. After 30 days: mark `repo-clone` deprecated in marketplace.json

### Backward Compatibility Guarantees

- `IMPLEMENTATION_PLAN.md`, `AGENTS.md`, `specs/`, `loop.sh` are content-identical between old and new. No content migration.
- `.claude/ralph-wiggum.local.md` state file name is preserved. Active loops continue working.
- `porting/manifest.json` is detected as a legacy location. Manual migration is offered, not forced.

---

## 10. Implementation Phases (Build Sequence)

### Phase 1: Scaffold and Copy (no logic changes)

- [ ] Create `ralph-wiggum-toolkit/` directory structure
- [ ] Write `plugin.json`
- [ ] Copy `core/hooks/stop-hook.sh` from ralph-wiggum (chmod +x)
- [ ] Write `core/hooks/hooks.json` (update CLAUDE_PLUGIN_ROOT path: `${CLAUDE_PLUGIN_ROOT}/hooks/stop-hook.sh` but CLAUDE_PLUGIN_ROOT now points to `ralph-wiggum-toolkit/` root)
- [ ] Copy `recipes/greenfield/templates/` from `ralph-wiggum/references/templates/`
- [ ] Copy `recipes/greenfield/references/methodology.md` from `ralph-wiggum/references/methodology.md`
- [ ] Write `recipes/greenfield/recipe.json`
- [ ] Copy `recipes/port/templates/` from `repo-clone/data/templates/` (rename AGENTS_port.md to AGENTS.md)
- [ ] Update `recipes/port/templates/manifest-template.json`: add `"recipe": "port"` and `"version": "3.0.0"` at top level
- [ ] Copy `recipes/port/agents/` from `repo-clone/agents/`
- [ ] Copy `recipes/port/references/` from `repo-clone/references/`
- [ ] Write `recipes/port/recipe.json`
- [ ] Copy `commands/spec.md` from `ralph-wiggum/commands/spec.md` (update `/ralph-wiggum:spec` references to `/ralph spec`)

### Phase 2: Core Scripts

- [ ] Write `core/scripts/init.sh`:
  - Parse `--recipe` flag (default: `greenfield`)
  - Validate recipe against `recipes/` and `~/.claude/ralph-recipes/`
  - `init_greenfield`: replicate `ralph-wiggum/scripts/init-project.sh` using `recipes/greenfield/templates/`; write `ralph/manifest.json`
  - `init_port`: replicate repo-clone init logic from `repo-clone/commands/repo-clone.md` sections 1-8; write `ralph/manifest.json`; use `ralph/` instead of `porting/` for state files
  - Both paths: copy `core/scripts/loop.sh` → `./loop.sh` in project root; chmod +x
- [ ] Copy + modify `core/scripts/setup-loop.sh`:
  - Add `--prompt-file` flag parsing (before mode validation)
  - After mode-to-PROMPT_FILE mapping, apply override if provided
  - Validate override file exists
- [ ] Copy + modify `core/scripts/loop.sh`:
  - After argument parsing, add: read `ralph/manifest.json` with shell grep/sed for `default_model`; assign to `CLAUDE_MODEL` variable (fallback: `opus`)
  - Replace hardcoded `--model opus` with `--model "$CLAUDE_MODEL"` in `claude -p` invocation
- [ ] Make all three scripts executable

### Phase 3: Commands

- [ ] Write `commands/ralph.md`:
  - Argument: `$ARGUMENTS` parsed for first word as subcommand
  - `init`: parse `--recipe` from remaining args; run `${CLAUDE_PLUGIN_ROOT}/core/scripts/init.sh $ARGUMENTS`
  - Recipe detection helper: read `ralph/manifest.json` if present; check `"recipe"` field; fall back to legacy detection (porting/manifest.json, then file-presence heuristic)
  - `plan`: detect recipe; build setup-loop.sh invocation with `--prompt-file PROMPT_port.md` if port, standard otherwise
  - `build`: same pattern as plan
  - `status`: detect recipe; render manifest-based phase table; for port recipe: per-file progress counts; legacy migration offer for porting/ path
  - `cancel`: read + delete `.claude/ralph-wiggum.local.md`; report mode and iteration
  - `help`: direct to `commands/help.md` content
- [ ] Write `commands/help.md`:
  - Merged from `ralph-wiggum/commands/help.md` and `repo-clone/commands/help.md`
  - Add recipe concept overview
  - Greenfield section: three phases, commands, files
  - Port section: five phases, extraction loop commands, manifest, citation format
  - Shared concepts: Geoffrey's methodology, stop hook vs external loop, backpressure
  - Adding custom recipes: `~/.claude/ralph-recipes/` convention

### Phase 4: Skills and Marketplace

- [ ] Write `skills/ralph/SKILL.md`:
  - Merged trigger phrases: "port to", "clone to", "migrate to", "translate to", "rewrite in", "convert from X to Y", "spec-driven", "ralph loop", "build feature", "autonomous dev"
  - Quick start for greenfield and port recipes
- [ ] Update `.claude-plugin/marketplace.json`:
  - Add entry for `ralph-wiggum-toolkit` with `"source": "./ralph-wiggum-toolkit"`, `"version": "1.0.0"`, full description
  - Add to `ralph-wiggum`: `"deprecated": true`, `"deprecation_message": "Replaced by ralph-wiggum-toolkit. See /ralph help."`
  - Add to `repo-clone`: same deprecation fields

### Phase 5: Validation

- [ ] Greenfield smoke test: `/ralph init` in `/tmp/test-greenfield`; verify `ralph/manifest.json` created, `PROMPT_plan.md` + `PROMPT_build.md` present, `loop.sh` executable
- [ ] Greenfield loop test: `/ralph plan --max-iterations 2` with a trivial spec; verify stop hook triggers iteration 2
- [ ] Port smoke test: `/ralph init --recipe port dart typescript` in `/tmp/test-port` with sample dart files; verify manifest populated with file entries, `AGENTS.md` has language substitutions, `ralph/SEMANTIC_MISMATCHES.md` created
- [ ] Port model test: `cat PROMPT_port.md | bash -c 'source core/scripts/loop.sh; echo $CLAUDE_MODEL'` equivalent; verify haiku read from manifest
- [ ] Legacy ralph-wiggum test: `/ralph status` in a directory with only `specs/` and `AGENTS.md`; verify status synthesized without error
- [ ] Legacy repo-clone test: `/ralph status` in a directory with `porting/manifest.json`; verify migration offer appears
- [ ] Recipe validation test: `/ralph init --recipe nonexistent`; verify error lists available recipes
- [ ] Custom recipe test: create `~/.claude/ralph-recipes/test-recipe/recipe.json`; verify `/ralph init --recipe test-recipe` finds it

---

## 11. Critical Details

### setup-loop.sh: --prompt-file Change (exact location)

In `ralph-wiggum/scripts/setup-loop.sh` at line 44 (after the `--work-scope` case), add before the `*)` fallthrough:

```bash
    --prompt-file)
      if [[ -z "${2:-}" ]] || [[ "${2:-}" == -* ]]; then
        echo "Error: --prompt-file requires a path" >&2
        exit 1
      fi
      PROMPT_FILE_OVERRIDE="$2"
      shift 2
      ;;
```

At line 87 (after the `case "$MODE" in` block), add:

```bash
if [[ -n "${PROMPT_FILE_OVERRIDE:-}" ]]; then
  PROMPT_FILE="$PROMPT_FILE_OVERRIDE"
fi
```

Then add to the `--help` text: `--prompt-file <path>   Override PROMPT file (e.g. PROMPT_port.md)`

### loop.sh: Model Reading (shell-only, no python3)

Add after argument parsing (before `ITERATION=0`):

```bash
# Read model from ralph/manifest.json if present (shell-only JSON parsing)
CLAUDE_MODEL="opus"
if [[ -f "ralph/manifest.json" ]]; then
  MANIFEST_MODEL=$(grep '"default_model"' ralph/manifest.json \
    | sed 's/.*"default_model"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' \
    | head -1)
  [[ -n "$MANIFEST_MODEL" ]] && CLAUDE_MODEL="$MANIFEST_MODEL"
fi
```

Replace `--model opus` with `--model "$CLAUDE_MODEL"` in both `claude -p` invocations (plan-work mode and default mode).

### commands/ralph.md: Recipe Detection Logic

The detection logic (read in `commands/ralph.md` before any dispatch):

1. If `ralph/manifest.json` exists: read `"recipe"` field with `grep + sed` or as part of the Read tool call
2. Else if `porting/manifest.json` exists: treat as `recipe=port` (legacy)
3. Else if `PROMPT_plan.md` and `PROMPT_build.md` exist in project root: treat as `recipe=greenfield` (initialized without toolkit)
4. Else: uninitialized project — show init instructions

The state file `.claude/ralph-wiggum.local.md` is never renamed. The stop hook reads it by name and has zero recipe awareness — this is its virtue.

### init.sh: Port Init Mirrors repo-clone/commands/repo-clone.md

The port init logic in `init.sh` replicates the repo-clone.md init steps 1-9 exactly. The only changes:
- Templates read from `$RECIPE_DIR/templates/` instead of plugin data directory
- State files written to `ralph/` instead of `porting/`
- Manifest written as `ralph/manifest.json` with added `"recipe"` and `"version"` fields

No simplification — preserve all existing port init behavior (language detection table, file categorization patterns, AGENTS.md substitution, SEMANTIC_MISMATCHES.md extraction).

---

## 12. Open Questions (Deferred)

**Q1: State file rename.** `.claude/ralph-wiggum.local.md` → `.claude/ralph.local.md`?
Defer to v2.0.0. Rename breaks active loops. Detect both names as v2.0.0 migration.

**Q2: plan-work mode for port recipe.** Greenfield has `plan-work "scope"` for feature branches. Port equivalent: porting a single module.
Defer to v1.1.0. Add `--scope <module>` to `/ralph plan` in port context.

**Q3: Deprecation timeline for old plugins.**
Deprecate in marketplace at toolkit v1.0.0 (still install, show notice). Remove from marketplace at toolkit v2.0.0 (30+ days after v1.0.0 release).

**Q4: Recipe versioning.** Should recipe.json have a schema version for future compatibility?
Include `"version"` field in recipe.json from the start (already in the schema above). No enforcement needed in v1.0.0.

---

*End of spec. Implement in the order given by Phase 1 through Phase 5.*
