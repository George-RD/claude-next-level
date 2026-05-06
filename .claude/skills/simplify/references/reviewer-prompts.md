# Simplify reviewer prompts

Each reviewer gets the same diff and requirements, but a narrow lens.

## Reuse reviewer

Find:
- duplicated logic
- existing helpers or modules that should be reused
- repeated literals, conversions, or parsing
- code that can be deleted because a nearby abstraction already covers it

Avoid:
- inventing broad abstractions
- moving code across module boundaries without clear reuse

## Quality reviewer

Find:
- unclear names
- unnecessary nesting
- overly long functions with a clean seam
- convention drift from AGENTS.md, CLAUDE.md, README, or project docs
- over-engineering and premature generality

Avoid:
- subjective style churn
- large rewrites that do not reduce complexity

## Efficiency reviewer

Find:
- redundant clones or allocations
- repeated expensive work in loops
- N+1 database or network patterns
- avoidable file-system scans
- missed batching or streaming opportunities

Avoid:
- micro-optimizations without measurable or obvious impact
- concurrency changes without tests or clear safety

## Output shape

```json
{
  "role": "reuse|quality|efficiency",
  "findings": [
    {"severity": "critical|important|minor", "file": "path:line", "issue": "...", "fix": "..."}
  ],
  "verdict": "clean|fixes-recommended|block"
}
```
