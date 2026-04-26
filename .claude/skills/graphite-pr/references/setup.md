# Setting up Graphite in a new repo

Run this once per repository. Goal: minimal CLAUDE.md footprint, all the actual rules live in the `graphite-pr` skill.

## 1. Install the CLI

macOS:

```bash
brew install withgraphite/tap/graphite
```

Other platforms: <https://graphite.com/docs/install-the-cli>.

Verify ≥ 1.6.7 (MCP-support minimum):

```bash
gt --version
```

## 2. Initialise

From the repo root (not a worktree):

```bash
gt init --trunk <trunk-branch>   # use the actual trunk: main, dev, develop, etc.
gt trunk                          # confirm
```

This creates `.graphite_repo_config` inside the git common dir. The skill's activation check (`test -f "$(git rev-parse --git-common-dir)/.graphite_repo_config"`) now returns `OK` from the repo root or any worktree.

## 3. Authenticate

Browser OAuth — needs the human's hands:

```bash
gt auth
```

You can't pre-check auth status reliably. `gt submit --dry-run --no-interactive` reaches the API only when there's a stack to submit; on a clean trunk it short-circuits with "Nothing to submit!" and exits 0 without confirming auth. So either ask the user "have you run `gt auth` recently?", or just run it — repeated `gt auth` is harmless.

If OAuth fails: `gt auth --reset && gt auth`.

**Do not** fall back to `gt config set github_token <PAT>`. Plaintext PATs in `gt`'s config leak via backups, cloud sync, shell history. If OAuth is genuinely blocked, use a fine-grained PAT scoped to the single repo, store it in the OS keychain, rotate after the session.

## 4. Add the one-line pointer to CLAUDE.md

Append to the project's `CLAUDE.md` (create if missing). One line under whatever section makes sense (e.g. a "Tooling" or "Workflow" heading, or freestanding):

```markdown
- **Stacked PRs**: trunk is `<trunk>`. Use the `graphite-pr` skill — `gt` owns branch state, so commits and pushes go through `gt create` / `gt modify` / `gt submit`.
```

Substitute the actual trunk. That's it — don't paste the full ruleset into CLAUDE.md. The skill auto-loads from the `.graphite_repo_config` trigger and the CLAUDE.md mention; keeping CLAUDE.md tight leaves more context budget for the actual project. The "`gt` owns branch state" half-sentence is load-bearing — it gives the agent the structural reason to reach for `gt` even before the skill body loads.

## 5. Verify activation

From the repo root or any worktree:

```bash
test -f "$(git rev-parse --git-common-dir)/.graphite_repo_config" && echo OK
```

Prints `OK` when the skill will fire.

## 6. First test commit

```bash
echo "# graphite test" >> .graphite-test
git add .graphite-test
gt create -m "chore: initial graphite test"
gt log
```

If the branch appears in `gt log` rooted on the configured trunk, setup is complete. Delete the test branch when done: `gt delete <branch>`.

## Optional: protective PreToolUse hook

If agents in this project keep reaching for `git commit` / `git push` / `git checkout -b` when they should be using `gt`, add `.claude/hooks/graphite-pretool.sh` (fail-closed):

```bash
#!/usr/bin/env bash
set -u
fail_closed() {
  echo '{"decision":"block","reason":"graphite-pr hook could not verify the command. Failing closed. Use gt (create/modify/submit/delete)."}'
  exit 0
}
command -v jq >/dev/null 2>&1 || fail_closed
input=$(cat)
raw=$(printf '%s' "$input" | jq -r '.tool_input.command // empty') || fail_closed
[ -n "$raw" ] || { echo '{"decision":"allow"}'; exit 0; }

GIT_PREFIX='(^|[[:space:]]|/)git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?'

if printf '%s' "$raw" | grep -Eq "${GIT_PREFIX}(commit|push|rebase|merge)([[:space:]]|$)"; then
  echo '{"decision":"block","reason":"Use gt (create/modify/submit/sync) per graphite-pr skill."}'
  exit 0
fi
if printf '%s' "$raw" | grep -Eq "${GIT_PREFIX}branch[[:space:]]+(-D|-d|--delete)([[:space:]]|$)"; then
  echo '{"decision":"block","reason":"Use gt delete per graphite-pr skill."}'
  exit 0
fi
if printf '%s' "$raw" | grep -Eq "${GIT_PREFIX}checkout[[:space:]]+(-b|-B)([[:space:]]|$)"; then
  echo '{"decision":"block","reason":"Use gt create per graphite-pr skill."}'
  exit 0
fi
echo '{"decision":"allow"}'
```

Make executable, register in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [
        { "type": "command", "command": ".claude/hooks/graphite-pretool.sh" }
      ]}
    ]
  }
}
```

Optional. The skill alone is usually enough; add only if you observe `git` drift in practice.

## Permission allowlist (reduce per-command prompts)

If agents in this repo hit per-command approval prompts for routine `gt` calls, add an allowlist to user-global `~/.claude/settings.json`. A good baseline:

```json
{
  "permissions": {
    "allow": [
      "Bash(gt sync*)",
      "Bash(gt log*)",
      "Bash(gt status*)",
      "Bash(gt create*)",
      "Bash(gt modify*)",
      "Bash(gt submit*)",
      "Bash(gt track*)",
      "Bash(gt delete*)",
      "Bash(gt absorb*)",
      "Bash(gt checkout*)",
      "Bash(gt up*)",
      "Bash(gt down*)",
      "Bash(gt trunk*)"
    ]
  }
}
```

## Troubleshooting

- **`gt: command not found`** — install (step 1).
- **`gt init` says "already initialised"** — `.graphite_repo_config` exists; skip to step 3.
- **Activation check fails inside a worktree** — the check uses `git rev-parse --git-common-dir`. Run it inside the worktree.
- **OAuth keeps failing** — `gt auth --reset && gt auth`. See PAT warning above before reaching for tokens.
- **Pre-commit hook fails during `gt create`** — `gt create` runs `git commit` internally. Fix the underlying failure (formatter, linter, type check) rather than bypassing.
- **EPERM on `~/.local/share/graphite/`** — `chmod -R u+rw ~/.local/share/graphite/` or remove and let `gt` recreate.
