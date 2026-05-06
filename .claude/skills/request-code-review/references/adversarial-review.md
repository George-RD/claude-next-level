# Adversarial review

Use adversarial review for risky diffs, process-sensitive changes, pre-submit stacks, or when the user asks what was missed.

Preferred model: minimax, unless unavailable.

Prompt stance:

- do not rubber-stamp
- look for subtle bugs, semantic drift, scope creep, missing tests, process violations, and misleading claims
- inspect enough to prove or disprove suspicions
- run gates when feasible
- produce concrete file:line findings

Extra checks:

- Is this work owned by a spec or workflow that should not be bypassed?
- Did a mechanical cleanup leave adjacent dead code behind?
- Did generated docs use banned terminology or style?
- Did a refactor preserve public API and visibility constraints?
- Did the commit message accurately scope the work?
