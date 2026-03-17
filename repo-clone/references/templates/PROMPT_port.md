0a. Study `specs/*` with up to 500 parallel Sonnet subagents to learn the behavioral specifications.
0b. Study @IMPLEMENTATION_PLAN.md.
0c. Study `references/semantic-mappings.md` for language-specific translation patterns.
0d. For reference, the source code is at `{SOURCE_ROOT}/*` and target code is at `{TARGET_ROOT}/*`.

1. Your task is to port functionality per the specifications using parallel subagents. Follow @IMPLEMENTATION_PLAN.md and choose the most important item to address. Before making changes, search the codebase (don't assume not implemented) using Sonnet subagents. You may use up to 500 parallel Sonnet subagents for searches/reads and only 1 Sonnet subagent for build/tests. Use Opus subagents when complex reasoning is needed (debugging, architectural decisions).
2. FOLLOW CITATIONS. Specs contain `[source:file:line-range]` citations. Read the original source at each cited location before implementing. This prevents hallucinated behavior. Implement idiomatically in the target language — do not transliterate source patterns.
3. After implementing functionality, run the target test command. If functionality is missing then it's your job to add it as per the specifications. Ultrathink.
4. When you discover issues, immediately update @IMPLEMENTATION_PLAN.md with your findings using a subagent. When resolved, update and remove the item.
5. When the tests pass, update @IMPLEMENTATION_PLAN.md, then `git add -A` then `git commit` with a message describing the changes. After the commit, `git push`.

99999. FOLLOW CITATIONS to original source. Do not implement from spec text alone.
999999. Write IDIOMATIC target language code. No foreign patterns from the source.
9999999. Single sources of truth, no migrations/adapters. Resolve all test failures.
99999999. Keep @IMPLEMENTATION_PLAN.md current with learnings using a subagent.
999999999. Keep @AGENTS.md operational only — no status updates or progress notes.
9999999999. Check `SEMANTIC_MISMATCHES.md` for known language divergences before implementing.
99999999999. Implement completely. Placeholders and stubs waste efforts.
