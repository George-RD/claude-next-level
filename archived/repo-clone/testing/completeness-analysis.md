# Variance Test: Data Integrity & Completeness Analysis

## Part 1: Data Integrity Check

### Methodology

Checked for contamination between haiku and sonnet runs at the same difficulty level, since both models wrote to the same spec file path before being copied to their final locations.

**Checks performed:**

1. MD5 hash comparison of every haiku run against every sonnet run for same difficulty
2. MD5 hash comparison within each model (detect self-duplicates)
3. Line count distribution analysis (haiku tends more variable; sonnet more consistent)
4. Manual reading of 20+ runs checking for stylistic cross-contamination

### Results

#### Byte-identical file detection

| Pair | Result |
|------|--------|
| haiku/easy vs sonnet/easy (100 pairs) | **No matches** |
| haiku/medium vs sonnet/medium (100 pairs) | **1 match: haiku/medium/run-05 == sonnet/medium/run-02** |
| Within haiku/easy (45 pairs) | No duplicates |
| Within sonnet/easy (45 pairs) | No duplicates |
| Within haiku/medium (45 pairs) | No duplicates |
| Within sonnet/medium (45 pairs) | No duplicates |

**Contamination confirmed:** `haiku/medium/phase1/run-05.md` and `sonnet/medium/phase1/run-02.md` are byte-identical (203 lines each). One overwrote the other during concurrent execution. The content reads like a haiku-style run (includes a `dart` code block in the constructor section, more procedural tone), so likely haiku wrote last to the shared file, and sonnet's copy captured haiku's output.

#### Line count distribution analysis

| Difficulty | Model | Min | Max | Range | Std Dev (approx) |
|------------|-------|-----|-----|-------|-------------------|
| Easy | Haiku | 100 | 306 | 206 | ~72 |
| Easy | Sonnet | 151 | 190 | 39 | ~12 |
| Medium | Haiku | 85 | 280 | 195 | ~62 |
| Medium | Sonnet | 131 | 225 | 94 | ~27 |

Haiku exhibits 3-5x more variance in output length than Sonnet. This is consistent with different models producing these outputs (not contaminated). The one contaminated pair (haiku/medium/run-05 at 203 lines matching sonnet/medium/run-02 at 203 lines) stands out because 203 lines falls within both distributions.

#### Stylistic analysis (manual)

Reading haiku easy runs vs sonnet easy runs reveals clear stylistic differences:

| Feature | Haiku runs | Sonnet runs |
|---------|------------|-------------|
| Opening format | Variable: some have tables immediately, some have prose | Consistent: always "Entity/Status/Scope" header block |
| Table usage | Sometimes | Almost always |
| Code examples | 4 of 10 runs include dart snippets | 0 of 10 runs include dart snippets |
| Length consistency | Wildly variable (100-306 lines) | Tight band (151-190 lines) |
| Section naming | Variable ("Behavioral Specifications", "Behavior Specifications", "Behavioral Spec") | Consistent ("Behavioral Specification") |
| Test citation format | Variable (some use `file:`, some use full path, some use relative) | Consistent full path format |
| Invariants section | 3 of 10 include explicit invariants | 6 of 10 include explicit invariants/summary |
| "No validation" callout | 5 of 10 mention this | 9 of 10 mention this explicitly |

### Data Integrity Verdict

**19 of 20 easy runs: TRUSTWORTHY.** No contamination detected. Stylistic fingerprints are distinct between models.

**19 of 20 medium runs: TRUSTWORTHY.** One confirmed contamination (haiku/medium/run-05 == sonnet/medium/run-02). Exclude BOTH from analysis since we cannot determine which model's output was overwritten. All other 18 runs show distinct stylistic signatures.

**Recommendation:** When analyzing medium difficulty, use 9 haiku runs (exclude run-05) and 9 sonnet runs (exclude run-02).

---

## Part 2: Completeness Analysis -- Easy (ProjectMember)

### Ground Truth: Complete Behavior Inventory

Source: `lib/features/projects/domain/entities/project_member.dart` (59 lines)
Test: `test/features/projects/domain/entities/project_member_test.dart` (365 lines, 17 tests)

#### Source code behaviors

