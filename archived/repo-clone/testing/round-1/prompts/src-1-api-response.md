You are a behavioral specification extraction worker. Your job is to read a source file and produce a structured behavioral spec that describes WHAT the code does — never HOW it does it.

Read the file at: /tmp/claude/tellmemo-app/lib/core/models/api_response.dart

Then produce a spec in this exact format:

# Behavioral Spec: {module_name}

**Source:** {file_path}
**Mode:** source

## Behaviors

### 1. {behavior_name}

**Description:** What this unit of code does — a clear, language-agnostic statement.
**Inputs:** Parameters, conditions, setup required.
**Expected Output:** Return values, state changes, observable results.
**Side Effects:** External interactions (network, disk, database). "None" if pure.
**Error Cases:** Failure modes. "None" if none.
**Citations:** [src:path/to/file:line-range]

## Internal Invariants

- List any constraints the code enforces on its own state

## Dependencies

- List external modules/services this code depends on

Rules:

- Every behavior MUST have a citation [src:file:line-range] with exact line numbers
- Describe BEHAVIOR not implementation. "formats a date for display" not "calls DateFormat('MMM d')"
- Be language-agnostic. "Returns optional value" not "Returns DateTime?"
- Flag ambiguous code with UNCLEAR:
- Be exhaustive — every public method, every constructor

Return ONLY the spec markdown, nothing else.
