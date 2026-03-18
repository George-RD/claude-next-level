# Porting Methodology

Citation-backed spec extraction decouples target implementation from source syntax.
The core insight: extract WHAT the code does, cite WHERE it does it, then implement
idiomatically in the target language. Never line-for-line translate.

## The 3-Phase Porting Pipeline

### Phase 1: Extract Specs from Source

Start with tests -- they are the most reliable behavioral contracts in any codebase.

1. Read source test files. For each test, extract the behavior it verifies.
2. Read source implementation. Extract public API contracts, error handling, edge cases.
3. Write behavioral specs (see Spec Format below) with citations back to source.

Tests first because they tell you what the code *must* do. Implementation second
because it fills in details tests don't cover (logging, config, internal structure).

Output: `specs/tests/*.md` (from test extraction) and `specs/src/*.md` (from source extraction) -- one spec per module/component, all citation-backed.

### Phase 2: Plan the Porting Backlog

Turn specs into a dependency-ordered task list.

1. Identify module dependencies (what imports what).
2. Order bottom-up: leaf modules first, then modules that depend on them.
3. Group into iterations -- each iteration ports one module and its tests.
4. Write `IMPLEMENTATION_PLAN.md` with tasks, status tracking, and dependency notes.

The plan is shared state between loop iterations. Each iteration picks the next
unchecked task, ports it, and marks it done.

### Phase 3: Port One Task per Iteration

Each loop iteration:

1. Read the next task from IMPLEMENTATION_PLAN.md.
2. Follow citations to read original source for that module.
3. Implement in target language idiomatically (not syntactic translation).
4. Run target tests. Commit on green, fix on red.
5. Update IMPLEMENTATION_PLAN.md status.

One task, one commit. Small iterations keep context fresh and errors catchable.

## Citation Format

```
[source:path/to/file:42-67]
```

Citations are file paths with line ranges pointing into the source codebase. During
porting, the agent reads the cited source to understand context -- but implements
using target language idioms, not source syntax.

Citations prevent hallucination. When a spec says "sorts by priority descending
`[source:lib/scheduler.rs:89-102]`", the agent can verify the exact behavior
instead of guessing.

## Semantic Mismatches

Languages have paradigm-level differences that cannot be transliterated:

- **Error handling:** Rust `Result<T,E>` becomes thrown exceptions in TS/Python
- **Ownership/borrowing:** Vanishes in GC languages -- use `readonly` for intent
- **Duck typing to interfaces:** Python implicit protocols need explicit TS interfaces
- **Concurrency models:** Rust Send/Sync bounds disappear; cooperative async is default
- **Macros:** Expand mentally, port the generated behavior

Track mismatches in `ralph/SEMANTIC_MISMATCHES.md` as they arise during porting.

## Backpressure

The target language's toolchain is your fitness function:

- **Tests** -- the primary gate. Commit on green, revert on red.
- **Compiler/type checker** -- catches structural errors before tests run.
- **Linter** -- enforces idiomatic patterns in the target language.

The test command configured in AGENTS.md runs after every implementation step.
If it fails, the iteration fixes before moving on. No skipping red tests to
"come back later."

## Spec Format

Behavioral contracts, not code descriptions:

```markdown
# Module: scheduler

## Behavior: task_priority_sorting
**Description:** Sorts pending tasks by priority descending, then by creation
date ascending for equal priorities.
**Inputs:** List of Task objects with `priority: int` and `created_at: datetime`
**Outputs:** Sorted list (same type, new allocation)
**Error Cases:** Empty list returns empty list (no error)
**Citations:** [source:lib/scheduler.rs:89-102], [source:tests/test_scheduler.rs:45-58]

## Behavior: task_deduplication
**Description:** Removes duplicate tasks by ID, keeping the highest-priority instance.
**Inputs:** List of Task objects
**Outputs:** Deduplicated list
**Error Cases:** None
**Citations:** [source:lib/scheduler.rs:110-134]
```

Key properties: language-agnostic descriptions, explicit inputs/outputs,
error cases called out, every claim citation-backed.

## When This Works Best

- Source has good test coverage (specs are only as good as the tests they extract from)
- Both languages are general-purpose (not porting a DSL to a general language)
- Behavioral port -- same features, different language (not a redesign)
- Team understands both source and target languages

It works less well when: source has no tests, the port also redesigns the API,
or the target language lacks fundamental capabilities the source relies on.

## Ralph Loop Integration

This methodology runs on Ralph loops. Run `/ralph help` for the full
technique reference, loop mechanics, and prompt template conventions.