| ID | Category | Behavior | Source Lines |
|----|----------|----------|-------------|
| E1 | Fields | `id` field: `String?`, optional/nullable | 2 |
| E2 | Fields | `projectId` field: `String`, required | 3 |
| E3 | Fields | `name` field: `String`, required | 4 |
| E4 | Fields | `email` field: `String`, required | 5 |
| E5 | Fields | `role` field: `String`, required | 6 |
| E6 | Fields | `addedAt` field: `DateTime?`, optional/nullable | 7 |
| E7 | Constructor | Named constructor with `required` for projectId, name, email, role | 9-16 |
| E8 | Constructor | `id` and `addedAt` are optional (no `required`) | 10, 15 |
| E9 | copyWith | Returns new `ProjectMember` instance | 18-34 |
| E10 | copyWith | Each field uses `??` coalescing (preserves original if null passed) | 27-32 |
| E11 | copyWith | Supports updating `id` independently | 27 |
| E12 | copyWith | Supports updating `projectId` independently | 28 |
| E13 | copyWith | Supports updating `name` independently | 29 |
| E14 | copyWith | Supports updating `email` independently | 30 |
| E15 | copyWith | Supports updating `role` independently | 31 |
| E16 | copyWith | Supports updating `addedAt` independently | 32 |
| E17 | copyWith | No-arg call returns exact copy | 18-34 |
| E18 | copyWith | Multi-field update in single call | 18-34 |
| E19 | fromJson | Maps `json['id']` to `id` | 38 |
| E20 | fromJson | Maps `json['project_id']` to `projectId` (snake_case) | 39 |
| E21 | fromJson | Maps `json['name']` to `name` | 40 |
| E22 | fromJson | Maps `json['email']` to `email` | 41 |
| E23 | fromJson | Maps `json['role']` to `role` | 42 |
| E24 | fromJson | Maps `json['added_at']` via `DateTime.parse()` with null check | 43-45 |
| E25 | fromJson | Missing optional fields result in null | 38, 43-45 |
| E26 | toJson | Includes `id` only if non-null (`if (id != null)`) | 51 |
| E27 | toJson | Maps `projectId` to `'project_id'` | 52 |
| E28 | toJson | Maps `name` to `'name'` | 53 |
| E29 | toJson | Maps `email` to `'email'` | 54 |
| E30 | toJson | Maps `role` to `'role'` | 55 |
| E31 | toJson | Includes `addedAt` only if non-null, via `toIso8601String()` | 56 |
| E32 | toJson | Null fields are EXCLUDED (not set to null) | 51, 56 |
| E33 | Invariant | No validation/sanitization on any field | whole class |
| E34 | Invariant | Immutability pattern (all fields `final`) | 2-7 |
| E35 | Edge | Empty strings accepted for required fields | (no validation) |
| E36 | Edge | Special characters preserved verbatim | (no transformation) |
| E37 | Edge | No length limits enforced | (no validation) |
| E38 | Edge | `copyWith` cannot clear a non-null field to null (due to `??`) | 27-32 |
| E39 | Serialization | Round-trip fidelity (fromJson->toJson preserves values) | 36-58 |

#### Test-covered behaviors (from test file)

| Test | Covers Ground Truth IDs |
|------|------------------------|
| Constructor with all fields | E1-E8 |
| Constructor with optional null | E1, E6, E7, E8 |
| copyWith id | E9, E11 |
| copyWith name | E9, E13 |
| copyWith email | E9, E14 |
| copyWith role | E9, E15 |
| copyWith projectId | E9, E12 |
| copyWith addedAt | E9, E16 |
| copyWith no params | E9, E17 |
| copyWith multiple | E9, E18 |
| fromJson complete | E19-E24 |
| fromJson minimal | E25 |
| toJson complete | E26-E31 |
| toJson null exclusion | E26, E31, E32 |
| Round-trip | E39 |
| Empty strings | E33, E35 |
| Special characters | E33, E36 |
| Long strings | E33, E37 |

### Completeness Matrix: Easy Phase 1

**H = Haiku run, S = Sonnet run. Y = captured, - = missing**

