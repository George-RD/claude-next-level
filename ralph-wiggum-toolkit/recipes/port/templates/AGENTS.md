# AGENTS — Porting Project

## Source

- Language: {SOURCE_LANG}
- Root: {SOURCE_ROOT}
- Test command: {SOURCE_TEST_CMD}

## Target

- Language: {TARGET_LANG}
- Root: {TARGET_ROOT}
- Test command: {TARGET_TEST_CMD}
- Build command: {TARGET_BUILD_CMD}

## Validation

Run these after implementing to get immediate feedback:

- Tests: `{TARGET_TEST_CMD}`
- Build: `{TARGET_BUILD_CMD}`
- Typecheck: {typecheck command if applicable}
- Lint: {lint command if applicable}

## Porting Conventions

- Write idiomatic {TARGET_LANG}. No transliterated {SOURCE_LANG} patterns.
- Follow citations in specs to read original source before implementing.
- Check SEMANTIC_MISMATCHES.md for known language divergences.
- One task per iteration. Commit on green, revert on red.

## Operational Notes

{Add learnings here as the port progresses — build quirks, dependency issues, test setup, etc.}

## Codebase Patterns

{Add discovered patterns here — naming conventions, error handling approach, module structure, etc.}
