# claude-next-level

Claude Code plugin marketplace: curated plugins for workflow discipline, business workshops, and PR automation.

## Structure

| Directory | Plugin | Description |
|-----------|--------|-------------|
| `ralph-wiggum-toolkit/` | ralph-wiggum-toolkit v1.0.0 | Recipe-based autonomous dev loops (greenfield + port recipes) |
| `next-level/` | next-level v0.3.0 | Workflow discipline: TDD enforcement, spec-driven dev, verification guards, linting |
| `grandslam-offer/` | grandslam-offer | $100M Offers workshop with adversarial agent teams |
| `hundred-million-leads/` | hundred-million-leads | $100M Leads workshop with adversarial agent teams |
| `pr-review-workflow/` | pr-review-workflow | Parallel PR review with agent teams |
| `ralph-wiggum/` | ralph-wiggum (deprecated) | Replaced by ralph-wiggum-toolkit greenfield recipe |
| `repo-clone/` | repo-clone (deprecated) | Replaced by ralph-wiggum-toolkit port recipe |

## Key Files

- `.claude-plugin/marketplace.json` — plugin registry (lists all plugins with versions)
- `next-level/plugin.json` — next-level plugin manifest
- `next-level/hooks/hooks.json` — hook definitions (TDD, linting, verification guards)
- `next-level/hooks/scripts/utils.sh` — shared hook utilities
- `next-level/lib/checkers/` — per-language AST checkers (Python, TS, Go, Rust, Swift)
- `docs/plans/` — design documents for future versions

## Development

- **No build step** — plugins are pure Markdown (skills, agents, rules) + shell/Python scripts
- **Testing hooks**: `next-level/hooks/scripts/test-*.sh` are test scripts for hooks
- **Commits**: conventional commits — `feat(scope):`, `fix(scope):`, etc.
- **Markdown linting**: `.markdownlint.json` disables MD013, MD024, MD033, MD036, MD060

## Gotchas

- Plugin scripts must be executable (`chmod +x`)
- Hook scripts in `next-level/hooks/scripts/` source `utils.sh` for shared functions
- `file_checker.py` imports from `next-level/lib/` — run from the hooks/scripts directory or ensure PYTHONPATH includes the lib dir
- The `next-level` plugin is the primary active development target; other plugins are stable
