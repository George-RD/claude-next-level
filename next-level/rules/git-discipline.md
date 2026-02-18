# Git Discipline

- Commit after each TDD cycle (red-green-refactor = one commit)
- Commit messages: `type: short description` — types: feat, fix, refactor, test, docs, chore
- Branch naming: `feat/<name>`, `fix/<name>`, `refactor/<name>` — lowercase, hyphens, no underscores
- Never force-push to main/master or shared branches
- Never commit secrets, credentials, or .env files
- Keep commits atomic: one logical change per commit, not a dump of unrelated edits
- Stage specific files — avoid `git add .` or `git add -A` which can catch unintended files
- Write the commit message body for "why", not "what" — the diff shows what changed
- Rebase feature branches on main before PR — prefer linear history
- Don't amend published commits — create fixup commits instead
