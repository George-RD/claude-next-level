# Deep review synthesis template

```markdown
## Verdict
PASS | CONCERNS | BLOCK

## Consensus findings
- Finding shared by both reviewers, with evidence.

## Constructive-only findings
- Quality or maintainability issue, with disposition.

## Adversarial-only findings
- Risk or blocker, with disposition.

## Fixes applied
- Commit or file:line summary.

## Deferred items
- Item, reason, owner or follow-up.

## Gate evidence
- fmt:
- build:
- lint:
- tests:
- docs/domain:

## Next action
Submit | fix first | re-review | stop
```

Disposition must be one of: fixed, rejected-with-evidence, deferred-with-owner, needs-user-decision.
