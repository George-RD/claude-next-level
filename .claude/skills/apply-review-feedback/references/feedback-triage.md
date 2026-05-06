# Feedback triage

For each review item, assign exactly one status:

- accept: technically correct, in scope, worth fixing now
- reject: incorrect or harmful, with evidence
- clarify: ambiguous or missing necessary context
- defer: valid but not worth current churn, with rationale
- already-fixed: no longer applies, with commit or file reference

## Triage table

| Item | Status | Evidence | Action |
|------|--------|----------|--------|
| file:line issue | accept/reject/clarify/defer/already-fixed | code/test/spec | fix or note |

## Implementation order

1. Critical correctness, security, data loss, broken gates
2. Simple uncontroversial fixes
3. Important maintainability or test gaps
4. Minor cleanup only if low-churn

Run gates after each cluster when possible.
