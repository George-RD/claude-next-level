# Sizing commits: worked examples

Load this when you have a chunk of work that's bigger than 400 lines and the five splitting heuristics in `SKILL.md` aren't enough on their own.

## Why the cap exists

Reviewers (human and AI) have a finite cognitive budget. Above ~400 lines per PR, review quality degrades sharply.

- Graphite's own guidance: AI review quality drops above ~400 lines.
- Jellyfish telemetry after AI review enablement: average PR shrank 82% from ~1480 lines to ~270 lines.
- A 5000-line squashed commit is effectively invisible.

Keep commits small so reviewers can actually read them.

## What "one logical unit" means

A commit you can describe in one conventional-commit subject, that reverts cleanly, and that leaves the build green. Common patterns:

- A single module or file added with its direct tests
- A single function or type introduced, wired to one call site
- A single refactor step (extract, rename, move) that keeps tests passing
- A single bug fix with its regression test
- A single config or dependency addition

## What NOT to split

- A logical unit into arbitrary hunks just to hit the 250-line target. Sub-400 is enough. Sub-250 is aspirational.
- A test away from the code it tests. They land together.
- A rename across 50 files. That's mechanical — keep it as one `chore:` commit.
- A lockfile update. Same commit as the dependency change that caused it.

## Worked example 1: feature split (LSP hover)

Feature: "add LSP hover that shows node metadata".

Squashed: ~510 lines, over the cap.

Split into four commits:

1. `feat(lsp): add hover-handler scaffolding` — ~80 lines (trait, empty handler, registration)
2. `feat(lsp): resolve node ID from cursor position` — ~180 lines (lookup + tests)
3. `feat(lsp): format hover content from node metadata` — ~200 lines (formatter + tests)
4. `feat(lsp): wire hover into LSP server` — ~50 lines (integration)

Each commit reverts cleanly. Each builds. Each is reviewable on its own.

## Worked example 2: test-first phase

Feature phase preceded by a test-first pre-phase (each test is one logical unit).

Pre-phase (7 ignored tests, ~50–150 lines each):

1. `test(phase-10): add LSP workspace-membership test (ignored)`
2. `test(phase-10): add LSP diagnostic parity test (ignored)`
3. `test(phase-10): add LSP hover test (ignored)`
4. ...continue per test

Feature phase (un-ignore + implement, one test at a time):

1. `feat(phase-10): implement LSP workspace-membership, un-ignore test`
2. `feat(phase-10): implement LSP diagnostic parity, un-ignore test`
3. ...continue per test

## Worked example 3: refactor phase

Split a 1200-line `god-module.rs` into five submodules.

1. `refactor(god-module): extract parse submodule` (~300)
2. `refactor(god-module): extract apply submodule` (~300)
3. `refactor(god-module): extract validate submodule` (~250)
4. `refactor(god-module): extract helpers submodule` (~200)
5. `refactor(god-module): relocate mod tests to new layout` (~250)

Each commit keeps tests green.

## Edge case: large fixtures and generated content

When a commit includes bulky generated/fixture content, count only non-generated lines. Reviewer-skippable paths:

- `**/fixtures/**`, `**/testdata/**`, `**/__fixtures__/**`
- `**/*.snap`, `**/*.golden`, `**/*.snapshot`
- Generated protobuf/graphql/OpenAPI (`**/*.pb.go`, `**/generated/**`)
- Vendored deps (`vendor/**`, `node_modules/**`)
- Lockfiles (`Cargo.lock`, `package-lock.json`, `poetry.lock`, `yarn.lock`)

Note the fixture nature in the PR body. When line count is borderline, err on splitting — a smaller PR is always cheaper than a larger one with "ignore the fixture" caveats.

## Edge case: unavoidably-large atomic change

Some changes truly can't be split: a `Cargo.lock` update spanning 1000 lines, a generated protobuf file, a `cargo fmt` pass touching 40 files. Tag with `chore:` and note in the PR body that review can focus on meta rather than line-by-line diff.
