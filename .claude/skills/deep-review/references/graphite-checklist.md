# Graphite checklist

Use when repo docs mention Graphite or `gt`.

Checks:

- branch stack shown by `gt log short`
- new commits created with `gt create` or amended with `gt modify`
- no raw `git commit` or `git push` used for stack changes
- commits are atomic and ordered by dependency
- stack submitted with `gt submit` only after gates and review
- downstack commit amendments were restacked cleanly

If Graphite is configured and the work used raw git commit, flag as process concern or blocker depending on repo instructions.
