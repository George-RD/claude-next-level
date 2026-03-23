# Simplified Extraction Prompt

Used for all 3 extraction tests (r2-test-1, r2-test-3, r2-src-3). Same template, different file paths and test/source mode.

## Template

```
Study this [test/source] file and document it as a behavioral specification with citations.

Read: [file path]

Document every [test case / public function and class] as a behavioral specification in /specs/ format. Link the implementation as citations in the specification using [test/source:file:line-range] format.

The spec should describe WHAT [is being tested / the code does], not HOW. Every claim must cite the source with exact line numbers.

Return the spec as markdown.
```

## Instances Used

### r2-test-1: DateTimeUtils (test file extraction)

```
Study this test file and document it as a behavioral specification with citations.

Read: /tmp/claude/tellmemo-app/test/utils/datetime_utils_test.dart

Document every test case as a behavioral specification in /specs/ format. Link the implementation as citations in the specification using [test:file:line-range] format.

The spec should describe WHAT is being tested, not HOW. Every claim must cite the source with exact line numbers.

Return the spec as markdown.
```

### r2-test-3: Authorization (test file extraction)

```
Study this test file and document it as a behavioral specification with citations.

Read: /tmp/claude/tellmemo-app/backend/tests/integration/test_authorization.py

Document every test case as a behavioral specification in /specs/ format. Link the implementation as citations in the specification using [test:file:line-range] format.

The spec should describe WHAT is being tested, not HOW. Every claim must cite the source with exact line numbers.

Return the spec as markdown.
```

### r2-src-3: Multi-LLM Client (source file extraction)

```
Study this source file and document it as a behavioral specification with citations.

Read: /tmp/claude/tellmemo-app/backend/services/llm/multi_llm_client.py

Document every public function and class as a behavioral specification in /specs/ format. Link the implementation as citations in the specification using [source:file:line-range] format.

The spec should describe WHAT the code does, not HOW. Every claim must cite the source with exact line numbers.

Return the spec as markdown.
```
