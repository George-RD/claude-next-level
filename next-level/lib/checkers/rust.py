"""Rust checker.

Format: rustfmt <file>
Lint: cargo clippy (project-level, not per-file)
Graceful degradation: if tools not installed, skip.
"""

import json
import os
import re
import shutil
import subprocess
from typing import Any


def check(filepath: str) -> dict[str, Any]:
    """Run Rust checks on a file."""
    result: dict[str, Any] = {"findings": [], "formatted": False}

    # File length check
    try:
        with open(filepath, encoding="utf-8") as f:
            lines = f.readlines()
        line_count = len(lines)
        if line_count > 500:
            result["length_warning"] = f"File is {line_count} lines (>500) — consider splitting"
        elif line_count > 300:
            result["length_warning"] = f"File is {line_count} lines (>300) — getting long"
    except (OSError, UnicodeDecodeError):
        pass

    # Format with rustfmt
    rustfmt_path = shutil.which("rustfmt")
    if rustfmt_path:
        try:
            proc = subprocess.run(
                [rustfmt_path, filepath],
                capture_output=True,
                timeout=15,
            )
            result["formatted"] = proc.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # Strip unnecessary comments
    try:
        from comment_stripper import strip_comments
        strip_result = strip_comments(filepath, "rust")
        result["comments_stripped"] = strip_result.get("stripped", 0)
    except (ImportError, Exception):
        result["comments_stripped"] = 0

    # Lint with cargo clippy (project-level)
    # Find project root by looking for Cargo.toml
    project_root = _find_cargo_root(filepath)
    cargo_path = shutil.which("cargo")
    if project_root and cargo_path:
        try:
            proc = subprocess.run(
                [cargo_path, "clippy", "--message-format=json", "--", "-W", "clippy::all"],
                capture_output=True,
                text=True,
                timeout=60,
                cwd=project_root,
            )
            # Parse JSON messages (one per line)
            abs_filepath = os.path.normpath(os.path.abspath(filepath))
            for line in proc.stdout.splitlines():
                try:
                    msg = json.loads(line)
                    if msg.get("reason") == "compiler-message":
                        message = msg.get("message", {})
                        # Only include findings for the specific file
                        for span in message.get("spans", []):
                            span_path = os.path.normpath(os.path.join(project_root, span.get("file_name", "")))
                            if span_path == abs_filepath:
                                result["findings"].append({
                                    "line": span.get("line_start", 0),
                                    "column": span.get("column_start", 0),
                                    "message": message.get("message", ""),
                                    "rule": message.get("code", {}).get("code", "") if message.get("code") else "",
                                    "severity": message.get("level", "warning"),
                                })
                except json.JSONDecodeError:
                    continue
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    return result


def _find_cargo_root(filepath: str) -> str | None:
    """Walk up from filepath to find Cargo.toml."""
    current = os.path.dirname(os.path.abspath(filepath))
    while current != os.path.dirname(current):  # Stop at filesystem root
        if os.path.isfile(os.path.join(current, "Cargo.toml")):
            return current
        current = os.path.dirname(current)
    return None
