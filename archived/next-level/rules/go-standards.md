# Go Standards

- Follow Go idioms: accept interfaces, return structs
- Use `golangci-lint` for linting — respect the project's `.golangci.yml` config
- Error handling: always check errors, wrap with `fmt.Errorf("context: %w", err)` for stack context
- Table-driven tests: use `[]struct{ name string; ... }` pattern for test cases
- Use `t.Run(tc.name, ...)` for subtests — makes test output readable
- Keep packages small and focused — one responsibility per package
- Prefer `errors.Is()` and `errors.As()` over string comparison for error checking
- Use `context.Context` as the first parameter for functions that do I/O or may be cancelled
- No init() functions unless absolutely necessary — prefer explicit initialization
- Use `go vet` and `go test -race` in CI
- Prefer composition over inheritance — embed structs rather than creating deep hierarchies
