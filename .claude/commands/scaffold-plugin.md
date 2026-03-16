---
description: "Scaffold a new Claude Code plugin"
argument-hint: "<name> \"<description>\""
---

# Scaffold a New Plugin

Create a new Claude Code plugin in this marketplace repo using the argument: `$ARGUMENTS`

Parse the arguments to extract:

- **name**: the first token (e.g., `my-plugin`)
- **description**: the quoted string that follows (e.g., `"Does awesome things"`)

If the arguments are missing or unclear, ask the user for the plugin name and a short description before proceeding.

## Steps

### 1. Create `<name>/plugin.json`

Follow the exact format used by existing plugins. Example from `jj-commands/plugin.json`:

```json
{
  "name": "<name>",
  "description": "<description>",
  "version": "0.1.0",
  "author": {
    "name": "George-RD"
  },
  "keywords": ["<relevant>", "<keywords>"]
}
```

Ask the user for 3-5 relevant keywords, or infer them from the description.

### 2. Create `<name>/skills/<skill-name>/SKILL.md`

Use the plugin name (or a short form) as the skill directory name. Include YAML frontmatter following the pattern from `jj-commands/skills/jj/SKILL.md`:

```markdown
---
name: <skill-name>
description: >-
  <A concise description of when this skill activates and what it does.
  Describe the trigger phrases or conditions.>
---

# <Skill Title>

<Brief overview of what this skill does.>

## Actions

### Action: <primary-action>

1. <Step 1>
2. <Step 2>
3. <Step 3>
```

Fill in sensible placeholder content based on the plugin description. The user will refine it later.

### 3. Create `<name>/commands/help.md`

Follow the pattern from `ralph-wiggum/commands/help.md`:

```markdown
---
description: "Explain <name> plugin and available commands"
---

# <Name> Plugin Help

Explain the following to the user:

## What is <Name>?

<Brief explanation based on the description.>

## Commands

| Command | Description |
|---------|-------------|
| `/<name>:help` | This help message |
```

### 4. Register in `.claude-plugin/marketplace.json`

Add a new entry to the `plugins` array in `.claude-plugin/marketplace.json`. Follow the exact structure of existing entries:

```json
{
  "name": "<name>",
  "description": "<description>",
  "version": "0.1.0",
  "author": { "name": "George-RD" },
  "source": "./<name>",
  "category": "<category>"
}
```

Choose `category` from the existing values: `"development"`, `"business"`, or ask the user if unclear.

### 5. Make scripts executable

Run `chmod +x` on any `.sh` files created in the plugin directory. Even if none were created in this scaffold, remind the user:

> Any shell scripts added later under `<name>/hooks/` or `<name>/scripts/` must be made executable with `chmod +x`.

## After scaffolding

Print a summary of all created files and directories, then suggest next steps:

1. Edit `<name>/skills/<skill-name>/SKILL.md` to define the real skill behavior
2. Add more commands under `<name>/commands/` as needed
3. Add hooks in `<name>/hooks/hooks.json` if the plugin needs pre/post processing
4. Add reference files under `<name>/skills/<skill-name>/references/` for supplemental docs

## Reference: existing plugins to study

- `jj-commands/` — minimal plugin with one skill and references
- `ralph-wiggum/` — full plugin with commands, hooks, scripts, and references
- `cycle/` — PR review plugin with commands
- `grandslam-offer/` — business workshop plugin
