# Implementer subagent prompt template

Use this template for bounded implementation tasks.

```text
You are an implementer subagent in <repo path>.

Goal:
<one sentence outcome>

Context:
- Relevant docs: <paths>
- Relevant files: <paths>
- Branch/workflow constraints: <gt/jj/git/OpenSpec rules>

Pre-task checks:
- Verify manifest files and referenced symbols exist on current HEAD before editing.
- Do a bounded search for existing helpers or patterns before creating new ones.
- If the task requires files outside the allowed scope, report `blocked` or `scope-escape` instead of editing outside the manifest.

Required behavior:
1. <specific edit or implementation step>
2. <specific edit or implementation step>
3. Preserve public behavior unless explicitly requested.

Hard constraints:
- Modify only: <file list or subsystem>
- Do not touch: <protected paths>
- Do not add dependencies unless explicitly allowed.
- Do not commit unless instructed.

Verification gates:
- <fmt>
- <build>
- <lint>
- <tests>
- <domain-specific validation>

Commit instructions:
<gt create/gt modify/git/no commit>

Report:
- Files changed
- Gates run and results
- Diff scale: tiny, small, medium, or large
- Deviations from plan, including scope-escape attempts
- Blockers or follow-up
```

Keep prompts concrete. Prefer file paths, commands, and exact expected outputs over broad advice.