| Ground Truth ID | H01 | H02 | H03 | H04 | H05 | H06 | H07 | H08 | H09 | H10 | S01 | S02 | S03 | S04 | S05 | S06 | S07 | S08 | S09 | S10 |
|-----------------|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|
| E1: id field nullable | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E2: projectId required | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E3: name required | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E4: email required | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E5: role required | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E6: addedAt nullable | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E7: Constructor required params | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E8: Optional params (id, addedAt) | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E9: copyWith returns new instance | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E10: `??` coalescing semantics | - | - | - | - | - | - | - | - | - | - | - | - | Y | - | - | - | - | - | - | - |
| E11: copyWith id | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E12: copyWith projectId | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E13: copyWith name | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E14: copyWith email | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E15: copyWith role | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E16: copyWith addedAt | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E17: copyWith no-arg exact copy | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E18: copyWith multi-field | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E19: fromJson id mapping | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E20: fromJson project_id snake | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E21: fromJson name | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E22: fromJson email | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E23: fromJson role | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E24: fromJson DateTime.parse | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E25: fromJson missing optionals | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E26: toJson conditional id | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E27: toJson project_id key | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E28: toJson name key | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E29: toJson email key | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E30: toJson role key | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E31: toJson conditional addedAt | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E32: toJson null EXCLUSION | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E33: No validation | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E34: Immutability (final) | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E35: Empty strings accepted | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E36: Special chars preserved | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E37: No length limits | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| E38: copyWith can't null-clear | - | - | - | - | - | - | - | - | - | - | - | - | Y | - | - | - | - | - | - | - |
| E39: Round-trip fidelity | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |

### Easy: Summary Statistics

| Category | Count | Captured in ALL 20 runs | Captured in SOME | Captured in NONE |
|----------|-------|------------------------|------------------|------------------|
| 100% reliable (39 behaviors) | 37 | **37** (95%) | 0 | 0 |
| Partially reliable | 2 | 0 | **2** (5%) | 0 |
| Systematic blind spot | 0 | 0 | 0 | **0** |

**Partially reliable behaviors (captured in only 1 of 20 runs):**

