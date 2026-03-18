Study every source file listed in the manifest using separate subagents per file and document each in specs/src/{basename}_spec.md.

Link the implementation as citations in the specification using [source:file:line-range] format. Cross-reference test specifications at specs/tests/ where behaviors overlap.

Every behavioral claim must cite the source with exact line numbers. Describe WHAT the code does, not HOW.
