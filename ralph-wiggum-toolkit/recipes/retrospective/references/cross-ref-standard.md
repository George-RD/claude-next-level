# Cross-Reference Standard

Reference document for agents operating within the retrospective audit chain.
All six gap analysis documents use this standard for traceability.

---

## Stable ID Scheme

Every gap item gets a stable ID at creation. IDs are immutable -- once assigned, never reused or renumbered.

### Format

```text
{PREFIX}-{NNN}
```

Three-digit zero-padded number, prefixed by document type.

### Prefix Table

| Document | Prefix | Example |
|----------|--------|---------|
| `codegap.md` | `CG-` | `CG-001` |
| `implgap.md` | `IG-` | `IG-001` |
| `plugingap.md` | `PG-` | `PG-001` |
| `synthesis.md` | `EVR-` | `EVR-001` |
| `explanations.md` | `EXP-` | `EXP-001` |
| `todo.md` | `TODO-` | `TODO-001` |

### ID Rules

- Sequential within each document, assigned at creation time
- **Never reuse** a retired ID -- leave gaps in numbering
- The prefix makes every ID globally unique across the chain without needing the filename
- IDs are assigned, not derived from heading text

### Heading Format

```markdown
### CG-001: Token refresh missing in destination
```

The text after the colon is for humans. It can be freely edited without breaking any cross-references. Agents find sections by matching the stable ID prefix (`CG-001`), not the heading slug.

---

## Citation Syntax

### Basic Reference

```text
[gap:{filename}#{stable-id}]
```

The filename is always the basename (no directory path) because all six documents live in the same `retro/` directory.

**Examples:**

```text
[gap:codegap.md#CG-001]
[gap:implgap.md#IG-003]
[gap:synthesis.md#EVR-012]
```

### Multiple Upstream References

Written as adjacent bracket tokens (no comma separator):

```markdown
**Upstream:** [gap:codegap.md#CG-001][gap:codegap.md#CG-004][gap:codegap.md#CG-009]
```

### Chain Reference (Arrow Syntax)

Use `->` to show a traceability chain across documents:

```text
[gap:codegap.md#CG-001] -> [gap:implgap.md#IG-002]
```

Full chain example (used in TODO items):

```text
[gap:codegap.md#CG-001] -> [gap:implgap.md#IG-002] -> [gap:plugingap.md#PG-003] -> [gap:synthesis.md#EVR-001] -> [gap:explanations.md#EXP-001]
```

### Inline Prose Reference

```markdown
As identified in [gap:codegap.md#CG-001], the token refresh behavior...
```

### Coexistence with Other Citation Types

The `gap:` prefix distinguishes these from existing citation families:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `source:` | Source code citation (line-range) | `[source:src/auth.rs:42-67]` |
| `test:` | Test code citation (line-range) | `[test:tests/auth_test.rs:15-30]` |
| `see-also:` | Soft cross-reference (file-level) | `[see-also:specs/tests/auth.spec.md]` |
| `gap:` | Gap item by stable ID | `[gap:codegap.md#CG-001]` |

An agent parsing a document distinguishes citation types by prefix.

---

## Validation Rules

### Rule 1: Every Reference Must Resolve

Every `[gap:file#ID]` reference in the chain must point to a heading that exists in the target file.

```bash
grep -roh '\[gap:[^]]*\]' *.md | sort -u | while read -r ref; do
  inner="${ref#\[gap:}"
  inner="${inner%\]}"
  file="${inner%%#*}"
  id="${inner##*#}"
  if ! grep -qE "^#{3,} $id" "$file" 2>/dev/null; then
    echo "BROKEN REF: $ref"
  fi
done
```

### Rule 2: Every Item Needs an Upstream Reference

Every gap item heading in documents 2-6 must contain at least one `[gap:...]` reference to a prior document. `codegap.md` is the chain root and has no upstream.

Exception: items discovered at a given analysis level (not traceable to an upstream gap) use:

```markdown
**Upstream:** None (discovered at implementation gap analysis)
```

The `**Upstream:**` field is always present, never omitted.

### Rule 3: No Orphan IDs

Every ID in document N-1 should be referenced by at least one item in document N. If an item genuinely requires no downstream action, mark it explicitly:

```markdown
**Disposition:** no-action-needed
```

### Rule 4: Chain Continuity

A `TODO-` item's `**Full chain:**` field must trace back to a `CG-` item through every intermediate document. The chain must not skip a level.

Valid:

```text
CG-001 -> IG-002 -> PG-003 -> EVR-001 -> EXP-001
```

Invalid (skips plugin_gap):

```text
CG-001 -> IG-002 -> EVR-001 -> EXP-001
```

---

## Tombstone and Retraction Rules

### Never Delete, Always Tombstone

If a gap item is retracted (false positive, re-analysis shows it was wrong), do NOT delete the heading. Replace the content with a tombstone:

```markdown
### CG-003: ~~Rate limiter edge case~~ [RETRACTED]

**Status:** retracted
**Reason:** False positive -- destination handles this correctly via {explanation}
**Retracted:** {date}
```

