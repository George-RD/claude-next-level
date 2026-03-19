# Retrospective Audit Cross-Referencing Standard

**Status:** Draft
**Date:** 2026-03-19
**Scope:** Cross-referencing standard for the retrospective audit document chain

## Problem

The retrospective audit workflow produces a chain of six markdown documents, each analyzing gaps from a different angle. Each document references specific items in prior documents. The cross-referencing system must:

1. Survive document edits (no line numbers as anchors)
2. Be machine-parseable (agents follow refs programmatically)
3. Be human-readable (authors and reviewers read them)
4. Link each item in doc N back to the relevant item in doc N-1
5. Allow agents working on doc N+1 to load specific sections from doc N by heading

## Research Findings

### Platform support for heading IDs

| Feature | GFM | mdBook | Docusaurus | Pandoc |
|---------|-----|--------|------------|--------|
| Auto heading IDs from text | Yes | Yes | Yes | Yes |
| Custom heading IDs `{#id}` | **No** | Yes | Yes | Yes |
| Cross-file `file.md#id` links | Yes | Yes | Yes | Yes |
| Duplicate ID suffix (`-1`, `-2`) | Yes | N/A | N/A | Yes |
| Broken link detection | No | No | Yes | No |

**Key constraint:** GitHub Flavored Markdown does NOT support the `{#custom-id}` attribute syntax. Custom IDs render as literal text. Since these documents will be read on GitHub and in editors, the standard must work without custom heading attributes.

### Heading slug generation (GitHub algorithm)

GitHub generates anchor IDs from headings as follows:

1. Strip leading/trailing whitespace
2. Convert to lowercase
3. Remove markup formatting (bold, italic, code spans)
4. Remove all punctuation except hyphens and underscores
5. Replace spaces with hyphens
6. Collapse consecutive hyphens (not guaranteed — tested, GitHub does NOT collapse them)
7. Duplicate headings get `-1`, `-2` suffixes

**Implication:** A heading like `### CG-001: Token refresh missing` generates the slug `cg-001-token-refresh-missing`. The slug is long and fragile — if the description text changes, the slug changes.

### Existing citation patterns in this codebase

The ralph-wiggum-toolkit port recipe already uses structured citations:

- `[source:path/to/file:42-67]` — source code citations with line ranges
- `[test:path/to/file:15-30]` — test code citations with line ranges
- `[see-also:specs/tests/module.spec.md]` — cross-references to related spec files

These are grep-parseable, human-readable, and already understood by agents in this ecosystem. The retrospective audit cross-ref system should follow this pattern family.

### Section extraction patterns (agent operations)

Tested four approaches for extracting a section's content from a markdown file:

**Winner — awk with stable ID matching:**

```bash
awk -v id="CG-001" '
BEGIN { found=0; level=0 }
/^##+ / && index($0, id) > 0 {
  found=1; level=0
  for(i=1; i<=length($0); i++) {
    if(substr($0,i,1)=="#") level++; else break
  }
  print; next
}
found && /^##+ / {
  newlevel=0
  for(i=1; i<=length($0); i++) {
    if(substr($0,i,1)=="#") newlevel++; else break
  }
  if(newlevel <= level) { found=0 } else { print }
  next
}
found { print }
'
```

This approach:

- Matches by stable ID prefix (e.g., `CG-001`) regardless of heading text
- Includes subsections (captures `###` under `##`)
- Stops at the next same-level or higher-level heading
- Works on macOS awk and GNU awk

**Simpler alternative for flat sections (no subsections):**

```bash
grep -A 1000 "^## CG-001" file.md | awk 'NR==1{print;next} /^## /{exit} {print}'
```

**Reference parsing (extract file and section from a cross-ref):**

```bash
grep -o '\[gap:[^]]*\]' file.md | while read -r ref; do
  inner="${ref#\[gap:}"
  inner="${inner%\]}"
  file="${inner%%#*}"
  section="${inner##*#}"
  echo "File: $file  Section: $section"
done
```

## Specification

### 1. Stable ID scheme

Each gap item gets a **stable ID** that is assigned at creation and never changes, even if the heading text is edited. IDs are prefixed by document type:

| Document | ID prefix | Example |
|----------|-----------|---------|
| `codegap.md` | `CG-` | `CG-001` |
| `implementation_gap.md` | `IG-` | `IG-001` |
| `plugin_gap.md` | `PG-` | `PG-001` |
| `expected-vs-reality_gap.md` | `EVR-` | `EVR-001` |
| `E-V-R_explanations.md` | `EXP-` | `EXP-001` |
| `improvement_todo.md` | `TODO-` | `TODO-001` |

