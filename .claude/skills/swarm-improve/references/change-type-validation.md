# Change-type validation routing

Use this reference when selecting gates for a plan, slice, checkpoint, or review. Match the applicable categories, prioritizing the highest-risk affected surface, then record the chosen gate and evidence or a clear N/A reason.

## Backend/API/data changes

- Run relevant unit, integration, migration, or contract tests.
- If the change affects user-visible behavior, run at least one smoke through the public surface: UI, CLI, or API.
- Evidence: command, endpoint or flow, result, and any relevant logs.

## Frontend/UI/UX changes

- For runnable user-facing UI changes, use a real browser, browser tool, or Playwright-style automation.
- Exercise changed flows and obvious adjacent controls, not just page load.
- Check console errors, loading/empty/error states, broken layout, and responsive behavior when layout changed.
- Capture screenshots, traces, or artifact paths when visual state or interaction evidence matters.
- Evidence: URL, steps/buttons clicked, screenshot or trace paths, console verdict, and visual verdict.
- Code-only review is usually insufficient for runnable user-facing UI changes unless no runnable UI exists; document why.

## CLI/TUI changes

- Run the changed command or TUI smoke when practical.
- Capture transcript, terminal output, or screenshot when output, layout, or interaction changed.
- Evidence: command, input sequence, output summary, and artifact path when relevant.

## Docs/config-only changes

- Validate examples, links, generated docs, or config parsing when user-facing.
- Evidence: command or manual check summary.

## Pure refactor/internal cleanup

- Run tests that cover the touched behavior, plus type/lint gates if available.
- If behavior is intentionally unchanged, state the invariant and how it was checked.