### Downstream Handling of Retracted Items

Documents referencing a retracted upstream item have two options:

1. Add `**Disposition:** upstream-retracted` and stop propagating
2. Propagate the retraction with their own tombstone

### Why Tombstones

- References never dangle -- the ID still resolves
- The ID is retired and will not be reused
- The audit trail is preserved -- reviewers see what was considered and rejected
- Agents following chains encounter explicit retraction rather than a dead link

---

## Section Extraction (Agent Operations)

### Extract a Section by Stable ID (awk)

This script extracts the full content of a section identified by its stable ID, including any subsections:

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
  if(newlevel <= level) found=0; else print
  next
}
found { print }
' codegap.md
```

**Behavior:**

- Matches by stable ID prefix regardless of heading text
- Includes subsections (captures `####` under `###`)
- Stops at the next same-level or higher-level heading
- Works on macOS awk and GNU awk

### Simpler Alternative (Flat Sections Only)

For sections with no subsections:

```bash
grep -A 1000 "^### CG-001" file.md | awk 'NR==1{print;next} /^### /{exit} {print}'
```

### Parse a Cross-Reference

Extract the file and section ID from a `[gap:...]` reference:

```bash
grep -o '\[gap:[^]]*\]' file.md | while read -r ref; do
  inner="${ref#\[gap:}"
  inner="${inner%\]}"
  file="${inner%%#*}"
  section="${inner##*#}"
  echo "File: $file  Section: $section"
done
```

### Claude Code Agent Approach

Agents using the `Read` tool can use an alternative workflow:

1. `grep -n "^### $id" $file` to find the line number
2. `grep -n "^### " $file` to find all section boundaries
3. `Read` the file from the section start to the next section start using `offset` and `limit`

### Follow Upstream References (Recursive)

If an extracted section contains `[gap:other_file.md#OTHER-ID]`, repeat the extraction on that file to build the full upstream context. The `**Full chain:**` field in TODO items provides all hops explicitly, so recursive traversal is optional.

---

## Edge Cases

### Renamed Section

**Scenario:** `CG-001: Token refresh missing` renamed to `CG-001: OAuth token lifecycle gap`.

**Impact:** None. Cross-references use `[gap:codegap.md#CG-001]` which matches on `CG-001`, not the heading text. The awk extraction uses `index($0, "CG-001")`, which works regardless of text after the colon.

### Deleted Section

**Scenario:** `CG-003` removed after re-analysis.

**Handling:** Do NOT delete. Apply a tombstone (see Tombstone Rules above). This ensures refs never dangle and the audit trail is preserved.

### Moved Section

**Not allowed.** IDs are prefixed by document type (`CG-`, `IG-`, etc.), so moving a section between documents would change its ID prefix. If content needs to appear in a different document, create a new item with a new ID and add a `[gap:...]` reference to the original.

### Duplicate IDs

**Not allowed.** IDs are sequential and never reused. Validation check:

```bash
grep -c "^### CG-001" codegap.md  # Must return exactly 1
```

### Fan-In (Many-to-One)

Multiple items in document N-1 may map to a single item in document N. Example: three codegaps all stem from the same planning failure:

```markdown
### IG-007: Plan missed auth-related gaps

**Upstream:** [gap:codegap.md#CG-001][gap:codegap.md#CG-004][gap:codegap.md#CG-009]
```

This is valid.

### Fan-Out (One-to-Many)

A single upstream item may cause multiple downstream items. Example: one codegap produces two implementation gaps because it affects two plan tasks. This is valid.

### One-to-Zero (New Items)

An item in document N may have no upstream reference if it represents something discovered at that analysis level. Example:

```markdown
### IG-003: Plan task 7.1 has no codegap

**Upstream:** None (discovered at implementation gap analysis)
```

This is valid but must be explicit -- the `**Upstream:**` field is always present, never omitted.

---

## Quick Reference

**Create a gap item:**

```markdown
### {PREFIX}-{NNN}: {Human-readable description}

**Upstream:** [gap:{upstream-file}#{upstream-id}]
```

**Reference a gap item in prose:**

```text
As identified in [gap:codegap.md#CG-001], the token refresh...
```

**Extract a gap item programmatically:**

```bash
awk -v id="CG-001" '<extraction script>' codegap.md
```

**Validate all references in a retro directory:**

```bash
grep -roh '\[gap:[^]]*\]' *.md | <validation script>
```

**Follow a full chain from TODO back to codegap:**

Read the `**Full chain:**` field in the TODO item -- it lists every hop explicitly.

**Compatibility:**

| Context | Works? | Notes |
|---------|--------|-------|
| GitHub rendering | Partial | Renders as literal text, not clickable. Acceptable -- refs are for agents. |
| VS Code / editor | Yes | Greppable. Ctrl+click won't follow, but search works. |
| grep / sed / awk | Yes | All parsing patterns tested on macOS awk and GNU awk. |
| Claude Code Read tool | Yes | Agent greps for line number, then uses Read with offset/limit. |
| markdownlint | Yes | No violations -- refs look like standard text in brackets. |
