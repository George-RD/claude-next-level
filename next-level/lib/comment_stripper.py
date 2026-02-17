"""Comment stripping engine for next-level.

Strips unnecessary comments while preserving:
- Docstrings and documentation comments (///, /** */, ''', \""")
- Type annotations (# type:, // @ts-, /// <reference)
- Linter directives (# noqa, # pylint:, // eslint-disable, // swiftlint:)
- TODOs, FIXMEs, NOTEs, HACKs, WARNINGs
- Shebangs (#!)
- License headers (first comment block if contains "license", "copyright", "MIT", etc.)

Python: uses tokenize module for accurate parsing.
TypeScript/Swift/Rust/Go: regex-based with language-specific patterns.
"""

import io
import re
import tokenize
from pathlib import Path
from typing import Any

# Preserved comment patterns (case-insensitive)
PRESERVED_MARKERS = re.compile(
    r"(?i)(TODO|FIXME|NOTE|HACK|WARNING|XXX|SAFETY|INVARIANT|IMPORTANT)",
)

LICENSE_MARKERS = re.compile(
    r"(?i)(license|copyright|MIT|Apache|BSD|GPL|Mozilla|ISC|SPDX)",
)


def strip_comments(filepath: str, language: str) -> dict[str, Any]:
    """Strip unnecessary comments from a file.

    Returns dict with:
        stripped: int — number of comments removed
        modified: bool — whether the file was changed
    """
    try:
        with open(filepath, encoding="utf-8") as f:
            original = f.read()
    except OSError:
        return {"stripped": 0, "modified": False}

    if language == "python":
        result = _strip_python(filepath, original)
    elif language in ("typescript", "javascript"):
        result = _strip_c_style(original, doc_prefix="/**")
    elif language == "swift":
        result = _strip_c_style(original, doc_prefix="///")
    elif language == "rust":
        result = _strip_c_style(original, doc_prefix="///")
    elif language == "go":
        result = _strip_c_style(original, doc_prefix="//", preserve_godoc=True)
    else:
        return {"stripped": 0, "modified": False}

    if result["modified"]:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(result["content"])

    return {"stripped": result["stripped"], "modified": result["modified"]}


def _strip_python(filepath: str, source: str) -> dict[str, Any]:
    """Strip Python comments using tokenize for accuracy."""
    try:
        tokens = list(tokenize.generate_tokens(io.StringIO(source).readline))
    except tokenize.TokenError:
        return {"stripped": 0, "modified": False, "content": source}

    stripped = 0
    # Track which lines to remove comments from
    lines = source.splitlines(keepends=True)
    remove_lines: set[int] = set()  # 0-indexed line numbers

    for tok in tokens:
        if tok.type != tokenize.COMMENT:
            continue

        comment = tok.string
        line_no = tok.start[0] - 1  # 0-indexed

        # Preserve shebangs
        if comment.startswith("#!") and line_no == 0:
            continue

        # Preserve type annotations
        if "type:" in comment or "type: ignore" in comment:
            continue

        # Preserve noqa, pylint directives
        if any(d in comment for d in ("noqa", "pylint:", "type: ignore", "pragma:")):
            continue

        # Preserve TODOs and similar markers
        if PRESERVED_MARKERS.search(comment):
            continue

        # Preserve license headers (first comment block)
        if line_no < 10 and LICENSE_MARKERS.search(comment):
            continue

        # This comment should be stripped
        stripped += 1

        # Check if the comment is the entire line (after stripping whitespace)
        if line_no >= len(lines):
            continue
        line = lines[line_no]
        stripped_line = line.lstrip()
        if stripped_line.startswith("#"):
            # Whole-line comment — mark for removal
            remove_lines.add(line_no)
        else:
            # Inline comment — remove just the comment part
            col = tok.start[1]
            # Remove trailing whitespace before the comment too
            before = lines[line_no][:col].rstrip()
            newline = "\n" if line.endswith("\n") else ""
            lines[line_no] = before + newline

    # Remove whole-line comments (iterate in reverse to preserve indices)
    new_lines = [line for i, line in enumerate(lines) if i not in remove_lines]
    content = "".join(new_lines)

    return {
        "stripped": stripped,
        "modified": stripped > 0,
        "content": content,
    }


