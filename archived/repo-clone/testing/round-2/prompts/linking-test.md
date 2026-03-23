# Linking Test Prompt

Given a test spec (signin_screen) and a source spec (auth_repository), asked agent to identify correspondences without any explicit tagging scheme.

## Prompt

```
I have two behavioral specifications extracted from the same codebase:

1. Test Spec (signin_screen_test.dart) — documents what the UI tests verify
2. Source Spec (auth_repository.dart) — documents what the auth repository implements

Read: /tmp/claude/specs/SIGNIN_SCREEN_SPEC.md
Read: /tmp/claude/specs/AUTH_REPOSITORY_SPEC.md

Analyze the correspondences between these two specs. For each test behavior in spec #1, identify which source behaviors in spec #2 it depends on or exercises.

Show the mapping as a structured analysis.
```

## Notes

- No tagging scheme was provided — the agent discovered correspondences by semantic similarity
- The agent successfully connected test behaviors (UI layer) to source behaviors (repository layer) across abstraction boundaries
- Returned inline (not written to file) in 28 seconds
