# Round 1: Spec Extraction Eval

**Date:** 2026-03-18
**Plugin:** repo-clone
**Phase:** behavioral spec extraction
**Model:** claude-haiku-3-5 (subagents)

## Scorecard

| # | File | LOC | Behaviors | Citations OK? | Lang Leaks | Model | Duration |
|---|------|-----|-----------|---------------|------------|-------|----------|
| test-1 | datetime_utils_test.dart | 373 | 14 | Yes | Minor ("isUtc") | haiku | 17s |
| test-2 | signin_screen_test.dart | 154 | 4 | Yes | "visibility_outlined" | haiku | 18s |
| test-3 | test_authorization.py | 620 | 14 | Yes | Clean | haiku | 24s |
| src-1 | api_response.dart | 36 | 6 | Yes | "Freezed", "@JsonSerializable" | haiku | 12s |
| src-2 | auth_repository.dart | 236 | 12 | Yes | "Supabase" throughout | haiku | 19s |
| src-3 | multi_llm_client.py | 1619 | 34 | Yes | "AsyncAnthropic", "AsyncOpenAI" | haiku | 68s |

## Findings

1. **Citations accurate across all 6.** Every behavior includes `[test:file:line-range]` or `[src:file:line-range]` citations with correct line numbers matching the source files.

2. **Framework/library names leak into specs.** Specs are supposed to be language-agnostic, but implementation-specific names appear:
   - src-1: "Freezed", "@JsonSerializable" (Dart code generation annotations)
   - src-2: "Supabase" throughout (should be "auth backend" or similar)
   - src-3: "AsyncAnthropic", "AsyncOpenAI" (SDK class names)
   - test-1: "isUtc" (Dart property name)
   - test-2: "visibility_outlined" (Flutter icon constant name)

3. **Integration test handled multi-module cleanly.** test-3 correctly identified cross-cutting concerns, listed modules involved per behavior, and flagged behaviors involving 3+ modules with the CROSS-CUTTING marker.

4. **Large files produce large specs but content is good.** src-3 (1619 LOC) produced 34 behaviors, 8 invariants, 8 untested behaviors, and 14 dependencies. The spec is comprehensive without being padded.

5. **Haiku adequate for simple/medium files, borderline for complex services.** test-1, test-2, src-1 completed in 12-18s with clean output. src-3 took 68s and the quality is acceptable but a more capable model might catch subtler behavioral contracts (e.g., the implicit ordering guarantees in the fallback cascade).

## File Inventory

### Prompts (round-1/prompts/)

- `test-1-datetime-utils.md` — test mode prompt for datetime utility tests
- `test-2-signin-screen.md` — test mode prompt for sign-in screen widget tests
- `test-3-authorization.md` — test mode prompt for integration authorization tests (multi-module variant)
- `src-1-api-response.md` — source mode prompt for API response models
- `src-2-auth-repository.md` — source mode prompt for auth repository
- `src-3-multi-llm-client.md` — source mode prompt for multi-provider LLM client (large file variant)

### Results (round-1/results/)

- `test-1-datetime-utils-spec.md` — 14 behaviors extracted
- `test-2-signin-screen-spec.md` — 4 behaviors extracted
- `test-3-authorization-spec.md` — 14 behaviors extracted (integration/multi-module)
- `src-1-api-response-spec.md` — 6 behaviors, 4 invariants
- `src-2-auth-repository-spec.md` — 12 behaviors, 5 invariants
- `src-3-multi-llm-client-spec.md` — 34 behaviors, 8 invariants, 8 untested behaviors, 14 dependencies

### Source Files (round-1/source-files/)

- `test-1-datetime-utils.dart` — original test file (373 LOC)
- `test-2-signin-screen.dart` — original test file (154 LOC)
- `test-3-authorization.py` — original test file (620 LOC)
- `src-1-api-response.dart` — original source file (36 LOC)
- `src-2-auth-repository.dart` — original source file (236 LOC)
- `src-3-multi-llm-client.py` — original source file (1619 LOC)
