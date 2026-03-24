# Project Conventions — Dynamic Context

This template is populated by the orchestrator from CLAUDE.md, project config, and repository analysis. It is injected into every agent prompt via the `{{CONVENTIONS}}` placeholder.

Fill in `{{PLACEHOLDERS}}` based on the target project's configuration before injecting.

---

## Project

- **Name**: {{PROJECT_NAME}}
- **Languages**: {{LANGUAGES}}

## Code Style

### Formatting

{{FORMATTERS}}

Run these commands to auto-format. All code must pass formatting checks before commit.

### Linting

{{LINTERS}}

Run these commands to lint. All code must pass linting with zero warnings-as-errors before commit.

### File Length Limits

{{FILE_LENGTH_LIMITS}}

If a file exceeds the limit, split it following the project's module/component conventions. Do not create files that exceed these limits.

## Testing

{{TEST_COMMANDS}}

Run these commands to execute tests. All tests must pass before commit. When adding new code, add corresponding tests.

## Version Control

### Commit Style

{{COMMIT_STYLE}}

Follow this style exactly. Examples:

- `feat(auth): add token refresh endpoint`
- `fix(parser): handle empty input without panic`
- `test(auth): add refresh token expiry test`
- `refactor(db): extract connection pool to module`
- `docs(api): update endpoint documentation`

### Branch Naming

Branches should follow the pattern: `<type>/<short-description>`

Examples: `feat/email-digest`, `fix/token-refresh`, `refactor/db-pool`

## File Structure

Follow existing project structure. Do not introduce new top-level directories or unconventional file locations without explicit instruction. Match the naming conventions of adjacent files.

## Dependencies

Do not add new dependencies without explicit instruction. If a dependency is needed, note it in the implementation report for orchestrator approval.

---

*This context is auto-generated. Do not edit the template directly — update the source configuration instead.*
