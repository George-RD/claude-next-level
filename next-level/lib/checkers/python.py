"""Python checker.

Format: ruff format <file>
Lint: ruff check <file>
Type check: basedpyright <file> (if available)
Graceful degradation: if tools not installed, skip.
"""

import json
import os
import re
import shutil
import subprocess
from typing import Any


def check(filepath: str) -> dict[str, Any]:
    """Run Python checks on a file."""
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
    except OSError:
        pass

    # Format with ruff
    if shutil.which("ruff"):
        try:
            proc = subprocess.run(
                ["ruff", "format", filepath],
                capture_output=True,
                timeout=15,
            )
            result["formatted"] = proc.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

        # Lint with ruff
        try:
            proc = subprocess.run(
                ["ruff", "check", "--output-format", "json", filepath],
                capture_output=True,
                text=True,
                timeout=15,
            )
            if proc.stdout:
                try:
                    ruff_results = json.loads(proc.stdout)
                    for diag in ruff_results:
                        result["findings"].append({
                            "line": diag.get("location", {}).get("row", 0),
                            "column": diag.get("location", {}).get("column", 0),
                            "message": diag.get("message", ""),
                            "rule": diag.get("code", ""),
                            "severity": "error" if diag.get("code", "").startswith(("E", "F")) else "warning",
                        })
                except json.JSONDecodeError:
                    pass
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # Strip unnecessary comments
    try:
        from comment_stripper import strip_comments
        strip_result = strip_comments(filepath, "python")
        result["comments_stripped"] = strip_result.get("stripped", 0)
    except (ImportError, Exception):
        result["comments_stripped"] = 0

    # Type check with basedpyright
    if shutil.which("basedpyright"):
        try:
            proc = subprocess.run(
                ["basedpyright", "--outputjson", filepath],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if proc.stdout:
                try:
                    pyright_results = json.loads(proc.stdout)
                    for diag in pyright_results.get("generalDiagnostics", []):
                        severity = diag.get("severity", "information")
                        if severity in ("error", "warning"):
                            result["findings"].append({
                                "line": diag.get("range", {}).get("start", {}).get("line", 0) + 1,
                                "message": diag.get("message", ""),
                                "rule": diag.get("rule", ""),
                                "severity": severity,
                            })
                except json.JSONDecodeError:
                    pass
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    return result
