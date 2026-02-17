"""Dependency detection engine for next-level.

Detects project languages, checks for linter/formatter/LSP binaries,
and scans for required plugins.
"""

import os
import shutil
import subprocess
from pathlib import Path
from typing import Any

# Language detection: config file -> language
LANGUAGE_INDICATORS: dict[str, str] = {
    "package.json": "typescript",
    "tsconfig.json": "typescript",
    "Cargo.toml": "rust",
    "Package.swift": "swift",
    "pyproject.toml": "python",
    "setup.py": "python",
    "setup.cfg": "python",
    "go.mod": "go",
}

# File extension -> language (fallback detection)
EXTENSION_MAP: dict[str, str] = {
    ".ts": "typescript",
    ".tsx": "typescript",
    ".js": "typescript",  # JS uses same toolchain
    ".jsx": "typescript",
    ".py": "python",
    ".swift": "swift",
    ".rs": "rust",
    ".go": "go",
}

# Per-language tool definitions: {tool_name: {binary, install_hint, role}}
LANGUAGE_TOOLS: dict[str, dict[str, dict[str, str]]] = {
    "typescript": {
        "prettier": {
            "binary": "prettier",
            "install": "npm install -g prettier",
            "role": "formatter",
        },
        "eslint": {
            "binary": "eslint",
            "install": "npm install -g eslint",
            "role": "linter",
        },
        "vtsls": {
            "binary": "vtsls",
            "install": "npm install -g @vtsls/language-server",
            "role": "lsp",
        },
    },
    "python": {
        "ruff": {
            "binary": "ruff",
            "install": "uv tool install ruff",
            "role": "formatter+linter",
        },
        "basedpyright": {
            "binary": "basedpyright",
            "install": "uv tool install basedpyright",
            "role": "type_checker+lsp",
        },
    },
    "swift": {
        "swiftformat": {
            "binary": "swiftformat",
            "install": "brew install swiftformat",
            "role": "formatter",
        },
        "swiftlint": {
            "binary": "swiftlint",
            "install": "brew install swiftlint",
            "role": "linter",
        },
        "sourcekit-lsp": {
            "binary": "sourcekit-lsp",
            "install": "included with Xcode",
            "role": "lsp",
        },
    },
    "rust": {
        "rustfmt": {
            "binary": "rustfmt",
            "install": "rustup component add rustfmt",
            "role": "formatter",
        },
        "clippy": {
            "binary": "cargo-clippy",
            "install": "rustup component add clippy",
            "role": "linter",
        },
        "rust-analyzer": {
            "binary": "rust-analyzer",
            "install": "rustup component add rust-analyzer",
            "role": "lsp",
        },
    },
    "go": {
        "gofmt": {
            "binary": "gofmt",
            "install": "included with Go",
            "role": "formatter",
        },
        "golangci-lint": {
            "binary": "golangci-lint",
            "install": "go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest",
            "role": "linter",
        },
        "gopls": {
            "binary": "gopls",
            "install": "go install golang.org/x/tools/gopls@latest",
            "role": "lsp",
        },
    },
}

# Plugin detection: name -> directory marker file
PLUGIN_MARKERS: dict[str, str] = {
    "omega_memory": "omega-memory",
    "coderabbit": "coderabbit",
}


def detect_languages(project_root: str | Path) -> list[str]:
    """Detect programming languages used in a project."""
    root = Path(project_root)
    found: set[str] = set()

    # Check config files first (most reliable)
    for config_file, lang in LANGUAGE_INDICATORS.items():
        if (root / config_file).exists():
            found.add(lang)

    # Fallback: scan top-level and src/ for file extensions
    scan_dirs = [root]
    src_dir = root / "src"
    if src_dir.is_dir():
        scan_dirs.append(src_dir)

    for scan_dir in scan_dirs:
        try:
            for entry in scan_dir.iterdir():
                if entry.is_file():
                    ext = entry.suffix
                    if ext in EXTENSION_MAP:
                        found.add(EXTENSION_MAP[ext])
        except PermissionError:
            continue

    return sorted(found)


def check_binary(name: str) -> bool:
    """Check if a binary is available on PATH."""
    return shutil.which(name) is not None


def check_binary_version(name: str) -> str | None:
    """Get version string of a binary, or None if not available."""
    if not check_binary(name):
        return None
    try:
        result = subprocess.run(
            [name, "--version"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        output = result.stdout.strip() or result.stderr.strip()
        # Return first line only
        return output.split("\n")[0] if output else "installed"
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return "installed"


def check_language_tools(language: str) -> dict[str, dict[str, Any]]:
    """Check availability of all tools for a language.

    Returns dict of {tool_name: {available: bool, version: str|None, ...tool_info}}.
    """
    tools = LANGUAGE_TOOLS.get(language, {})
    results: dict[str, dict[str, Any]] = {}

    for tool_name, tool_info in tools.items():
        binary = tool_info["binary"]
        available = check_binary(binary)
        results[tool_name] = {
            **tool_info,
            "available": available,
            "version": check_binary_version(binary) if available else None,
        }

    return results


def detect_plugins() -> dict[str, bool]:
    """Scan for installed Claude Code plugins."""
    results: dict[str, bool] = {}

    # Check common plugin locations
    plugin_dirs = [
        Path.home() / ".claude" / "plugins",
        Path.home() / ".claude" / "plugins" / "marketplaces",
    ]

    for plugin_name, marker in PLUGIN_MARKERS.items():
        found = False
        for plugin_dir in plugin_dirs:
            if not plugin_dir.is_dir():
                continue
            # Recursively search for plugin directory or plugin.json mentioning it
            for entry in plugin_dir.rglob("plugin.json"):
                try:
                    import json
                    with open(entry) as f:
                        manifest = json.load(f)
                    if marker in manifest.get("name", ""):
                        found = True
                        break
                except (json.JSONDecodeError, OSError):
                    continue
            if found:
                break
            # Also check directory names
            for entry in plugin_dir.iterdir():
                if entry.is_dir() and marker in entry.name:
                    found = True
                    break
            if found:
                break

        results[plugin_name] = found

    return results


def full_dependency_check(project_root: str | Path) -> dict[str, Any]:
    """Run complete dependency check for a project.

    Returns a structured report of all detected languages, tools, and plugins.
    """
    languages = detect_languages(project_root)
    plugins = detect_plugins()

    tool_status: dict[str, dict[str, dict[str, Any]]] = {}
    for lang in languages:
        tool_status[lang] = check_language_tools(lang)

    missing_tools: list[dict[str, str]] = []
    for lang, tools in tool_status.items():
        for tool_name, info in tools.items():
            if not info["available"]:
                missing_tools.append({
                    "language": lang,
                    "tool": tool_name,
                    "install": info["install"],
                    "role": info["role"],
                })

    return {
        "languages": languages,
        "tools": tool_status,
        "plugins": plugins,
        "missing_tools": missing_tools,
        "all_tools_available": len(missing_tools) == 0,
    }
