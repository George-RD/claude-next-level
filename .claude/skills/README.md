# Skills & Plugins Registry

Portable reference for George's Claude Code coding setup. Skill folders under this directory are vendored copies of skills authored by me. The rest is a registry of external skills and plugins I use, with install sources so this setup can be reconstructed on a fresh machine.

## Where skills live (cross-tool layout)

Three search roots:

| Tool | Discovery |
|---|---|
| **Claude Code** | auto-scans `~/.claude/skills/` (global) and `<project>/.claude/skills/` (project-scoped). |
| **Codex** | explicit `[[skills.config]]` blocks in `~/.codex/config.toml` — no auto-scan. |
| **Shared canonical** | `~/.agents/skills/` — single source for skills used by **both** tools. |

For cross-tool skills: canonical lives at `~/.agents/skills/<name>/`; Claude reads it via a symlink at `~/.claude/skills/<name>`, Codex via a `[[skills.config]]` block pointing at the absolute `SKILL.md` path. Edit once, both tools update.

Currently shared: `firecrawl` (+ `firecrawl-*`), `graphite-pr`. Everything else is Claude-only at `~/.claude/skills/`.

Skills I author are vendored into this repo as the versioned source; the runtime canonical is what the tools actually load. See "Rebuilding this setup" below for the wiring steps.

## Skills authored by me (vendored here)

| Skill | Trigger / Scope | Runtime canonical | Sharing |
|---|---|---|---|
| [`graphite-pr/`](./graphite-pr/) | Stacked PRs via `gt` — daily commit→submit→review→merge loop. Active in `.graphite_repo_config` repos or on `gt`/stacked-PR cues. Renamed from `graphite-atomic` Apr 2026. | `~/.agents/skills/graphite-pr/` | **shared** (Claude via symlink, Codex via `config.toml` entry) |
| [`jj-vcs-comprehensive/`](./jj-vcs-comprehensive/) | Jujutsu (jj) VCS — colocated workspaces, bookmarks, GitHub sync, conflict resolution. | `~/.claude/skills/jj-vcs-comprehensive/` | Claude only |

**Update discipline**: edit the vendored copy here first (so the change is committed), then mirror to the runtime canonical:

```bash
cp -r .claude/skills/<name>/ ~/.agents/skills/<name>/   # shared skills
cp -r .claude/skills/<name>/ ~/.claude/skills/<name>/   # Claude-only skills
```

For shared skills the single mirror reaches both tools.

## External skills I use

Installed directly under `~/.claude/skills/` (not via a plugin). Source/install notes:

| Skill | Purpose | Source |
|---|---|---|
| `firecrawl`, `firecrawl-scrape`, `firecrawl-search`, `firecrawl-map`, `firecrawl-crawl`, `firecrawl-agent`, `firecrawl-interact`, `firecrawl-download` | Web scraping / search / crawl via Firecrawl CLI. Shared (canonical at `~/.agents/skills/firecrawl*`). | Firecrawl (likely `skills.sh` or Firecrawl docs) |
| `nlm-skill` | NotebookLM CLI + MCP (`nlm`) | NotebookLM MCP package |
| `sketch-implement-design` | Translate Sketch layers → code via Sketch MCP | Sketch MCP server |
| `cmux-theme` | cmux terminal multiplexer | cmux.app distribution |
| `forgecad` | ForgeCAD geometry authoring | ForgeCAD project |
| `create-bbb` | `.bbb` brand files | External — bundled with brand tooling |
| `openspec-conflux-init`, `openspec-archiving` | OpenSpec / Conflux (`cflx`) change proposals | OpenSpec tooling |
| `remotion-best-practices` | Remotion video | Remotion docs |
| `ms-office-suite` | Word / PDF / PowerPoint manipulation | Generic Office skill |
| `sql-server-maintenance` | SQL Server DBA ops | Generic SQL Server skill |
| `copywriting` | Marketing copy | Generic |
| `frontend-design` | Also ships via `frontend-design@claude-plugins-official` plugin — standalone skill copy here. | anthropics plugin |
| `find-skills` | Skill discovery/install | Anthropic built-in |
| `graphify` | Knowledge-graph builder (`/graphify`) | External (referenced in global `CLAUDE.md`) |
| `dg` | Dinesh vs Gilfoyle adversarial review (`/dg`) | External |
| `skill-creator` | Author / improve / eval skills. **Project-scoped here** (vendored under `.claude/skills/skill-creator/` instead of enabled globally) so it activates only when working in this repo. | Anthropic — `skill-creator@claude-plugins-official`, copied from `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/skill-creator/skills/skill-creator/` |

