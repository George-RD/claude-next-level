# Closeout learning loop

## Signal sources

- GitHub PR comments and requested changes
- CodeRabbit or other automated review comments
- human review comments
- CI, e2e, lint, or cflx gate failures
- reviewer misses found later in implementation
- user friction or workflow steps repeatedly skipped

## Classification

- real miss: an issue the workflow should probably have caught
- false positive: a reviewer/tool finding rejected with evidence
- preference: subjective style or taste without project impact
- unclear instruction: skill wording caused wrong action or confusion
- process friction: correct workflow exists but costs too much or is skipped
- regression: skill change made a previously good workflow worse
- repeated pattern: same class of miss seen across workflows

## Promotion flow

1. Log the signal with evidence.
2. If one-off, false positive, or preference, do not update skills.
3. If repeated or high severity, add a deterministic eval first when possible.
4. Prefer trim, deletion, clarification, or Mermaid decision-path edits.
5. Update existing reviewer lenses before creating new personas.
6. Run static validation, behavioral evals, and adversarial review before accepting skill changes.
