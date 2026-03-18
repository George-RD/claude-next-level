---
description: "Full methodology guide for Ralph Wiggum Toolkit"
---

# Ralph Wiggum Toolkit — Full Guide

## What is Ralph Wiggum Toolkit?

Ralph Wiggum Toolkit implements Geoffrey Huntley's spec-driven autonomous development methodology with a **recipe-based architecture**. A bash loop feeds the same prompt to Claude repeatedly — each iteration gets a fresh context window but sees its previous work through files on disk.

```bash
while :; do cat PROMPT.md | claude -p; done
```

The toolkit supports multiple **recipes** — each recipe defines what gets scaffolded, which prompts exist, and how many phases there are. Two built-in recipes ship with v1.0.0:

## Greenfield Recipe

For new features and greenfield projects. Three phases:

| Phase | Command | What happens |
|-------|---------|-------------|
| 1. Define | `/ralph spec` | Interactive JTBD analysis, write `specs/*.md` |
| 2. Plan | `/ralph plan` | Gap analysis between specs and code, create `IMPLEMENTATION_PLAN.md` |
| 3. Build | `/ralph build` | Implement one task per iteration: investigate, build, test, commit |

## Port Recipe

For porting existing codebases to a new language. Five phases:

| Phase | Command | What happens |
|-------|---------|-------------|
| 1. Extract Tests | Headless loop | Extract behavioral specs from test files with citations |
| 2. Extract Source | Headless loop | Extract behavioral specs from source files with citations |
| 3. Plan | `/ralph plan` | Synthesize implementation plan from all specs |
| 4. Build | `/ralph build` | Port one task per iteration, following citations |
| 5. Audit | Interactive | Parity check between source and ported code |

### Running Extraction Loops (Port Recipe)

Extraction phases are headless-only — they use Haiku for throughput:

```bash
# Extract test specs
while :; do cat PROMPT_extract_tests.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done

# Extract source specs
while :; do cat PROMPT_extract_src.md | claude -p --model haiku --dangerously-skip-permissions; sleep 5; done
```

**Safety:** `--dangerously-skip-permissions` bypasses all tool approval. Run only in sandboxed environments.

### Citations

The citation format `[source:path/file.ext:start-end]` is what makes port recipe work:

1. Extraction reads source code and writes specs with citations
2. Porting reads specs, then follows each citation back to the original source
3. This prevents "spec drift" where the agent invents behavior not in the source

## All Commands

| Command | Description |
|---------|-------------|
| `/ralph init [--recipe <name>]` | Initialize project with chosen recipe |
| `/ralph spec [topic]` | Phase 1: Define JTBD requirements (greenfield) |
| `/ralph plan [options]` | Run planning loop |
| `/ralph build [options]` | Run build loop |
| `/ralph status` | Show current project state |
| `/ralph cancel` | Cancel an active loop |
| `/ralph help` | This help message |

## In-Session vs External Loop

**In-session** (commands above): Runs within your current Claude Code session using stop hooks. Good for interactive development where you want to observe and steer.

**External** (`loop.sh`): Runs `claude -p` in a bash while-true loop. Fully autonomous, fire-and-forget.

```bash
./loop.sh              # Build mode, unlimited
./loop.sh 20           # Build mode, max 20 iterations
./loop.sh plan         # Plan mode
./loop.sh plan 5       # Plan mode, max 5 iterations
```

## Key Files

| File | Purpose |
|------|---------|
| `ralph/manifest.json` | Universal progress tracker (recipe, phases, per-file status) |
| `specs/*.md` | Source of truth for requirements |
| `AGENTS.md` | Operational guide: build/test/lint commands (~60 lines) |
| `IMPLEMENTATION_PLAN.md` | Prioritized task list (shared state between iterations) |
| `PROMPT_*.md` | Mode-specific loop instructions |
| `loop.sh` | External autonomous loop runner |

## Custom Recipes

Place a recipe at `~/.claude/ralph-recipes/<name>/` with:

- `recipe.json` — recipe contract (phases, args, prompt map)
- `templates/AGENTS.md` — operational guide template
- `templates/PROMPT_*.md` — one per loop phase

## Expectations

- **Best for greenfield projects.** Existing codebases with legacy patterns are harder to steer.
- **Expect ~90% completion.** Plan for human review and polish on the final stretch.

## Learn More

- Original technique: <https://ghuntley.com/ralph/>
- Playbook reference: <https://github.com/ghuntley/how-to-ralph-wiggum>