> **TODO**: backfill exact install command / source URL for each row. Some likely came from `skills.sh` — if I can find the install command history, I'll pin it here.

## Plugin marketplaces

From `~/.claude/plugins/known_marketplaces.json`:

### Mine (George-RD)

| Marketplace | Source | Notes |
|---|---|---|
| `claude-next-level` | [`github:George-RD/claude-next-level`](https://github.com/George-RD/claude-next-level) | This repo. |
| `reaveshq-claude-plugins` | `git:https://github.com/George-RD/reaveshq-claude-plugins.git` | Reaves HQ plugins. |
| `mordor-forge` | `git:https://github.com/George-RD/mordor-forge.git` | ide-of-sauron et al. |
| `mag-plugins` | [`github:George-RD/mag-plugins`](https://github.com/George-RD/mag-plugins) | MAG memory plugin. |
| `my-claude-plugins` | `directory:~/.claude/plugins/marketplaces/my-claude-plugins` | Local-only marketplace. |
| `my_local_plugins` | (local, referenced in `installed_plugins.json`) | Earlier alias; some overlap with `my-claude-plugins`. |

### Third-party

| Marketplace | Source |
|---|---|
| `claude-plugins-official` | [`github:anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) |
| `axiom-marketplace` | [`github:CharlesWiltgen/Axiom`](https://github.com/CharlesWiltgen/Axiom) |
| `supabase-agent-skills` | [`github:supabase/agent-skills`](https://github.com/supabase/agent-skills) |
| `cli-anything` | [`github:HKUDS/CLI-Anything`](https://github.com/HKUDS/CLI-Anything) |
| `verygoodplugins-mcp-automem` | `git:https://github.com/verygoodplugins/mcp-automem.git` |
| `openai-codex` | `git:https://github.com/openai/codex-plugin-cc.git` |
| `claude-code-workflows` | (see `installed_plugins.json` — used for agent-orchestration, debugging-toolkit, unit-testing, etc.) |

## Installed plugins

Grouped by source marketplace. Scope is `user` unless noted. Install via `/plugin install <name>@<marketplace>`.

### From `claude-next-level` (mine, this repo)

- `grandslam-offer@claude-next-level` v1.0.0
- `hundred-million-leads@claude-next-level` v1.0.0
- `cycle@claude-next-level` v2.0.0
- `jj-commands@claude-next-level` v1.0.0
- `ralph-wiggum-toolkit@claude-next-level` v2.0.0

### From `mordor-forge` (mine)

- `ide-of-sauron@mordor-forge` v2.0.4

### From `reaveshq-claude-plugins` (mine)

- `brand-toolkit` v2.0.0
- `excalidraw-generation` v1.0.0
- `latex-handouts` v1.0.0
- `playwright-cli` v1.0.0
- `revealjs` v1.0.0
- `slidev` v1.0.0
- `frontend-harness` v1.2.0

### From `mag-plugins` (mine)

- `mag@mag-plugins` v0.1.1

### From `my-claude-plugins` / `my_local_plugins` (local)

- `arch-patterns` v1.0.1
- `research-framework` v1.0.0
- `fugro-investigation` v1.0.0
- `automem-helper` v1.0.0

### From `claude-plugins-official` (Anthropic)

- `context7`, `frontend-design`, `feature-dev`, `code-review`, `commit-commands`
- `pr-review-toolkit`, `playwright`, `ralph-wiggum` (deprecated in favour of ralph-wiggum-toolkit)
- `serena`, `rust-analyzer-lsp`, `typescript-lsp`, `swift-lsp` (project-scoped)
- `greptile`, `hookify`, `superpowers`, `code-simplifier`
- `claude-code-setup`, `claude-md-management`, `skill-creator`
- `supabase`, `github` (project-scoped), `security-guidance` (project-scoped)
- `circleback`, `plugin-dev`, `coderabbit`, `linear`, `posthog` (project-scoped)
- `huggingface-skills` (project-scoped), `fakechat`, `vercel`, `telegram`

### From `claude-code-workflows`

- `agent-orchestration` v1.2.0 (project-scoped)
- `multi-platform-apps` v1.2.1
- `error-debugging` v1.2.0, `unit-testing` v1.2.0
- `debugging-toolkit` v1.2.0, `error-diagnostics` v1.2.0
- `ralph-loop@claude-plugins-official` (separate project install)

### From other sources

- `axiom@axiom-marketplace` v3.0.3 (project-scoped, yarnling-ios)
- `postgres-best-practices@supabase-agent-skills` (project-scoped)
- `cli-anything@cli-anything`
- `automem@verygoodplugins-mcp-automem` v0.13.0
- `codex@openai-codex` v1.0.2

## Rebuilding this setup on a fresh machine

1. Install Claude Code CLI (and Codex CLI if dual-tool setup).
2. Add the marketplaces listed above (`/plugin marketplace add <repo>`).
3. Install plugins from each marketplace.
4. Restore vendored skills (run from the cloned repo root):

   ```bash
   # Ensure target dirs exist (fresh installs may not have them).
   mkdir -p ~/.agents/skills ~/.claude/skills

   # Shared (used by both Claude and Codex) — canonical lives in ~/.agents/skills/.
   cp -r .claude/skills/graphite-pr ~/.agents/skills/
   ln -sfn "$HOME/.agents/skills/graphite-pr" "$HOME/.claude/skills/graphite-pr"

   # Claude-only — copy straight into ~/.claude/skills/.
   cp -r .claude/skills/jj-vcs-comprehensive ~/.claude/skills/
   ```

5. Wire shared skills into Codex. Back up first, then append (Codex has no auto-scan; every shared skill needs its own block):

   ```bash
   mkdir -p ~/.codex
   touch ~/.codex/config.toml
   cp ~/.codex/config.toml ~/.codex/config.toml.bak.$(date +%s)

   # Idempotent append — only adds the block if this skill's path isn't already registered.
   SKILL_PATH="$HOME/.agents/skills/graphite-pr/SKILL.md"
   grep -qF "$SKILL_PATH" ~/.codex/config.toml || cat >> ~/.codex/config.toml <<EOF

   [[skills.config]]
   path = "$SKILL_PATH"
   enabled = true
   EOF
   ```

   Verify the file still parses: `python3 -c 'import tomllib; tomllib.load(open("'"$HOME"'/.codex/config.toml","rb"))'`.

6. Reinstall standalone entries from the External skills table (mostly via `skills.sh` or upstream docs). Shared external skills install into `~/.agents/skills/` and need both a Claude symlink and a Codex block per skill. For example, the firecrawl set is 8 SKILL.md files (`firecrawl`, `firecrawl-{agent,crawl,download,interact,map,scrape,search}`) — repeat the step-5 append once per skill, swapping the path.

## Notes

- `.claude/skills/` is auto-loaded by Claude Code when working in this repo, so vendored skills are live here as well as backed up.
- Source of truth for skill authorship: the `SKILL.md` frontmatter does not reliably carry an author field — I'm using habit/setup patterns to classify. When in doubt, confirm authorship before vendoring.
