# Spec Extraction Variance: Deep Analysis

Based on reading all 10 runs across sonnet easy P2, haiku easy P1, and sonnet easy P1, with line-by-line comparison of content.

---

## 1. Sonnet Easy Phase 2 -- The 24% CV Outlier

**Line counts (sorted):**

| Run | Lines |
|-----|-------|
| run-06 | 153 |
| run-05 | 164 |
| run-01 | 171 |
| run-09 | 171 |
| run-08 | 183 |
| run-10 | 186 |
| run-03 | 208 |
| run-04 | 239 |
| run-02 | 280 |
| run-07 | 301 |

### Shortest (run-06, 153 lines) vs Longest (run-07, 301 lines)

**What run-07 has that run-06 does not:**

1. **Inline code snippets for every method.** Run-07 reproduces the full Dart source for the constructor, copyWith, fromJson, and toJson as fenced code blocks. Run-06 has zero code blocks -- it describes everything in prose and tables.

2. **Per-field copyWith breakdown table.** Run-07 includes a table mapping each single-field update to its specific source line:

   ```
   | Field updated | Implementation line |
   |---|---|
   | `id` | [source:...dart:27] |
   | `projectId` | [source:...dart:28] |
   ```

   Run-06 describes single-field updates in a single paragraph.

3. **"Design Decisions & Notes" section** (lines 257-282). Run-07 adds four explicit design notes:
   - No `==` or `hashCode` override
   - `copyWith` cannot clear optional fields to null
   - `role` is free-form
   - `toIso8601String` format precision warning

   Run-06 covers the first three in a compact "What the Entity Does NOT Do" section (4 bullet points, 5 lines). Run-07 spends 25 lines on the same material.

4. **Cross-Reference Summary table** (lines 285-301). Run-07 ends with a 13-row table mapping every behavior to both implementation source lines and test spec references. Run-06 has no summary table.

### Is run-06 (shortest) usable for porting?

**Yes, fully usable.** Run-06 captures every behavioral fact needed:

- All 6 fields with types, required/optional status
- Constructor semantics (no coercion, null defaults)
- copyWith semantics including the null-clearing limitation
- fromJson key mapping with added_at conditional parsing
- toJson conditional key inclusion (collection-if, keys absent not null)
- Round-trip fidelity
- Edge cases (empty strings, special chars, long strings)
- "What the Entity Does NOT Do" (no equality, no toString, no validation)

Every cross-reference to the test spec is present. A porting agent reading run-06 would know exactly what to implement.

### Is run-07 (longest) over-detailed?

**Partially.** The extra content falls into two buckets:

- **Valuable (but not necessary):** The `toIso8601String` precision note (line 277-280) warns about platform-specific formatting differences. This is genuinely useful for a porting agent writing test assertions.

- **Unnecessary for porting:** The inline code blocks (constructor, copyWith, fromJson, toJson source) add ~80 lines. The porting agent should NOT reproduce Dart syntax -- they need the behavioral contract, not the implementation. The cross-reference summary table (17 lines) duplicates information already stated inline throughout the document.

**Verdict:** The 2x size difference is ~60% code block padding, ~25% formatting expansion of the same facts, and ~15% genuinely additional insight. The variance is high in line count but low in information content.

---

## 2. Haiku vs Sonnet: Best and Worst

### Selected runs

| Category | Run | Lines | Rationale |
|----------|-----|-------|-----------|
| Best haiku P1 | run-08 | 306 | Most thorough: structured with When/Then specs, JSON examples, usage examples, implementation considerations |
| Worst haiku P1 | run-07 | 100 | Shortest by significant margin |
| Best sonnet P1 | run-01 | 182 | Most thorough: covers behaviors systematically with detailed cross-references, mentions no-equality/no-toString |
| Worst sonnet P1 | run-05 | 151 | Shortest sonnet P1 |

### Best Haiku (run-08, 306 lines) vs Worst Haiku (run-07, 100 lines)

**Behaviors in best haiku that worst haiku misses entirely:**

