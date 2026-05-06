# Repo workflow adapters

Before editing, inspect repo-specific workflow docs and active state. Start with lightweight probes:

```bash
git status --short --branch
command -v gt >/dev/null 2>&1 && gt log short || true
find . -maxdepth 3 \( -name openspec -o -name .cflx.jsonc \) 2>/dev/null
```

## Graphite

If repo docs mention Graphite or `gt`:

- use `gt create` for new stacked commits
- use `gt modify` to amend current branch
- use `gt submit` only after gates and review
- do not use raw `git commit`, `git push`, `git checkout -b`, or branch deletion

## OpenSpec and cflx

If `openspec/` or `.cflx.jsonc` exists:

- inspect active changes before touching behavior
- do not manually implement feature-phase tasks that cflx owns
- hygiene changes may proceed if they do not satisfy or alter phase acceptance criteria
- if a hygiene fix overlaps a future phase, add a commit-body note that scopes the work and preserves phase ownership
- run project-specific validation if requested by docs, for example `cflx openspec validate <change> --strict`

## Generic git repos

- check `git status` first
- preserve user changes
- commit atomic changes when the user asked for implementation and repo instructions allow it
- avoid combining unrelated changes unless the workflow expects stacked commits

## No workflow found

Use conservative defaults: small commits, explicit gate output, and stop before push/submit unless the user asked for it.
