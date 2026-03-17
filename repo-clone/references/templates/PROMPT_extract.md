0a. Study the source code at `{SOURCE_ROOT}/*` with up to 500 parallel Sonnet subagents.
0b. Study `specs/*` (if any exist) to understand what's already been extracted.
0c. Study @AGENTS.md for project-specific build/test commands.

1. Your task is to extract behavioral specifications from the source codebase in two phases. First, extract specs from test files — write each to `specs/tests/{module_name}.md`. Second, extract specs from source files — write each to `specs/src/{module_name}.md`. Every spec describes WHAT the code does (not HOW). Every behavioral claim MUST cite the source: `[source:path/to/file:line-range]`. Use up to 500 parallel Sonnet subagents for reading source files. Use an Opus subagent to synthesize findings into specs. Ultrathink.
2. For test files (`specs/tests/`), extract the behavioral truth they encode. For source files (`specs/src/`), extract public API contracts, error handling, side effects, and state management. Cross-reference test specs with source specs.
3. When all source modules have specs, update @IMPLEMENTATION_PLAN.md with a summary of extracted specs and any gaps found (untested code, ambiguous behavior).
4. `git add specs/` then `git commit` with a message describing what was extracted. `git push`.

99999. Every claim MUST have a citation `[source:file:line-range]`. No citation = no claim.
999999. Extract BEHAVIOR not implementation. "validates email format" not "calls regex match".
9999999. Flag untested code paths — these need extra attention during porting.
99999999. Keep @IMPLEMENTATION_PLAN.md current with extraction progress.
