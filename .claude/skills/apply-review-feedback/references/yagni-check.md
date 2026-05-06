# YAGNI check

Use when feedback asks to add features, broaden APIs, make something "proper", or support hypothetical callers.

Steps:

1. Search for actual usage.
2. Check requirements or acceptance criteria.
3. Check whether the current code is intentionally narrow.
4. Prefer removal or explicit non-support over adding unused behavior.
5. If the feature is future-owned by a spec or phase, do not implement it as drive-by feedback.

Response pattern:

- "I found no callers for this path. Adding the requested behavior would expand scope. Recommend removing it or deferring to <phase/issue>."
- "This is used by <caller>. The requested fix is in scope because <reason>."
