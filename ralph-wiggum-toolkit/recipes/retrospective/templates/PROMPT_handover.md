0a. Read `retro/retro_state.md` for project metadata (project name, directory, source recipe, languages).
0b. Read @AGENTS.md for operational context.
0c. Read `retro/CROSS_REF_STANDARD.md` for citation format.

Prerequisite: `retro/todo.md` AND `retro/opsaudit.md` must both exist. If `retro/todo.md` is missing, output "ERROR: Run todo phase first. Use: /ralph retro --phase todo" and stop. If `retro/opsaudit.md` is missing, output "ERROR: Run opsaudit phase first. Use: /ralph retro --phase opsaudit" and stop.

1. Read `retro/todo.md` and `retro/opsaudit.md` in full. todo.md is the primary input — it already synthesizes all upstream findings with full chain references.

3. Ultrathink. Produce TWO handover documents:

**Document A:** Write `retro/HANDOVER_PROJECT.md` with this structure:

```
# Project Handover: {project_name}

## Generated
{date} by retrospective recipe

## Status
{One paragraph: project state, % of spec behaviors present from codegap summary, what's stubbed vs functional, overall health assessment}

## Critical Issues (P0)
{Group P0 TODO items into WORKSTREAMS -- coherent sets of related items that should be tackled together. NOT a flat list.}

### Workstream 1: {name, e.g. "Auth Provider Implementation"}
**Items:** TODO-003, TODO-007, TODO-012
**Effort:** {sum of XS/S/M/L/XL}
**Summary:** {what this accomplishes}
**Start with:** {which item first and why}
**Dependencies:** {ordering constraints between items}

### Workstream 2: ...
{repeat for each workstream}

## Important Issues (P1)
{Same workstream format, briefer}

## Operational Issues
{OPS findings from opsaudit.md that need addressing -- commit discipline, missing gates, etc.}

## Human Observations
{Empty section -- instructions for the user to add findings the retro missed}

### HO-001: {title}
**Observed by:** {user}
**Category:** {free-form}
**Description:** {what was noticed}
**Suggested action:** {what to do about it}

{Include 2-3 blank HO-NNN templates so the user has the format ready}

## How to Use This Document
1. Open a new Claude session in {project_dir}
2. Say: "Read retro/HANDOVER_PROJECT.md and start on Workstream 1"
3. After each workstream, re-run /ralph retro --phase codegap to verify gaps are closed
```

**Document B:** Write `retro/HANDOVER_PLUGIN.md` with this structure:

```
# Plugin Handover: {project_name} Retrospective

## Generated
{date} from {project_dir} retrospective

## Context
{2-3 paragraphs: what the project was, what recipe was used, what the retro found at a high level. Enough context that someone in the plugin repo understands WITHOUT loading the project.}

## Plugin Issues Found

### From Behavioral Audit (Track B)
{Each Track B TODO item from todo.md, rewritten with plugin-repo-relative file paths. Map template names like "PROMPT_build.md" to their full plugin path like "ralph-wiggum-toolkit/recipes/{recipe}/templates/PROMPT_build.md". Include the original TODO-NNN ID for traceability.}

### From Operational Audit
{OPS items from opsaudit.md that indicate the plugin should enforce something it doesn't. Rewrite as plugin changes with plugin-repo-relative file paths.}

## Suggested Implementation Order
{Sequence by impact and dependency. Which changes unlock the most improvement?}

## How to Use This Document
1. Open a new Claude session in the plugin repo
2. Say: "Read {project_dir}/retro/HANDOVER_PLUGIN.md and implement the plugin fixes"
3. After implementing, bump plugin version
```

4. Update `retro/retro_state.md` -- mark handover phase as "done" with completion timestamp.

5. Display completion summary: list both handover documents created with their full paths.

999. Workstreams must group related items, not just chunk by count. A workstream has a coherent goal -- items that together deliver a capability or fix a subsystem.
9999. HANDOVER_PLUGIN.md must be self-contained -- readable without access to the project repo. Include enough context, evidence, and rationale that a reader in the plugin repo can act on every item.
99999. Plugin file paths must be accurate -- map from template names to their actual location in the plugin directory structure (e.g. "PROMPT_build.md" -> "ralph-wiggum-toolkit/recipes/{source_recipe}/templates/PROMPT_build.md").
999999. The Human Observations section in HANDOVER_PROJECT.md must include the HO-NNN template with clear instructions for the user to fill in their own findings.
