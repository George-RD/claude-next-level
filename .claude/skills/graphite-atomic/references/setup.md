# Setting Up graphite-atomic in a Project

Run through this once per repository. Keep the skill itself slim; most project-specific setup lives here so the skill body stays small in context.

## 1. Install the Graphite CLI

macOS via Homebrew:

```bash
brew install withgraphite/tap/graphite
```

Other platforms: see <https://graphite.com/docs/install-the-cli>.

Verify and gate on the MCP-support minimum (≥ 1.6.7). The awk-based comparison below avoids `sort -V -C` portability gaps between GNU and BSD sort (macOS ships BSD by default):

```bash
GT_VERSION=$(gt --version 2>/dev/null | awk '{print $NF}')
test -n "$GT_VERSION" || { echo "gt not installed"; exit 1; }
awk -v cur="$GT_VERSION" -v min="1.6.7" 'BEGIN {
  split(cur, c, "."); split(min, m, ".");
  for (i = 1; i <= 3; i++) {
    if ((c[i]+0) > (m[i]+0)) exit 0;
    if ((c[i]+0) < (m[i]+0)) exit 1;
  }
  exit 0;
}' || { echo "gt $GT_VERSION is older than 1.6.7"; exit 1; }
```

## 2. Initialise in the repo

From the repo root (not a worktree):

```bash
gt init --trunk <trunk-branch>
```

Use the actual trunk for the project. For CAIRN that is `dev`, not `main`. Confirm:

```bash
gt trunk
```

This creates `.graphite_repo_config` inside the git common dir. In a non-worktree checkout it resolves to the regular `.git/.graphite_repo_config`. In a worktree it lives in the main repo's `.git/`, not in the worktree's `.git` pointer file. The activation check always uses `$(git rev-parse --git-common-dir)/.graphite_repo_config` for this reason.

## 3. Authenticate

Before asking the user to run `gt auth`, the agent should probe whether auth already exists. Graphite does not expose a direct `gt auth status` command, but from a branch with commits on top of trunk the following reaches the Graphite API and fails with an auth error when unauthed:

```bash
gt submit --dry-run --no-interactive
```

Caveat: on a clean trunk with nothing to submit, `gt submit --dry-run` short-circuits with "Nothing to submit!" and exits 0 without hitting the API. It cannot confirm auth in that state. If there is no stack to probe, ask the user directly ("have you run `gt auth` in a recent session?") rather than having them re-auth blindly.

When auth is genuinely missing:

```bash
gt auth
```

Opens a browser for OAuth. Required for `gt submit`. This needs the human's hands — an agent cannot complete browser OAuth on the user's behalf.

If the browser flow fails, reset and retry:

```bash
gt auth --reset
gt auth
```

**Do not** fall back to pasting a long-lived Personal Access Token via `gt config set github_token`. Plaintext PATs in `gt`'s config file leak via backups, cloud sync, and shell history. If OAuth is genuinely blocked (air-gapped dev, CI runner):

- Prefer a **fine-grained personal access token** scoped to the single repository you are working in, rather than a classic PAT. Fine-grained PATs let you pick the exact repo and the minimum actions (commit read/write, PR read/write).
- If you must use a classic PAT, avoid the `repo` scope. `repo` grants full read/write across *every* private repository the user can access. Use `public_repo` for public repos; only escalate to `repo` when you genuinely need write access to a specific private repo and understand the blast radius.
- Store the token in the OS keychain (macOS Keychain, `pass`, `gh auth token`), not `gt config`.
- Rotate after the session.

## 4. Anchor the rules in CLAUDE.md

Append to the project's `CLAUDE.md` (create if missing):

```markdown
## Graphite stacking

This project uses Graphite for atomic commits and stacked PRs.
- Use `gt create -am "<subject>"` to start a new branch plus commit
- Target ≤250 lines, hard cap ≤400 lines per commit
- One logical unit per commit. One commit per PR.
- Prefer `gt` over `git` for anything that affects branches or history
- Do not run `git merge` manually — let `gt sync` / `gt restack` or the Graphite merge queue handle merges; manual merges confuse the stack model
- Full rules live in the `graphite-atomic` skill

Trunk is `<trunk-branch>`. Publish the stack via `gt submit --stack --no-interactive`.
```

Replace `<trunk-branch>` with the actual trunk. This anchors the skill's rules in persistent context so the agent sees them at every session start, not only when the skill triggers.

## 5. Optional: protective PreToolUse hook (fail-closed)

If agents in this project reach for `git commit` / `git push` / `git checkout -b` when they should be using `gt`, add a PreToolUse hook. The pattern below **fails closed**: if the hook cannot parse its input, it blocks the tool call rather than allowing it through.

Create `.claude/hooks/graphite-pretool.sh`:

