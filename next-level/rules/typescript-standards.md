# TypeScript Standards

- Strict TypeScript: enable `strict: true` in tsconfig — no exceptions
- Never use `any` — use `unknown` and narrow with type guards when the type is genuinely unknown
- ESLint for linting — follow the project's existing ESLint config
- Prefer `interface` for object shapes, `type` for unions/intersections/utility types
- Import ordering: external packages, internal modules, relative imports — one blank line between groups
- Use `const` by default, `let` only when reassignment is needed, never `var`
- Prefer named exports over default exports for better refactoring support
- Use async/await over raw promises — avoid `.then()` chains
- Prefer early returns to reduce nesting
- Use optional chaining (`?.`) and nullish coalescing (`??`) over manual null checks
- Template literals over string concatenation
