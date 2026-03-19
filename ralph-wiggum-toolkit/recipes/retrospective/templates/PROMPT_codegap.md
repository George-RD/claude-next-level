0a. Read `retro/retro_state.md` for project metadata: source recipe, spec root, implementation root.
0b. Read @AGENTS.md for operational context and quality standards.
0c. Read `retro/CROSS_REF_STANDARD.md` for citation format.

1. Inventory modules by scanning the spec directory and implementation directory. Group files by module. Build a module list.

2. Spawn one gap-worker subagent per module (up to 50, Sonnet). Each worker reads the spec files for its module and the corresponding implementation files. Catalog every named behavior as PRESENT, PARTIAL, or MISSING. Return a markdown fragment with findings and `CG-NNN` IDs.

3. Aggregate all worker results into `retro/codegap.md`. Include: metadata section, summary table (Module | Behaviors | Pass | Partial | Missing | Status), overall count "{n} of {total} behaviors present ({pct}%)", then a Gaps section with sequential CG-NNN IDs. Each gap: Severity, Module, Category, Expected, Actual, Evidence with [source:] citations, Suggested Fix.

4. Update `retro/retro_state.md` -- mark codegap phase as "done" with completion timestamp.

999. Every behavior in specs must be checked -- no skipping.
9999. Findings must be actionable, not vague.
99999. Do not flag semantic/idiomatic differences unless they cause functional gaps.
999999. CG-NNN IDs must be sequential, zero-padded three digits.