**ID rules:**

- Format: `PREFIX-NNN` (zero-padded three digits)
- IDs are sequential within a document, assigned at creation time
- IDs are **immutable** — once assigned, never reused or renumbered
- If an item is deleted, its ID is retired (leave a gap in numbering)
- The prefix makes every ID globally unique across the chain without needing the filename

### 2. Heading hierarchy per document type

All six documents follow the same structural skeleton. Only the content semantics differ.

```markdown
# {Document Title}

## Metadata
<!-- Machine-readable YAML front block -->

## Summary
<!-- Human-readable executive summary -->

## Gaps

### {ID}: {Short description}
<!-- Individual gap items live here -->
<!-- Sub-fields are bold-prefixed key-value pairs -->

### {ID}: {Short description}
...
```

#### codegap.md

```markdown
# Behavioral Gap Analysis: {source} -> {destination}

## Metadata

- **Source repo:** {name}
- **Destination repo:** {name}
- **Generated:** {date}
- **Analyzer:** {agent model}

## Summary

{1-3 sentence overview of gap count and severity distribution}

## Gaps

### CG-001: {Short description of behavioral gap}

**Severity:** critical | high | medium | low
**Category:** missing-feature | wrong-behavior | missing-error-handling | missing-test | drift
**Source behavior:** {What the source does}
**Destination behavior:** {What the destination does, or "Not implemented"}
**Evidence:** [source:{path}:{lines}]
**Impact:** {Why this matters}
```

#### implementation_gap.md

```markdown
# Implementation Gap Analysis: codegap vs Plan

## Metadata

- **Upstream:** codegap.md
- **Plan:** IMPLEMENTATION_PLAN.md
- **Generated:** {date}

## Summary

{Overview: N of M codegaps addressed in plan, K unaddressed}

## Gaps

### IG-001: {Short description}

**Upstream:** [gap:codegap.md#CG-NNN]
**Plan status:** addressed | partial | unaddressed | over-scoped
**Plan ref:** {task ID or section in IMPLEMENTATION_PLAN.md, or "None"}
**Detail:** {What the plan gets right or wrong about this codegap}
**Recommendation:** {What should change in the plan}
```

#### plugin_gap.md

```markdown
# Plugin Gap Analysis: Implementation vs Plugin Workflow

## Metadata

- **Upstream:** implementation_gap.md
- **Plugin:** {plugin name and version}
- **Generated:** {date}

## Summary

{Overview}

## Gaps

### PG-001: {Short description}

**Upstream:** [gap:implementation_gap.md#IG-NNN]
**Codegap origin:** [gap:codegap.md#CG-NNN]
**Plugin phase:** {which plugin phase/step is affected}
**Detail:** {How the plugin workflow fails to address this gap}
**Recommendation:** {Plugin change needed}
```

#### expected-vs-reality_gap.md

```markdown
# Expected vs Reality: Gap Synthesis

## Metadata

- **Upstream:** codegap.md, implementation_gap.md, plugin_gap.md
- **Generated:** {date}

## Summary

{Synthesis overview}

## Gaps

### EVR-001: {Short description — the synthesized gap}

**Origin chain:** [gap:codegap.md#CG-NNN] -> [gap:implementation_gap.md#IG-NNN] -> [gap:plugin_gap.md#PG-NNN]
**Root cause:** {Where this gap was introduced: source analysis, planning, or plugin design}
**Expected outcome:** {What the audit chain expected to find}
**Actual outcome:** {What was actually found}
**Severity:** critical | high | medium | low
**Cross-cutting:** {Does this gap pattern repeat? List related EVR-IDs if so}
```

#### E-V-R_explanations.md

```markdown
# Gap Explanations: Correlated with Session History

## Metadata

- **Upstream:** expected-vs-reality_gap.md
- **Sessions analyzed:** {list of session IDs or date ranges}
- **Generated:** {date}

## Summary

{Overview of explanation patterns}

## Explanations

### EXP-001: {Short description of why this gap occurred}

**Gap ref:** [gap:expected-vs-reality_gap.md#EVR-NNN]
**Origin chain:** [gap:codegap.md#CG-NNN] -> ... -> [gap:expected-vs-reality_gap.md#EVR-NNN]
**Session evidence:** {Which session(s), what happened}
**Root cause category:** context-loss | misunderstanding | tool-limitation | scope-creep | oversight
**Explanation:** {Detailed narrative of why this gap exists}
```

#### improvement_todo.md