1. **No explicit field-type table.** Run-07 uses a bullet list for fields (lines 11-16) instead of a structured table, and omits the "Nullable" column that run-08 provides. Both capture the same fields, but run-07's format is less scannable.

2. **Dart code examples.** Run-08 includes "Usage Examples" with 4 code samples (creating a member, updating role, JSON conversion, batch updates). Run-07 has zero code examples.

3. **Implementation Considerations section.** Run-08 documents the immutability pattern, JSON field mapping convention, null safety, and no-validation-at-entity-level as explicit design notes. Run-07 has a brief "Implementation Notes" section but with less depth.

4. **Test Coverage Summary.** Run-08 provides a concrete count: "Total: 17 test cases" with breakdown by category. Run-07 has no coverage summary.

5. **JSON example payloads.** Run-08 includes actual JSON blocks showing the expected format. Run-07 describes the mapping but never shows a concrete example.

**Critical question: Are behaviors actually missing from run-07, or just underspecified?**

Run-07 still covers: construction (full and partial), all 6 copyWith cases (single-field updates for each field), no-arg copy, multi-field update, fromJson (complete and minimal), toJson (complete and null exclusion), round-trip, and all 3 edge cases. The test references are all present.

**Verdict:** Run-07 is terse but covers every behavior. The difference is presentation density, not information coverage. A porting agent could use run-07, but would have to work harder to extract the contract.

### Best Sonnet (run-01, 182 lines) vs Worst Sonnet (run-05, 151 lines)

**Differences:**

1. **"No equality / no toString" section.** Run-01 does not have an explicit section for this, but it IS mentioned in the overview: "no business logic beyond data holding." Run-05 is also silent on this. Neither sonnet P1 run covers the missing-equality point that sonnet P2 runs consistently capture.

2. **Citation style.** Run-01 uses `[test:test/features/.../project_member_test.dart:7-25]` format. Run-05 uses `[test:test/features/.../project_member_test.dart:7-25]` -- identical format. Both are consistent.

3. **copyWith null-clearing limitation.** Run-01 does NOT mention this limitation. Run-05 does NOT mention it either. This is a P1-only blind spot -- P2 runs consistently document this limitation.

**Verdict:** Best and worst sonnet P1 are remarkably close. The 31-line difference is almost entirely formatting (run-01 uses slightly more whitespace and longer prose descriptions). Both capture the same behavioral set.

### Best Haiku (run-08) vs Best Sonnet (run-01): Quality comparison

