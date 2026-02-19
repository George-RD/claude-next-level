# Python Standards

- Use ruff for formatting and linting (replaces black, isort, flake8)
- Type hints preferred on function signatures — use `from __future__ import annotations` for modern syntax
- pytest for testing — no unittest unless the project already uses it
- Follow PEP 8 naming: `snake_case` for functions/variables, `PascalCase` for classes, `UPPER_CASE` for constants
- Prefer pathlib over os.path for file operations
- Use dataclasses or Pydantic for structured data — avoid raw dicts for domain objects
- f-strings over `.format()` or `%` formatting
- Keep imports organized: stdlib, third-party, local — one blank line between groups
- Use `if __name__ == "__main__":` guard for scripts
- Prefer explicit exception types over bare `except:` or `except Exception:`
