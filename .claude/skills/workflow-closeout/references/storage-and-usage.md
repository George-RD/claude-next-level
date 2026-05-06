# Skill storage and usage telemetry

Keep skill definitions separate from skill runtime state.

## Scope model

Use three layers:

1. Global definitions and evals for reusable skills.
2. Project-local evals and raw artifacts for repo-specific behavior.
3. Cross-repo summary telemetry for rollups, comparisons, and missed-skill analysis.

Raw traces, code snippets, private transcripts, and heavyweight artifacts should stay project-local or session-local by default. Global logs should contain summaries, hashes, counts, outcomes, and artifact references only.

## Definition and eval files

Global skill definitions live under:

- `~/.jcode/skills/<skill-name>/`
- `~/.jcode/skills/.workflow-evals/`

These are cross-repo and should change only through the governance gate.

Project-specific skill or eval definitions may live under the repo, for example:

- `<repo>/.jcode/skills/<skill-name>/`
- `<repo>/.jcode/skill-evals/`
- `<repo>/.jcode/evals/skills/`

Project-local evals are for repo conventions, OpenSpec/cflx phases, product-specific acceptance criteria, or generated fixtures that should not become global policy.

## Runtime state

Cross-repo runtime telemetry lives under:

- `~/.jcode/skill-state/skill-usage.jsonl`
- `~/.jcode/skill-state/workflow-learnings.jsonl`
- `~/.jcode/skill-state/eval-runs.jsonl`
- `~/.jcode/skill-state/evidence-packets/*.json`
- `~/.jcode/skill-state/projects/<repo_hash>/eval-runs.jsonl`
- `~/.jcode/skill-state/reports/`

Runtime state should include `repo_path` or `repo_hash` so patterns can be analyzed globally or per repo. Avoid storing secrets, private transcripts, or unnecessary code snippets.

Repo-specific raw artifacts should live under a project/session path, not the global state directory, for example:

- `<repo>/.jcode/skill-runs/<run-id>/`
- `<repo>/.jcode/reports/<run-id>/`
- the harness session artifact directory

Commit those artifacts only when they are deliberate fixtures, reports, or project documentation.

## Eval run records

Each eval run summary should be small and safe to aggregate. Use `scope: global|project` to distinguish reusable skill checks from repo-specific checks.

Required minimum fields:

- timestamp, scope
- skill, eval_suite, case_id, result
- metrics as a JSON object
- artifact_ref
- repo_hash for project-scoped records

Optional fields:

- source_harness
- repo_path, but prefer omitting it from global rollups unless it is needed for local diagnostics
- skill_hash or skill_version
- failure_taxonomy, model_route, maturity_state

Result and supporting value guidance:

- result must be one of pass, fail, warn, skip, or error
- metrics may include duration_ms, tool_calls, token_estimate, review_lenses, simplify_passes, retry_count
- artifact_ref should be an opaque artifact id, relative project path, session id, PR link, or report id for raw details

Do not put absolute local paths, raw transcript text, secrets, or code snippets in global eval-run records. If raw details are needed, keep them in the project/session artifact store and point to them with an opaque or relative `artifact_ref`.

Project-scoped summaries may be copied into the global aggregate when they are redacted and include `repo_hash`; per-project rollups under `projects/<repo_hash>/` are useful for local diagnostics and trend reports.

Higher-level analysis should compare summaries across repos by skill, skill version, eval suite, case, maturity state, model route, and failure taxonomy. It should not mix private raw project artifacts into global reports.

## What to log

Log a usage event when:

- a skill is intentionally used
- a skill probably should have been used but was missed
- repeated manual work suggests a new skill/workflow candidate
- a workflow closeout creates, rejects, or defers a learning
- a PR/CodeRabbit/human finding reveals a review gap
- an eval run passes, fails, regresses, or is skipped for scope reasons

Suggested fields:

- timestamp, repo_path, skill, event_type
- trigger: explicit, inferred, missed, closeout, review-finding
- task_kind and scale: tiny, small, medium, large
- outcome: success, partial, failed, skipped, false-positive
- metrics: tool_calls, review_passes, simplify_passes, followups_created
- for evals: scope, eval_suite, case_id, result, artifact_ref

## What not to do

Do not turn everything into a skill. Create or update a skill only when the pattern is repeated, non-obvious, high-value, or safety-critical enough that reusable guidance beats ordinary reasoning.