```markdown
# Improvement TODO

## Metadata

- **Upstream:** E-V-R_explanations.md
- **Generated:** {date}

## Summary

{Overview: N items, priority distribution}

## TODO Items

### TODO-001: {Actionable task description}

**Priority:** P0 | P1 | P2 | P3
**Explanation ref:** [gap:E-V-R_explanations.md#EXP-NNN]
**Full chain:** [gap:codegap.md#CG-NNN] -> [gap:implementation_gap.md#IG-NNN] -> [gap:plugin_gap.md#PG-NNN] -> [gap:expected-vs-reality_gap.md#EVR-NNN] -> [gap:E-V-R_explanations.md#EXP-NNN]
**Acceptance criteria:** {How to verify this TODO is done}
**Effort estimate:** trivial | small | medium | large
**Detail:** {What to do, concretely}
```

### 3. Cross-reference syntax

```
[gap:{filename}#{stable-id}]
```

**Examples:**

- `[gap:codegap.md#CG-001]`
- `[gap:implementation_gap.md#IG-003]`
- `[gap:expected-vs-reality_gap.md#EVR-012]`

**Rules:**

- The filename is always the basename (no directory path) because all six documents live in the same directory
- The stable ID after `#` matches the ID prefix in the target document's heading
- The `gap:` prefix distinguishes these from other citation types (`source:`, `test:`, `see-also:`) already in use
- Multiple upstream refs are comma-separated: `[gap:codegap.md#CG-001, gap:codegap.md#CG-003]`
- Chain refs use `->` arrow syntax for traceability: `[gap:codegap.md#CG-001] -> [gap:implementation_gap.md#IG-002]`

**Why not standard markdown links?** Standard markdown links `[text](file.md#heading)` depend on the full heading slug, which changes when heading text is edited. The `[gap:file#ID]` syntax decouples the reference from the heading text — only the stable ID matters.

### 4. Section ID generation

Section IDs are NOT generated from heading text. They are the **stable ID prefix** embedded in the heading:

```markdown
### CG-001: Token refresh missing in destination
```

The agent finds this section by searching for `CG-001` in headings, not by computing `cg-001-token-refresh-missing-in-destination`. This is the core design decision: **IDs are assigned, not derived**.

The heading text after the colon is for humans. It can be freely edited without breaking any cross-references.

### 5. How an agent loads a section

An agent that needs to read a specific referenced section performs:

**Step 1 — Parse the reference:**

```bash
# Input: [gap:codegap.md#CG-001]
file="codegap.md"
id="CG-001"
```

**Step 2 — Extract the section content (awk):**

```bash
awk -v id="$id" '
BEGIN { found=0; level=0 }
/^##+ / && index($0, id) > 0 {
  found=1; level=0
  for(i=1; i<=length($0); i++) {
    if(substr($0,i,1)=="#") level++; else break
  }
  print; next
}
found && /^##+ / {
  newlevel=0
  for(i=1; i<=length($0); i++) {
    if(substr($0,i,1)=="#") newlevel++; else break
  }
  if(newlevel <= level) found=0; else print
  next
}
found { print }
' "$file"
```

**Step 3 — Follow upstream refs (recursive):**
If the extracted section contains `[gap:other_file.md#OTHER-ID]`, the agent repeats steps 1-2 on that file to get the full upstream context.

**For Claude Code agents specifically:** The `Read` tool with `offset` and `limit` can be used instead of awk. The agent would:

1. `grep -n "^### $id" $file` to find the line number
2. `grep -n "^### " $file` to find all section boundaries
3. `Read` the file from the section start to the next section start

### 6. Validation rules

An agent (or CI check) can validate the entire chain:

**Rule 1 — Every ref must resolve:**

```bash
# Extract all [gap:...] refs from all chain documents
# For each ref, verify the target file exists and contains a heading with that ID
grep -roh '\[gap:[^]]*\]' *.md | sort -u | while read -r ref; do
  inner="${ref#\[gap:}"
  inner="${inner%\]}"
  file="${inner%%#*}"
  id="${inner##*#}"
  if ! grep -q "^##* $id" "$file" 2>/dev/null; then
    echo "BROKEN REF: $ref"
  fi
done
```

**Rule 2 — Every item in doc N must have an upstream ref (except codegap.md):**
Each gap item heading in documents 2-6 must contain at least one `[gap:...]` reference to a prior document.

**Rule 3 — No orphan IDs:**
Every ID in doc N-1 should be referenced by at least one item in doc N (unless explicitly marked `**Disposition:** no-action-needed`).

**Rule 4 — Chain continuity:**
A `TODO-` item's `**Full chain:**` field must trace back to a `CG-` item through every intermediate document. The chain must not skip a level.

