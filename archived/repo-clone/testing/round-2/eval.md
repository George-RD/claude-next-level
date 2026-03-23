# Round 2 Eval Summary

## Test Results

| Test | Prompt Style | Output | Lines | Behaviors | Wrote to File? | Duration |
|------|-------------|--------|-------|-----------|----------------|----------|
| r2-test-1 | Simplified | datetime utils spec | 249 | 31 claims in 11 groups | YES (pipeline issue) | 31s |
| r2-test-3 | Simplified | authorization spec | 246 | 15 in 4 sections | YES (pipeline issue) | 60s |
| r2-src-3 | Simplified | multi_llm_client spec | 525 | ~30 organized by class | YES (pipeline issue) | 82s |
| r2-linking | Custom | correspondence analysis | inline | N/A | No (returned inline) | 28s |
| r2-porting | Custom | TODO list | 287 | 11 tasks | YES (wrote TODO file) | 36s |

## Key Findings

1. Simplified Geoffrey-style prompts produce BETTER organized specs (grouped by theme/class vs flat numbered list)
2. Linking works naturally without tags — haiku connected test #4 to source #5 by semantic similarity
3. Porting TODO generation successfully preserves citations and security invariants
4. PIPELINE ISSUE: "document in /specs/ format" causes agents to write files instead of returning inline. Fix: say "Return the spec as your response, do not write any files."
5. Citation format inconsistency: some used [test:methodName:line] vs [test:file:line] — need to standardize in prompt
6. Language leaks still present but less impactful than feared — linking/porting worked fine despite them

## Round 1 vs Round 2 Comparison

| Metric | Round 1 (structured) | Round 2 (simplified) |
|--------|---------------------|---------------------|
| Prompt complexity | ~20 lines with rigid template | 4-5 lines, natural language |
| Output organization | Flat numbered behaviors | Grouped by theme/class/method |
| Citation accuracy | Good | Good |
| Language leaks | Present | Still present |
| Linking capability | Not tested | Works naturally |
| Porting capability | Not tested | Works well |
| Agent behavior | Returned inline | Wrote to files (fixable) |
