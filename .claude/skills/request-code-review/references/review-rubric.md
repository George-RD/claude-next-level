# Review rubric

## Severity

Critical:
- broken build, failing tests, data loss, security issue, incorrect behavior, process violation, or direct contradiction of requirements
- must fix before proceeding

Important:
- missing important test, incomplete implementation, maintainability risk, hidden edge case, performance issue with plausible impact, or unclear ownership
- fix before proceeding unless explicitly deferred with evidence

Minor:
- style, naming, comments, optional cleanup, small readability issue
- may defer or batch

## Checklist

- Correctness: does the code do what was requested?
- Requirements: did it satisfy only the intended scope?
- Tests: are success and failure paths covered where meaningful?
- Gates: did fmt, build, lint, tests, docs, or domain checks pass?
- Maintainability: are names, seams, visibility, and abstractions appropriate?
- Safety: any destructive behavior, secrets, auth, migration, or concurrency risk?
- Process: did the work respect repo workflow, branch tooling, specs, and ownership?
- Diff hygiene: are unrelated changes excluded?

Every finding needs file:line evidence when possible, why it matters, and a concrete fix. Do not paste full diffs or logs; quote only the smallest excerpt needed to prove the issue.