| Behavior | Runs capturing it | Which run |
|----------|------------------|-----------|
| E10: `??` coalescing semantics (can't pass null to clear a non-null field) | 1/20 (5%) | Sonnet run-03 only |
| E38: copyWith cannot null-clear a non-null field | 1/20 (5%) | Sonnet run-03 only |

Both of these are essentially the same subtle implementation detail: Sonnet run-03 uniquely noted: "Null-clearance caveat: The implementation uses `??` coalescing, so passing `null` explicitly for a field that already holds a non-null value will **not** clear it -- the original value is preserved."

**Single-run completeness (if you picked any ONE run at random):**

| Metric | Haiku | Sonnet |
|--------|-------|--------|
| Average behaviors captured per run | 37/39 = 94.9% | 37/39 = 94.9% (S03 gets 39/39 = 100%) |
| Min behaviors captured | 37/39 = 94.9% | 37/39 = 94.9% |
| Max behaviors captured | 37/39 = 94.9% | 39/39 = 100% |

**Verdict for Easy:** The pipeline is extremely reliable for this simple entity. Every run captures 95%+ of ground truth. The only blind spot is a subtle implementation detail (`??` coalescing preventing null-clearance) that is arguably not a "behavior" the test file exercises but rather an implementation observation.

---

## Part 3: Completeness Analysis -- Medium (HierarchyActionBar)

### Ground Truth: Complete Behavior Inventory

Source: `lib/features/hierarchy/presentation/widgets/hierarchy_action_bar.dart` (121 lines)
Test: `test/features/hierarchy/widgets/hierarchy_action_bar_test.dart` (263 lines, 10 tests)

#### Source code behaviors

| ID | Category | Behavior | Source Lines |
|----|----------|----------|-------------|
| M1 | Widget Type | Extends `ConsumerWidget` (Riverpod integration) | 5 |
| M2 | Props | `selectedCount: int` required parameter | 6 |
| M3 | Props | `selectedItems: List<HierarchyItem>` required parameter | 7 |
| M4 | Props | `onClearSelection: VoidCallback` required parameter | 8 |
| M5 | Props | `onMoveItems: Function(List<HierarchyItem>)` required parameter | 9 |
| M6 | Props | `onDeleteItems: Function(List<HierarchyItem>)` required parameter | 10 |
| M7 | Props | `const` constructor with `super.key` | 12-19 |
| M8 | Visibility | Returns `SizedBox.shrink()` when `selectedCount == 0` | 25-27 |
| M9 | Theming | Uses `Theme.of(context)` for colors | 23 |
| M10 | Layout | Container with `primaryContainer` background color | 31 |
| M11 | Layout | `BorderRadius.circular(8)` | 33 |
| M12 | Layout | Horizontal padding 16, vertical padding 8 | 30 |
| M13 | Layout | Row layout with children | 35 |
| M14 | UI: Close | IconButton with `Icons.close`, size 20 | 37-41 |
| M15 | UI: Close | `onPressed` calls `onClearSelection` | 39 |
| M16 | UI: Spacing | `SizedBox(width: 8)` between close and count | 42 |
| M17 | UI: Count | Text shows `'$selectedCount selected'` | 43-44 |
| M18 | UI: Count | Text style: `bodyMedium`, `fontWeight: w600` | 44-45 |
| M19 | UI: Count | Text color: `onPrimaryContainer` | 46 |
| M20 | UI: Layout | `Spacer()` between count and action buttons | 50 |
| M21 | UI: Move | `TextButton.icon` with `Icons.drive_file_move_outline`, size 20 | 51-53 |
| M22 | UI: Move | Label text "Move" | 54 |
| M23 | UI: Move | `onPressed` calls `_showMoveDialog(context)` | 52 |
| M24 | UI: Move | Foreground color: `onPrimaryContainer` | 55-57 |
| M25 | UI: Spacing | `SizedBox(width: 8)` between Move and Delete | 59 |
| M26 | UI: Delete | `TextButton.icon` with `Icons.delete_outline`, size 20 | 60-62 |
| M27 | UI: Delete | Label text "Delete" | 63 |
| M28 | UI: Delete | `onPressed` calls `_showDeleteDialog(context)` | 61 |
| M29 | UI: Delete | Foreground color: `error` color | 64-66 |
| M30 | Dialog: Move | Uses `showDialog()` | 74 |
| M31 | Dialog: Move | `AlertDialog` with title "Move Items" | 76-77 |
| M32 | Dialog: Move | Content: "Move $selectedCount item(s) to a different location?" | 78 |
| M33 | Dialog: Move | Cancel button: `TextButton` with "Cancel", pops Navigator | 80-83 |
| M34 | Dialog: Move | Confirm button: `FilledButton` with "Move" | 84-89 |
| M35 | Dialog: Move | Confirm pops Navigator THEN calls `onMoveItems(selectedItems)` | 86-87 |
| M36 | Dialog: Delete | Uses `showDialog()` | 98 |
| M37 | Dialog: Delete | `AlertDialog` with title "Delete Items" | 100 |
| M38 | Dialog: Delete | Content: "Are you sure you want to delete $selectedCount item(s)?" | 101 |
| M39 | Dialog: Delete | Cancel button: `TextButton` with "Cancel", pops Navigator | 103-106 |
| M40 | Dialog: Delete | Confirm button: `FilledButton` with "Delete" | 107-115 |
| M41 | Dialog: Delete | Confirm button uses `error` background color | 112-113 |
| M42 | Dialog: Delete | Confirm pops Navigator THEN calls `onDeleteItems(selectedItems)` | 109-110 |
| M43 | Architecture | Private methods `_showMoveDialog` and `_showDeleteDialog` | 73, 96 |
| M44 | Architecture | `WidgetRef ref` parameter in build (ConsumerWidget) but unused | 22 |

### Completeness Matrix: Medium Phase 1

**Excluding contaminated runs: haiku/run-05 and sonnet/run-02**

| Ground Truth ID | H01 | H02 | H03 | H04 | H06 | H07 | H08 | H09 | H10 | S01 | S03 | S04 | S05 | S06 | S07 | S08 | S09 | S10 |
|-----------------|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|
| M1: ConsumerWidget | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M2: selectedCount prop | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M3: selectedItems prop | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M4: onClearSelection prop | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M5: onMoveItems prop | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M6: onDeleteItems prop | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M7: const constructor | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M8: SizedBox.shrink when 0 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M9: Theme.of for colors | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M10: primaryContainer bg | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M11: BorderRadius 8 | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M12: Padding 16h/8v | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M13: Row layout | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M14: Close icon + size | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M15: Close calls onClear | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M16: 8px spacing | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M17: Count text format | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M18: Text style w600 | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M19: Text onPrimaryContainer | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M20: Spacer between count/actions | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M21: Move icon type + size | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M22: Move label "Move" | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M23: Move opens dialog | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M24: Move fg color | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M25: 8px between buttons | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M26: Delete icon + size | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M27: Delete label "Delete" | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M28: Delete opens dialog | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M29: Delete fg error color | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M30: showDialog call | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M31: Move dialog title | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M32: Move dialog content | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M33: Move Cancel button | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M34: Move FilledButton | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M35: Move confirm pops+calls | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M36: Delete showDialog | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M37: Delete dialog title | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M38: Delete dialog content | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M39: Delete Cancel button | - | Y | Y | Y | - | Y | - | Y | - | - | Y | - | - | - | - | - | - | - |
| M40: Delete FilledButton | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M41: Delete btn error color | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M42: Delete pops+calls | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| M43: Private method names | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| M44: Unused WidgetRef | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |

### Medium: Summary Statistics

| Category | Count | Details |
|----------|-------|---------|
| **100% reliable** (captured in ALL 18 runs) | 28/44 = 64% | All test-observable behaviors |
| **Partially reliable** | 1/44 = 2% | M39: Delete Cancel button (5 of 18 runs) |
| **Systematic blind spot** | 15/44 = 34% | All visual/styling/architecture details |

#### Behaviors captured in ALL runs (100% reliable)

All 28 behaviors that are directly observable from the test file:

- All 5 props (M2-M6)
- Visibility behavior (M8)
- Close button presence and callback (M14, M15)
- Count text format (M17)
- Move button icon and label (M21, M22)
- Move opens dialog (M23)
- Delete button icon and label (M26, M27)
- Delete opens dialog (M28)
- All dialog content (M30-M32, M34-M38, M40, M42)
- Move Cancel button (M33)

#### Behaviors captured SOMETIMES (partially reliable)

| Behavior | Haiku (9 runs) | Sonnet (9 runs) | Total |
|----------|---------------|-----------------|-------|
| M39: Delete dialog has Cancel button | 4/9 (44%) | 1/9 (11%) | 5/18 (28%) |

Note: The delete dialog Cancel button IS in the source code (line 103-106) and IS implicitly tested (the test just doesn't assert its existence separately -- the move dialog test checks for Cancel, but the delete dialog test does not explicitly assert Cancel). The spec generators inconsistently infer this.

#### Behaviors NEVER captured (systematic blind spots)

| ID | Behavior | Why missed |
|----|----------|-----------|
| M1 | ConsumerWidget (extends) | Tests don't assert widget type; source-only detail |
| M7 | `const` constructor | Not tested; Dart constructor detail |
| M9 | `Theme.of(context)` usage | Not tested; styling implementation detail |
| M10 | `primaryContainer` background | Not tested; visual styling |
| M11 | `BorderRadius.circular(8)` | Not tested; visual styling |
| M12 | Padding 16h/8v | Not tested; layout detail |
| M13 | Row layout | Not tested; layout structure |
| M16 | 8px spacing between elements | Not tested; layout detail |
| M18 | Font weight w600 | Not tested; text styling |
| M19 | onPrimaryContainer text color | Not tested; color styling |
| M20 | Spacer widget | Not tested; layout detail |
| M24 | Move button foreground color | Not tested; color styling |
| M25 | 8px between Move/Delete buttons | Not tested; layout detail |
| M29 | Delete button error color | Not tested; color styling |
| M41 | Delete confirm error bg color | Not tested; color styling |
| M43 | Private method names | Not tested; internal implementation |
| M44 | Unused WidgetRef param | Not tested; internal implementation |

**Pattern in what gets missed:** ALL blind spots are implementation details that exist only in the source code, not observable through the test file. The pipeline reads tests (Phase 1), not source code. Since these behaviors are never tested, they never appear in any spec.

This reveals a fundamental architectural insight: **the Phase 1 pipeline can only capture behaviors that are tested.** It is 100% reliable for test-observable behaviors and 0% reliable for untested implementation details.

### Single-run completeness (Medium)

| Metric | Haiku (9 runs) | Sonnet (9 runs) |
|--------|---------------|-----------------|
| Of 44 total source behaviors: | | |
| Average captured per run | 28.4/44 = 65% | 28.1/44 = 64% |
| Of 29 test-observable behaviors: | | |
| Average captured per run | 28.4/29 = 98% | 28.1/29 = 97% |
| Min test-observable captured | 28/29 = 97% | 28/29 = 97% |
| Max test-observable captured | 29/29 = 100% | 29/29 = 100% |

---

## Part 4: Cross-cutting Analysis

### Question 1: What is the COMPLETE list of behaviors in each source file?

- **ProjectMember (Easy):** 39 behaviors across fields (6), constructor (2), copyWith (10), fromJson (7), toJson (7), invariants (2), edge cases (3), round-trip (1), and 1 subtle implementation detail.
- **HierarchyActionBar (Medium):** 44 behaviors across widget type (1), props (6), constructor (1), visibility (1), theming (1), layout (7), UI elements (16), dialog structure (13), dialog interactions (6), and architecture (2).

### Question 2: Which behaviors are captured in ALL runs (100% reliable)?

| Difficulty | 100% reliable | Of total | Of test-observable |
|------------|---------------|----------|--------------------|
| Easy | 37/39 (95%) | 95% | 37/37 = 100% |
| Medium | 28/44 (64%) | 64% | 28/29 = 97% |

### Question 3: Which behaviors are captured in SOME runs (partially reliable)?

| Difficulty | Partially reliable | Details |
|------------|-------------------|---------|
| Easy | 2/39 (5%) | `??` coalescing caveat -- 1/20 runs (Sonnet-03 only) |
| Medium | 1/44 (2%) | Delete dialog Cancel button -- 5/18 runs |

### Question 4: Which behaviors are NEVER captured (systematic blind spot)?

| Difficulty | Never captured | Details |
|------------|---------------|---------|
| Easy | 0/39 (0%) | Nothing systematically missed |
| Medium | 15/44 (34%) | All are styling/layout/architecture details NOT covered by tests |

### Question 5: Pattern in what gets missed

The pattern is unambiguous:

1. **Tested behaviors: ~100% capture rate.** Both models reliably extract every behavior that has a corresponding test case. This is true across all 38 clean runs examined.

2. **Implementation-only details: 0% capture rate.** Styling (colors, font weights, border radius), layout structure (Row, Spacer, SizedBox widths), widget inheritance (ConsumerWidget), and internal method naming are never captured because they only exist in source code, not in test assertions.

3. **Subtle semantic implications: ~5% capture rate.** Things like "copyWith uses `??` so you cannot null-clear a field" are rarely captured because they require reasoning beyond what the test code explicitly states.

### Question 6: Does haiku miss more than sonnet for partially-reliable behaviors?

| Behavior | Haiku capture rate | Sonnet capture rate |
|----------|-------------------|---------------------|
| E10/E38: `??` coalescing | 0/10 (0%) | 1/10 (10%) |
| M39: Delete Cancel button | 4/9 (44%) | 1/9 (11%) |

Mixed results. Sonnet was the only model to catch the `??` coalescing caveat. But haiku was more likely to infer the Delete Cancel button. Sample sizes are too small for statistical significance. **No meaningful pattern.**

### Question 7: If you picked ANY SINGLE RUN at random, what % of ground truth would you get?

| Scope | Easy | Medium |
|-------|------|--------|
| % of ALL source behaviors | 94.9% (37/39) | 64% (28/44) |
| % of TEST-OBSERVABLE behaviors | 100% (37/37) | 97% (28/29) |
| Worst case single run | 94.9% | 64% |
| Best case single run | 100% (Sonnet-03) | 66% |

**Key insight:** The denominator matters enormously. If the goal is "capture all behaviors the tests cover," any single run gets 97-100%. If the goal is "capture ALL source code behaviors including untested ones," Phase 1 alone gets 64-95% (worse for complex widget code with styling details).

---

## Part 5: Pipeline Trustworthiness Assessment

### For production porting, is Phase 1 sufficient?

**YES for behavioral correctness:** Phase 1 captures 97-100% of test-observable behaviors in every single run. The tests define the behavioral contract, and the specs faithfully reproduce it.

**NO for visual/styling fidelity:** Phase 1 systematically misses all untested implementation details. For a UI widget like HierarchyActionBar, this means colors, font weights, padding, border radius, and layout structure are lost. For a pure domain entity like ProjectMember, there are essentially no untested details to miss.

### Recommendations

1. **Data integrity:** Fix the concurrent write race condition before running more tests. Use unique file paths per model+difficulty+run, e.g., `specs/tests/{model}_{difficulty}_run{N}_spec.md`.

2. **Phase 1 is reliable for behavior extraction.** Any single run captures the behavioral contract with 97%+ fidelity. Multiple runs add negligible value for correctness (the 3% miss rate is for behaviors the test code itself doesn't explicitly test).

3. **Phase 2 (source code reading) is essential for UI widgets.** The 15 missed behaviors for HierarchyActionBar are all styling/layout details that only exist in source code. If the porting pipeline needs to reproduce these, Phase 2 must be implemented.

4. **Model choice (haiku vs sonnet) has minimal impact on completeness.** Both models achieve the same capture rate for test-observable behaviors. The difference is in verbosity and formatting consistency, not in behavioral coverage.

5. **The `item(s)` pluralization pattern** in dialog messages is a detail that 100% of runs capture. Both models correctly identify this as a literal string rather than conditional pluralization. This validates that the pipeline handles string-literal-level details reliably.