```bash
#!/usr/bin/env bash
set -u

# This hook is a heuristic defence-in-depth, not a sandbox. It catches common
# drift (plain `git commit`, absolute-path git, env-prefixed git, `git -C <dir>`
# form) but a command that actively evades it (shell eval, command substitution,
# `--git-dir=` option, exotic whitespace) will still succeed. Treat this as a
# seatbelt; the skill ruleset is the primary discipline.

fail_closed() {
  echo '{"decision":"block","reason":"graphite-atomic hook could not verify the command. Failing closed. Fix the hook or use gt (create/modify/submit/delete)."}'
  exit 0
}

command -v jq >/dev/null 2>&1 || fail_closed

input=$(cat)
raw=$(printf '%s' "$input" | jq -r '.tool_input.command // empty') || fail_closed
[ -n "$raw" ] || { echo '{"decision":"allow"}'; exit 0; }

# Match a git invocation regardless of:
#   bare git:        `git commit`
#   leading space:   `  git commit`
#   absolute path:   `/usr/bin/git commit`
#   env prefix:      `env X=y git commit`
#   -C <dir> form:   `git -C /tmp commit`
GIT_PREFIX='(^|[[:space:]]|/)git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?'

if printf '%s' "$raw" | grep -Eq "${GIT_PREFIX}(commit|push|rebase|merge)([[:space:]]|$)"; then
  echo '{"decision":"block","reason":"Use gt (create/modify/submit/sync) per graphite-atomic skill. Manual git merge confuses the stack — let gt sync/restack or the merge queue handle it. Plain git reads like git status and git log are fine."}'
  exit 0
fi

if printf '%s' "$raw" | grep -Eq "${GIT_PREFIX}branch[[:space:]]+(-D|-d|--delete)([[:space:]]|$)"; then
  echo '{"decision":"block","reason":"Use gt delete per graphite-atomic skill."}'
  exit 0
fi

if printf '%s' "$raw" | grep -Eq "${GIT_PREFIX}checkout[[:space:]]+(-b|-B)([[:space:]]|$)"; then
  echo '{"decision":"block","reason":"Use gt create per graphite-atomic skill."}'
  exit 0
fi

echo '{"decision":"allow"}'
```

Make it executable:

```bash
chmod +x .claude/hooks/graphite-pretool.sh
```

Register in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/graphite-pretool.sh" }
        ]
      }
    ]
  }
}
```

The hook is optional. The skill alone is usually sufficient. Add it only if you observe `git` drift in practice.

## 6. If using cflx: apply_prompt clause

Add to `.cflx.jsonc` under the `apply_prompt` key. Append this paragraph to the existing prompt. **Substitute placeholders** (`<phase-id>`, `<trunk-branch>`) at configuration time with literals for the project (e.g., `phase-8` for phase-8-summariser):

```text
You have access to the graphite-atomic skill. Each time you complete a logical unit of work under the 400-line cap, create a new branch and commit:

    gt create -am "<type>(<phase-id>): <subject>"

Substitute <phase-id> with this apply's phase slug when writing each subject
(for phase-8-summariser, use `phase-8`). At the end of apply, publish the
stack with `gt submit --stack --no-interactive`. Prefer `gt` over `git`
for branch and commit operations. Read the skill's SKILL.md for the full ruleset.
```

The cflx consumer stays thin. It says "use the skill"; the skill says how.

## 7. If using sauron or another phase runner

Equivalent clause wherever that runner's agent instructions live. For sauron waves, use the wave slug in place of a phase id (e.g., `feat(wave-3): …`). Same skill, same rules, different consumer.

## 8. Verify activation

From the repo root or any worktree:

```bash
test -f "$(git rev-parse --git-common-dir)/.graphite_repo_config" && echo OK
```

Prints `OK` when activation will fire.

## 9. First test commit

Make a trivial change, then:

```bash
gt create -am "chore: initial graphite test"
gt log
```

If the branch appears in `gt log` with the expected trunk base, setup is complete.

## Troubleshooting

- **`gt: command not found`**: install the CLI (step 1).
- **`gt init` fails with "already initialised"**: `.graphite_repo_config` exists; skip to step 3.
- **Skill activation check fails inside a worktree**: the check uses `git rev-parse --git-common-dir` to resolve the shared `.git` path. Verify the command runs inside the worktree.
- **OAuth fails**: `gt auth --reset && gt auth`. If that still fails, see the PAT warning in step 3 before considering token auth.
- **Pre-commit hook fails during `gt create`**: `gt create` runs `git commit` internally. The pre-commit hook fires normally. Fix the underlying failure (formatter, linter, type check) rather than bypassing.
- **EPERM on `~/.local/share/graphite/`**: `gt` uses this path for state. Fix via `chmod -R u+rw ~/.local/share/graphite/` or remove the directory and let `gt` recreate it.
- **Hook blocks a legitimate command**: the PreToolUse hook errs on the side of blocking. If you need to run a raw git command once, temporarily disable the hook by renaming `graphite-pretool.sh` to `graphite-pretool.sh.off`, run the command, then rename back.