### 7. Edge cases

#### Referenced section renamed

**Scenario:** `CG-001: Token refresh missing` is renamed to `CG-001: OAuth token lifecycle gap`.

**Impact:** None. Cross-references use `[gap:codegap.md#CG-001]` which matches on `CG-001`, not the heading text. The awk extraction matches `index($0, "CG-001")`, which works regardless of the text after the colon.

#### Referenced section deleted

**Scenario:** `CG-003` is removed from `codegap.md` after re-analysis shows it was a false positive.

**Handling:**

1. Do NOT delete the heading. Replace the content with a tombstone:

   ```markdown
   ### CG-003: ~~Rate limiter edge case~~ [RETRACTED]

   **Status:** retracted
   **Reason:** False positive — destination handles this correctly via {explanation}
   **Retracted:** {date}
   ```

2. Downstream documents referencing `CG-003` can choose to:
   - Add `**Disposition:** upstream-retracted` and stop propagating
   - Or propagate the retraction with their own tombstone

This ensures refs never dangle. The ID is retired, the section remains findable, and the audit trail is preserved.

#### Referenced section moved to different document

**Not allowed.** IDs are prefixed by document type (`CG-`, `IG-`, etc.), so moving a section between documents would change its ID prefix. If content needs to appear in a different document, create a new item with a new ID and add a `[gap:...]` ref to the original.

#### Duplicate IDs

**Not allowed.** IDs are sequential and never reused. Validation rule: `grep -c "^### CG-001" codegap.md` must return exactly 1.

#### Many-to-one references (fan-in)

Multiple items in doc N-1 may map to a single item in doc N. For example, three codegaps might all stem from the same planning failure:

```markdown
### IG-007: Plan missed auth-related gaps

**Upstream:** [gap:codegap.md#CG-001], [gap:codegap.md#CG-004], [gap:codegap.md#CG-009]
```

This is valid. The reverse (one-to-many, fan-out) is also valid — a single codegap may cause multiple implementation gaps.

#### One-to-zero references (new items)

An item in doc N may have no upstream ref if it represents something discovered at that analysis level. For example, `IG-003: Plan task 7.1 has no codegap` has no upstream because it's a plan-only finding. In this case:

```markdown
**Upstream:** None (discovered at implementation gap analysis)
```

This is valid but must be explicit — the `**Upstream:**` field is always present, never omitted.

#### Chain documents in subdirectories

If the audit output lives in a subdirectory (e.g., `ralph/audit/`), all six documents are in the same directory. References use basenames only. If a future workflow needs cross-directory references, the syntax extends to `[gap:path/to/file.md#ID]` with forward slashes.

### 8. Compatibility notes

| Context | Works? | Notes |
|---------|--------|-------|
| GitHub rendering | Partial | `[gap:file#id]` renders as literal text (not a clickable link). This is acceptable — the refs are for agents, not browsers. |
| VS Code / editor | Yes | Refs are greppable. Ctrl+click won't follow them, but search works. |
| grep/sed/awk | Yes | All parsing patterns tested on macOS awk and GNU awk. |
| Claude Code Read tool | Yes | Agent greps for line number, then uses Read with offset/limit. |
| Pandoc processing | Yes | Refs are inert text, pass through unchanged. |
| markdownlint | Yes | No violations — refs look like standard text in brackets. |

### 9. Migration from existing patterns

The existing `[source:path:lines]` and `[test:path:lines]` citations in the port recipe remain unchanged. The new `[gap:file#id]` syntax is additive:

- `[source:...]` — cite source code (line-range based, used during extraction)
- `[test:...]` — cite test code (line-range based, used during extraction)
- `[see-also:...]` — soft cross-reference to related spec (no ID, file-level)
- `[gap:...]` — cite a specific gap item by stable ID (new, used during audit)

All four citation types coexist. An agent parsing a document can distinguish them by prefix.

### 10. Reference summary

**To create a gap item:**

```markdown
### {PREFIX}-{NNN}: {Human-readable description}

**Upstream:** [gap:{upstream-file}#{upstream-id}]
```

**To reference a gap item from prose:**

```
As identified in [gap:codegap.md#CG-001], the token refresh...
```

**To extract a gap item programmatically:**

```bash
awk -v id="CG-001" '<extraction script>' codegap.md
```

**To validate all references:**

```bash
grep -roh '\[gap:[^]]*\]' *.md | <validation script>
```

**To follow a full chain from TODO back to codegap:**
Read the `**Full chain:**` field in the TODO item — it lists every hop explicitly.
