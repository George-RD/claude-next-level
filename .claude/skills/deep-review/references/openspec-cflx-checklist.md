# OpenSpec and cflx checklist

Use when a repo has `openspec/`, `.cflx.jsonc`, or phase/change directories.

Checks:

- active changes inspected
- archived changes not modified
- implementation did not manually consume feature-phase tasks outside cflx
- hygiene changes do not alter acceptance criteria
- overlapping future phase scope is explained in commit body or follow-up
- relevant `cflx openspec validate <change> --strict` command is run when touching specs
- code changes obey `openspec/conventions.md`

Blocking examples:

- manually implementing queued phase features without cflx
- changing archived OpenSpec history
- adding error codes without registry updates when convention requires it
- touching generated/planned tests without removing or preserving planned attributes correctly
