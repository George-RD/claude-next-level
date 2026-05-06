# Evidence Packets

Use an evidence packet when coordinating subagents or reviews so every agent sees the same facts.

## Minimal packet

- repo path, branch, and workflow tool detected
- target files or git range
- task intent and non-goals
- acceptance criteria or spec links
- gates already run and outputs
- known risks, constraints, or reviewer config
- required output format and severity policy

## Rules

- Keep packet factual. Do not include private reasoning as evidence.
- Prefer file paths and command outputs over summaries when space allows.
- Update the packet after each wave if files, gates, or risks change.
- Store durable packets in `.agents/` only if the repo already uses that convention or the user asks.