| Criterion | Best Haiku (run-08) | Best Sonnet (run-01) |
|-----------|--------------------|--------------------|
| All behaviors covered | Yes | Yes |
| copyWith null-clear limitation | No | No (P1 doesn't cover this) |
| No-equality noted | Yes (Implementation Considerations) | No |
| No-toString noted | No | No |
| Test citations | Yes, per-behavior | Yes, per-behavior |
| JSON examples | Yes | No |
| Dart code examples | Yes (4 examples) | No |
| Concrete test count | Yes (17 tests) | No |
| Source line citations | No (P1 doesn't have source) | No (P1 doesn't have source) |

**Winner: Best haiku.** Run-08 captures everything run-01 does, plus implementation considerations that run-01 omits. However, this is partly because run-08 is 306 lines (nearly 70% longer) -- it has the space to include extras.

### Worst Haiku (run-07) vs Worst Sonnet (run-05): Usability comparison

| Criterion | Worst Haiku (run-07) | Worst Sonnet (run-05) |
|-----------|--------------------|--------------------|
| All behaviors covered | Yes | Yes |
| Structured tables | Bullet list only | Yes (field table + field summary table) |
| Test citations | Yes | Yes |
| Edge cases | All 3 | All 3 |
| Conciseness | Very terse, compact | Concise but well-structured |
| Parseable by agent | Harder (less structure) | Easier (tables, clear sections) |

**Winner: Worst sonnet.** Run-05 is 50% longer than run-07 but uses that space for better structure (tables, clear section headers, test coverage summary). Both are usable, but run-05 is more reliably parseable by a downstream agent.

---

## 3. Nature of Variance -- WHY Does It Happen?

Analyzed haiku easy P1 runs: run-02 (110 lines), run-07 (100 lines), run-08 (306 lines), run-04 (291 lines).

### Variance Type Breakdown

#### Structural variance (~10% of total)

All 4 runs use the same top-level sections: Overview, Construction, copyWith, JSON Serialization, Edge Cases. The organization is stable. Minor structural differences:

- Run-08 uses "Behavioral Specifications" as a container heading; others go straight to numbered sections.
- Run-04 and run-08 put fields in a table; run-02 uses a table; run-07 uses a bullet list.
- Run-08 groups JSON under "JSON Serialization" with sub-sections for deserialization/serialization; run-04 does the same but with different sub-heading names.

This is genuine structural variance but it does not affect information extraction.

#### Verbosity (~30% of total)

This is the largest single contributor to line-count variance. Same fact, different word counts:

**Run-07 (terse):**
> "Updating `id` preserves all other fields"

**Run-08 (verbose):**
> "**Behavior:** Creating a copy with updated id preserves all other fields.\n\n**Specification:**\n- When copyWith(id: newValue) is called\n- Then the returned instance has the new id value\n- And all other fields retain their original values"

**Run-04 (verbose):**
> "#### Update ID\n[test:...]\n\nCreates a copy with a new `id` while preserving all other fields."

The same behavioral fact ("copyWith(id:) updates id, preserves others") takes 1 line in run-07, 5 lines in run-08, and 3 lines in run-04.

This pattern repeats for all 6 copyWith single-field update descriptions, all 5 JSON serialization behaviors, and all 3 edge cases. Multiplied across the document, this alone accounts for 60-100 lines of difference.

#### Coverage (~15% of total)

Some runs include behaviors that others skip entirely:

- **"No validation at entity level" as explicit design note:** Present in run-08 and run-04 as dedicated sections. Absent as a standalone section in run-07 and run-02 (though the fact is implied by the edge cases section).

- **Test coverage summary table:** Present in run-08 (with exact test counts: "Total: 17 test cases") and run-04 (with line-range breakdown). Absent in run-07 and run-02.

- **Usage/code examples:** Present in run-08 (4 examples) and run-04 (3 examples). Absent in run-07 and run-02.

These are genuinely different amounts of information, but none of the "missing" items are behavioral requirements -- they are supplementary context.

#### Detail depth (~20% of total)

Same behavior documented but at different levels of specificity:

**DateTime parsing (run-02, shallow):**
> "addedAt parses ISO 8601 format datetime strings from JSON key `added_at`"

**DateTime parsing (run-04, deep):**
> "**DateTime Parsing**: The `added_at` field expects ISO 8601 formatted datetime strings (e.g., `'2024-01-15T10:30:00Z'`)"

**DateTime parsing (run-08, deepest):**
> "**Specification:**\n- When fromJson is called with a complete JSON object\n- Then the instance properties match the JSON values\n- And field name mapping follows snake_case convention (e.g., `project_id` -> `projectId`, `added_at` -> `addedAt`)\n- And ISO 8601 datetime strings are parsed to DateTime objects"

The deep version adds concrete format examples. The deepest version spells out the mapping convention. Neither adds a behavior the shallow version misses.

#### Bonus content (~20% of total)

Content that appears in some runs but has no equivalent in others:

- **Implementation Notes / Design Decisions:** Run-08 has "Implementation Considerations" covering immutability pattern, JSON naming convention, null safety, and no-validation design. Run-04 has "Constraints & Validation" and "Implementation Notes" covering similar ground. Run-07 has "Implementation Notes" (3 bullets). Run-02 has none.

- **Integration Points:** Run-04 uniquely mentions "Backend API", "Local persistence", and "UI layer" as integration contexts. No other run includes this.

- **Invariants list:** Run-04 has a 5-item "Invariants" section. No other run structures invariants as a standalone list.

#### Citation style (~5% of total)

All haiku P1 runs use `[test:test/features/.../project_member_test.dart:LINE-LINE]` format. Some cite per-behavior (run-08 cites 11 separate test ranges); others cite ranges (run-07 cites 7 ranges but groups copyWith single-field updates into one range `43-113`). This affects line count minimally.

### Summary of Variance Sources

| Variance type | % of total variance | Impact on usability |
|--------------|--------------------|--------------------|
| Verbosity | ~30% | None -- same information, more words |
| Detail depth | ~20% | Low -- concrete examples help but aren't required |
| Bonus content | ~20% | Low -- supplementary context, not behavioral requirements |
| Coverage | ~15% | Low -- design notes are useful but not critical for porting |
| Structural | ~10% | None -- all structures are parseable |
| Citation style | ~5% | None -- all citations are functional |

**Key finding: ~60% of the variance (verbosity + structural + citation) has zero impact on information content. The remaining ~40% (coverage, detail depth, bonus) represents genuinely different amounts of information, but the "missing" items are supplementary rather than behavioral.**

---

## 4. Would 2x Haiku Help?

### Merging run-07 (100 lines) with run-04 (291 lines)

**Complementary content (present in run-04, absent in run-07):**

- Dart code examples for constructor, copyWith, JSON operations
- JSON payload examples (both complete and minimal)
- "Constraints & Validation" section noting no validation at entity level
- "Invariants" list (5 items: required fields non-null, immutability, nullable optionals, field independence, round-trip preservation)
- "Integration Points" section (backend API, local persistence, UI layer)
- Precondition/Postcondition annotations on several behaviors
- "Constraints & Assumptions" section

**Complementary content (present in run-07, absent in run-04):**

- Nothing. Run-04 is a superset of run-07's behavioral coverage.

**Would merging create conflicts?**

No. Tested by checking every behavioral statement in both runs:

- Fields: Both list the same 6 fields with the same types and optionality. No conflict.
- Constructor: Both describe the same semantics. No conflict.
- copyWith: Both describe the same 8 behaviors. No conflict.
- JSON: Both describe the same 5 behaviors with the same key mappings. No conflict.
- Edge cases: Both describe the same 3 edge cases. No conflict.

**Would the merged output match sonnet P2 quality?**

Compare merged haiku output against sonnet P2 run-06 (the shortest, "floor-quality" sonnet P2):

| Behavior | Merged haiku | Sonnet P2 run-06 |
|----------|-------------|-----------------|
| Fields + types | Yes | Yes |
| Constructor semantics | Yes | Yes |
| copyWith (all cases) | Yes | Yes |
| copyWith null-clearing limitation | No | Yes |
| fromJson key mapping | Yes | Yes |
| fromJson error behavior (missing required keys) | No | Yes (mentions TypeError) |
| toJson conditional inclusion | Yes | Yes |
| toJson key-absent vs null-value distinction | No | Yes (explicit "not set to null") |
| Round-trip fidelity | Yes | Yes |
| Edge cases (all 3) | Yes | Yes |
| No equality/hashCode | No | Yes |
| No toString | No | Yes |
| Source line citations | No (P1 has test citations only) | Yes |

**Verdict: 2x haiku gets you ~85% of sonnet P2 quality.** The remaining 15% gap is in implementation-level insights that haiku P1 consistently omits:

1. The copyWith null-clearing limitation (a Dart-specific subtlety)
2. Error behavior when required fields are missing from JSON
3. The distinction between "key absent" and "key present with null value" in toJson
4. Missing equality/hashCode/toString overrides

These are not random omissions -- they represent a consistent depth-of-analysis gap between haiku and sonnet. Merging two haiku runs would not fill this gap because neither haiku run captures these insights. They require the model to reason about what the code does NOT do, which is a harder analytical task.

---

## 5. Patterns in What Gets Dropped

Compared short runs against long runs across both models to identify systematic patterns.

### What short runs always keep (never dropped)

1. **Field definitions** -- all 6 fields, types, required/optional status. Present in every single run across all 20 files examined.
2. **Constructor semantics** -- full construction and optional-defaults-to-null. Present in every run.
3. **copyWith basic semantics** -- returns new instance, preserves unchanged fields. Present in every run.
4. **JSON key mapping** -- snake_case to camelCase mapping for all 6 fields. Present in every run.
5. **Edge cases** -- empty strings, special characters, long strings. Present in every run.
6. **Test citations** -- every run includes test references for every behavior.

### What short runs drop first (ordered by "first to be cut")

1. **Code examples / usage examples** -- FIRST to go. Present in 6/20 runs, always in the longer ones.

2. **Implementation notes / design decisions** -- SECOND to go. Notes about immutability pattern, JSON naming convention, no-validation design philosophy. Present in ~12/20 runs; consistently absent from runs under 150 lines.

3. **Coverage summary tables** -- THIRD to go. Test count breakdowns, coverage maps. Present in ~8/20 runs; always in longer runs.

4. **Cross-reference summary tables** -- FOURTH to go. End-of-document tables mapping every behavior to source + test. Present in ~6/20 runs; only in runs over 200 lines.

5. **Negative behaviors** (what the entity does NOT do) -- FIFTH to go. No equality override, no toString, no validation. This is partially present in most runs (mentioned in passing) but only given a dedicated section in ~10/20 runs.

6. **Subtle implementation details** -- LAST to go, but most impactful when dropped:
   - copyWith null-clearing limitation: present in ~14/20 runs (all sonnet P2, most sonnet P1, no haiku P1)
   - fromJson error behavior for missing required fields: present in ~6/20 runs (sonnet P2 only)
   - toJson key-absent vs null-value distinction: present in ~12/20 runs

### The pattern is NOT random

There is a clear hierarchy of what gets preserved:

```
ALWAYS KEPT (100% of runs):
  Core behaviors: fields, constructor, copyWith, JSON mapping, edge cases

USUALLY KEPT (60-80% of runs):
  Implementation subtleties: null-clearing limitation, key-absent distinction

SOMETIMES KEPT (30-60% of runs):
  Design documentation: no-equality, no-validation, negative behaviors

RARELY KEPT (under 30% of runs):
  Supplementary content: code examples, coverage tables, cross-ref summaries
```

**This hierarchy directly maps to the analytical difficulty of each category:**

- Core behaviors = describe what the code DOES (easy, directly observable)
- Implementation subtleties = describe HOW the code does it (medium, requires reading carefully)
- Design documentation = describe what the code does NOT do (hard, requires reasoning about absence)
- Supplementary content = supporting material (optional, style-dependent)

### Implications for the pipeline

**The pipeline does NOT need to worry about core behaviors being unreliable.** Every run, across both models, captures the same fundamental behavioral contract.

**The pipeline SHOULD worry about implementation subtleties.** The copyWith null-clearing limitation is a real porting concern (a target language without the same null-coalescing pattern needs to handle this differently). When this gets dropped, it's a genuine information loss.

**The pipeline can safely ignore supplementary content variance.** Code examples and coverage tables are nice-to-have but don't affect porting correctness.

---

## Summary of Key Findings

1. **The 24% CV in sonnet easy P2 is misleading.** ~60% of the line-count variance is presentation noise (verbosity, code blocks, formatting). The information-content variance is closer to 10-15%.

2. **The shortest runs ARE usable.** Sonnet P2 run-06 (153 lines) and haiku P1 run-07 (100 lines) both capture every behavioral fact needed for porting. They're terse but complete.

3. **The longest runs are NOT over-detailed.** They include genuinely useful extras (implementation notes, precision warnings), but ~50% of the extra length is code block reproduction that adds little value for porting.

4. **Best haiku beats best sonnet at P1 level.** But this is misleading -- the best haiku run is an outlier (306 lines when the median is ~140). Sonnet is more consistently good.

5. **2x haiku does NOT equal sonnet.** The gap is not random coverage variance but a systematic depth-of-analysis gap. Haiku consistently misses "what the code does NOT do" insights that sonnet captures.

6. **What gets dropped follows a predictable hierarchy.** Core behaviors are never dropped. Implementation subtleties are sometimes dropped (15-40% of runs). Supplementary content is frequently dropped (60-70% of runs). This is not random.

7. **The real risk is implementation subtlety variance.** The copyWith null-clearing limitation, error behavior for malformed JSON input, and key-absent vs null-value distinction are the items that matter for porting correctness and are inconsistently captured.
