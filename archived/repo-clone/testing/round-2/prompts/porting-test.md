# Porting Test Prompt

Given the auth_repository source spec, asked agent to create a TypeScript porting TODO list with citation references back to the original Dart source.

## Prompt

```
Read: /tmp/claude/specs/AUTH_REPOSITORY_SPEC.md

Using this behavioral specification as a guide, create a TypeScript porting TODO list.

For each behavior documented in the spec, create a task that describes:
1. What to implement in TypeScript
2. Which spec behaviors it covers
3. Citations back to the original source file

Group related behaviors into logical implementation tasks. Include security invariants and error handling requirements.

Write the TODO list to /Users/george/repos/claude-next-level/AUTH_REPOSITORY_PORT_TODO.md
```

## Notes

- Agent produced 11 tasks in 287 lines, covering all 6 spec behaviors
- Citations were preserved and mapped back to original Dart source lines
- Security invariants (credential error masking, stale token clearing) were explicitly called out
- Implementation order recommendation was included
- Completed in 36 seconds
