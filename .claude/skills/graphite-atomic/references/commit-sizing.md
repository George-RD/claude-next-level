# Commit Sizing: The ≤400 Line Rule

## Why the limit exists

Reviewers have a finite cognitive budget. Above roughly 400 lines per PR, review quality degrades sharply for both humans and AI review tools.

- Graphite's own guidance on AI reviews: review quality drops above ~400 lines.
- Jellyfish telemetry after teams enabled AI review: average PR shrank 82% from ~1480 lines to ~270 lines.
- A 5000-line squashed commit is effectively invisible to any reviewer.

Keep commits small so reviewers can actually read them.

## The rule

- **Target**: ≤250 lines added+removed
- **Hard cap**: ≤400 lines
- **Exception**: pure-mechanical changes (generated code, bulk renames, lockfile regeneration) may exceed the cap, tagged with a `chore:` prefix and a short note in the PR body explaining why it is mechanical.

## What "one logical unit" means

A commit you can describe in one conventional-commit subject, that reverts cleanly, and that leaves the build green. Common patterns:

- A single module or file added with its direct tests
- A single function or type introduced, wired to one call site
- A single refactor step (extract, rename, move) that keeps tests passing
- A single bug fix with its regression test
- A single config or dependency addition

## Splitting heuristics

When a piece of work naturally exceeds 400 lines, split by the first applicable rule:

1. **Interface before implementation.** Commit N introduces the trait, type, or signature. Commit N+1 implements it.
2. **Scaffolding before behaviour.** Commit N adds an empty module with types and placeholder functions. Commit N+1 fills in the logic.
3. **Tests before wiring.** Commit N adds tests marked `#[ignore]` or equivalent. Commit N+1 implements and removes the `#[ignore]`.
4. **Refactor before change.** Commit N performs a behaviour-preserving refactor. Commit N+1 changes behaviour.
5. **Mechanical before semantic.** Commit N renames, moves, or regenerates. Commit N+1 changes meaning.

If none of the five apply, the work may genuinely be indivisible, in which case annotate the oversize commit with the `chore:` exception and a note.

## What not to split

- A logical unit into arbitrary hunks just to hit the 250-line target. Sub-400 is enough. Sub-250 is aspirational.
- A test away from the code it tests. They land together.
- A rename across 50 files. That is mechanical; keep it as one `chore:` commit.
- A lockfile update. Same commit as the dependency change that caused it.

## Worked examples

### Example 1: feature split (LSP hover)

Feature: "add LSP hover that shows node metadata".

Single squashed form: ~510 lines, over the cap.

Split into four commits:

1. `feat(lsp): add hover-handler scaffolding`: ~80 lines (trait, empty handler, registration)
2. `feat(lsp): resolve node ID from cursor position`: ~180 lines (position-to-node lookup + tests)
3. `feat(lsp): format hover content from node metadata`: ~200 lines (formatter + tests)
4. `feat(lsp): wire hover into LSP server`: ~50 lines (integration)

Each commit reverts cleanly. Each builds. Each is reviewable on its own.

### Example 2: test-first pre-phase

Feature phase preceded by a test-first pre-phase (each test is a single logical unit).

Pre-phase (7 ignored tests, ~50–150 lines each):

1. `test(phase-10): add LSP workspace-membership test (ignored)`
2. `test(phase-10): add LSP diagnostic parity test (ignored)`
3. `test(phase-10): add LSP hover test (ignored)`
4. …continue per test

Feature phase (removes `#[ignore]` and implements, one test at a time):

1. `feat(phase-10): implement LSP workspace-membership, un-ignore test`
2. `feat(phase-10): implement LSP diagnostic parity, un-ignore test`
3. …continue per test

### Example 3: a refactor phase

Split of a 1200-line `god-module.rs` into five submodules.

Squashed form would be ~1300 lines. Split:

1. `refactor(god-module): extract parse submodule` (~300)
2. `refactor(god-module): extract apply submodule` (~300)
3. `refactor(god-module): extract validate submodule` (~250)
4. `refactor(god-module): extract helpers submodule` (~200)
5. `refactor(god-module): relocate mod tests to new layout` (~250)

Each commit keeps tests green. Each is reviewable on its own.

## Edge case: large test fixtures and generated content

When a single commit includes bulky generated or fixture content, count only non-generated lines against the 400-line limit. Paths that count as fixtures / generated (reviewer-skippable):

- `**/fixtures/**`, `**/testdata/**`, `**/__fixtures__/**`
- `**/*.snap`, `**/*.golden`, `**/*.snapshot`
- Generated protobuf, graphql, OpenAPI outputs (`**/*.pb.go`, `**/generated/**`)
- Vendored dependency files (`vendor/**`, `node_modules/**`)
- Lockfiles (`Cargo.lock`, `package-lock.json`, `poetry.lock`, `yarn.lock`)

Note the fixture nature in the PR body so the reviewer can focus on the meaningful diff. When the line count is borderline, err on the side of splitting: a smaller PR is always cheaper to review than a larger one with "ignore the fixture" caveats.

## Edge case: unavoidably-large atomic change

Some changes truly cannot be split: a `Cargo.lock` update spanning 1000 lines, a generated protobuf file, a `cargo fmt` pass that touches 40 files. Tag with `chore:` and note in the PR body that review can focus on meta rather than line-by-line diff.
