# Skills & Plugins Registry

Portable reference for George's Claude Code coding setup. Skill folders under this directory are vendored copies of skills authored by me. The rest is a registry of external skills and plugins I use, with install sources so this setup can be reconstructed on a fresh machine.

## Skills authored by me (vendored here)

| Skill | Trigger / Scope | Upstream |
|---|---|---|
| [`graphite-atomic/`](./graphite-atomic/) | Atomic commits + stacked PRs via `gt`. Active only in repos with `.graphite_repo_config`. | `~/.claude/skills/graphite-atomic/` |
| [`jj-vcs-comprehensive/`](./jj-vcs-comprehensive/) | Jujutsu (jj) VCS — colocated workspaces, bookmarks, GitHub sync, conflict resolution. | `~/.claude/skills/jj-vcs-comprehensive/` |

These are committed into the repo so the canonical source is versioned. To update, edit in place here and copy out to `~/.claude/skills/<name>/` (or symlink during local dev).

## External skills I use

Installed directly under `~/.claude/skills/` (not via a plugin). Source/install notes:

| Skill | Purpose | Source |
|---|---|---|
| `firecrawl`, `firecrawl-scrape`, `firecrawl-search`, `firecrawl-map`, `firecrawl-crawl`, `firecrawl-agent`, `firecrawl-interact`, `firecrawl-download` | Web scraping / search / crawl via Firecrawl CLI | Firecrawl (likely `skills.sh` or Firecrawl docs) |
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

1. Install Claude Code CLI.
2. Add the marketplaces listed above (`/plugin marketplace add <repo>`).
3. Install plugins from each marketplace.
4. Copy the vendored skills here into `~/.claude/skills/`:

   ```bash
   cp -r .claude/skills/graphite-atomic ~/.claude/skills/
   cp -r .claude/skills/jj-vcs-comprehensive ~/.claude/skills/
   ```

5. Reinstall any standalone `~/.claude/skills/` entries from the External skills table above (most likely via `skills.sh` or their upstream docs).

## Notes

- `.claude/skills/` is auto-loaded by Claude Code when working in this repo, so vendored skills are live here as well as backed up.
- Source of truth for skill authorship: the `SKILL.md` frontmatter does not reliably carry an author field — I'm using habit/setup patterns to classify. When in doubt, confirm authorship before vendoring.
