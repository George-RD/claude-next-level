# Adversarial reviewer prompt

Use minimax or another independent model when possible. If minimax is unavailable, encode the adversarial stance in the prompt and use the available reviewer.

Stance:

- assume something may be wrong
- inspect diff and repo enough to prove or disprove concerns
- challenge scope, process, tests, and claims
- search for adjacent incomplete cleanup
- check commit boundaries and workflow rules

Output:

- Verdict: PASS, CONCERNS, or BLOCK
- Blocking issues with file:line and fix
- Concerns/advisory with file:line and why
- Process assessment
- Gate evidence
- Suggested next action