def _strip_c_style(
    source: str,
    doc_prefix: str = "/**",
    preserve_godoc: bool = False,
) -> dict[str, Any]:
    """Strip C-style comments (//, /* */) with language-specific preservation."""
    lines = source.splitlines(keepends=True)
    stripped = 0
    new_lines: list[str] = []
    in_block_comment = False
    block_is_preserved = False

    for i, line in enumerate(lines):
        stripped_line = line.lstrip()

        # Handle block comments
        if in_block_comment:
            if "*/" in line:
                in_block_comment = False
                if not block_is_preserved:
                    stripped += 1
                    continue
            if not block_is_preserved:
                continue
            new_lines.append(line)
            continue

        # Start of block comment
        if "/*" in stripped_line and not stripped_line.startswith("//"):
            # Check if it's a doc comment
            if stripped_line.startswith("/**") or stripped_line.startswith("/*!"):
                block_is_preserved = True
            elif LICENSE_MARKERS.search(line):
                block_is_preserved = True
            elif PRESERVED_MARKERS.search(line):
                block_is_preserved = True
            else:
                block_is_preserved = False

            if "*/" not in line.split("/*", 1)[1]:
                in_block_comment = True
                if block_is_preserved:
                    new_lines.append(line)
                else:
                    stripped += 1
                continue
            else:
                # Single-line block comment
                if not block_is_preserved:
                    stripped += 1
                    # Remove just the comment if there's code before it
                    before = line.split("/*")[0].rstrip()
                    if before:
                        new_lines.append(before + "\n")
                    continue
                new_lines.append(line)
                continue

        # Single-line comments
        if stripped_line.startswith("//"):
            # Preserve doc comments
            if stripped_line.startswith("///") or stripped_line.startswith("//!"):
                new_lines.append(line)
                continue

            # Preserve shebangs (shouldn't be // but just in case)
            if stripped_line.startswith("#!") and i == 0:
                new_lines.append(line)
                continue

            # Preserve linter directives
            directive_patterns = [
                "eslint-disable", "eslint-enable", "@ts-",
                "swiftlint:", "nolint", "nosec",
                "SAFETY:", "INVARIANT:",
            ]
            if any(p in stripped_line for p in directive_patterns):
                new_lines.append(line)
                continue

            # Preserve TODOs and markers
            if PRESERVED_MARKERS.search(stripped_line):
                new_lines.append(line)
                continue

            # Preserve license headers
            if i < 10 and LICENSE_MARKERS.search(stripped_line):
                new_lines.append(line)
                continue

            # Preserve godoc comments (Go: comment directly above a declaration)
            if preserve_godoc and i + 1 < len(lines):
                next_line = lines[i + 1].lstrip()
                if next_line and (
                    next_line.startswith("func ") or
                    next_line.startswith("type ") or
                    next_line.startswith("var ") or
                    next_line.startswith("const ") or
                    next_line.startswith("package ")
                ):
                    new_lines.append(line)
                    continue

            # Strip this comment
            stripped += 1
            continue

        # Handle inline comments (code // comment)
        if "//" in line and not line.lstrip().startswith("//"):
            # Check if // is inside a string
            if not _in_string(line, line.index("//")):
                comment_part = line[line.index("//"):]
                # Check preservation rules on the comment part
                if (PRESERVED_MARKERS.search(comment_part) or
                        any(p in comment_part for p in ("eslint-disable", "@ts-", "nolint"))):
                    new_lines.append(line)
                    continue
                # Strip inline comment
                before = line[:line.index("//")].rstrip()
                stripped += 1
                new_lines.append(before + "\n")
                continue

        new_lines.append(line)

    content = "".join(new_lines)
    return {
        "stripped": stripped,
        "modified": stripped > 0,
        "content": content,
    }


def _in_string(line: str, pos: int) -> bool:
    """Check if position in line is inside a string literal (simple heuristic)."""
    in_single = False
    in_double = False
    in_backtick = False
    escaped = False

    for i, ch in enumerate(line):
        if i >= pos:
            break
        if escaped:
            escaped = False
            continue
        if ch == "\\":
            escaped = True
            continue
        if ch == "'" and not in_double and not in_backtick:
            in_single = not in_single
        elif ch == '"' and not in_single and not in_backtick:
            in_double = not in_double
        elif ch == "`" and not in_single and not in_double:
            in_backtick = not in_backtick

    return in_single or in_double or in_backtick
