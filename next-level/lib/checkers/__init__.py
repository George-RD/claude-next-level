"""Checker registry — routes files to language-specific checkers."""

from pathlib import Path
from typing import Any

# Extension to language mapping
EXTENSION_LANGUAGE: dict[str, str] = {
    ".ts": "typescript",
    ".tsx": "typescript",
    ".js": "typescript",
    ".jsx": "typescript",
    ".mts": "typescript",
    ".cts": "typescript",
    ".mjs": "typescript",
    ".cjs": "typescript",
    ".py": "python",
    ".pyi": "python",
    ".swift": "swift",
    ".rs": "rust",
    ".go": "go",
}

# Files/patterns to skip
SKIP_EXTENSIONS = {".md", ".json", ".yaml", ".yml", ".toml", ".ini", ".cfg",
                   ".lock", ".txt", ".csv", ".svg", ".png", ".jpg", ".gif",
                   ".ico", ".woff", ".woff2", ".eot", ".ttf", ".map",
                   ".html", ".css", ".scss", ".less"}

SKIP_PATTERNS = {"migrations/", "fixtures/", "__mocks__/", "node_modules/",
                 ".git/", "dist/", "build/", ".next/", "__pycache__/",
                 "vendor/", ".venv/", "venv/"}


def detect_language(filepath: str) -> str | None:
    """Detect language from file extension."""
    ext = Path(filepath).suffix.lower()
    return EXTENSION_LANGUAGE.get(ext)


def should_skip(filepath: str) -> bool:
    """Check if file should be skipped by the checker."""
    path = Path(filepath)

    # Skip by extension
    if path.suffix.lower() in SKIP_EXTENSIONS:
        return True

    # Skip by path segment
    path_parts = set(Path(filepath).parts)
    for pattern in SKIP_PATTERNS:
        segment = pattern.rstrip("/")
        if segment in path_parts:
            return True

    # Skip test files
    name = path.stem
    if (name.startswith("test_") or name.endswith("_test") or
            ".test." in path.name or ".spec." in path.name):
        return True

    # Skip config files
    if path.name in {"package.json", "tsconfig.json", "Cargo.toml",
                     "pyproject.toml", "go.mod", "go.sum", ".eslintrc.json",
                     ".prettierrc", "jest.config.ts", "vitest.config.ts",
                     "ruff.toml", "setup.py", "setup.cfg"}:
        return True

    return False


def get_checker(language: str) -> Any:
    """Import and return the checker module for a language."""
    if language == "typescript":
        from . import typescript
        return typescript
    elif language == "python":
        from . import python
        return python
    elif language == "swift":
        from . import swift
        return swift
    elif language == "rust":
        from . import rust
        return rust
    elif language == "go":
        from . import go
        return go
    return None


def check_file(filepath: str) -> dict[str, Any]:
    """Run all checks on a file. Returns findings dict."""
    if should_skip(filepath):
        return {"skipped": True, "reason": "excluded file type/pattern"}

    language = detect_language(filepath)
    if not language:
        return {"skipped": True, "reason": "unsupported language"}

    checker = get_checker(language)
    if not checker:
        return {"skipped": True, "reason": f"no checker for {language}"}

    return checker.check(filepath)
