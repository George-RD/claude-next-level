"""TypeScript/JavaScript checker.

Format: prettier --write <file>
Lint: eslint --format json <file>
File length warnings: >300 lines warn, >500 lines critical
Graceful degradation: if tools not installed, skip.
"""

import json
import os
import shutil
import subprocess
from typing import Any


def check(filepath: str) -> dict[str, Any]:
    """Run TypeScript/JavaScript checks on a file."""
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

    # Format with prettier
    if shutil.which("prettier"):
        try:
            proc = subprocess.run(
                ["prettier", "--write", filepath],
                capture_output=True,
                timeout=15,
            )
            result["formatted"] = proc.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # Strip unnecessary comments
    try:
        from comment_stripper import strip_comments
        strip_result = strip_comments(filepath, "typescript")
        result["comments_stripped"] = strip_result.get("stripped", 0)
    except ImportError:
        result["comments_stripped"] = 0
    except Exception as exc:
        result["comments_stripped"] = 0
        result["comment_strip_error"] = str(exc)

    # Lint with eslint
    if shutil.which("eslint"):
        try:
            proc = subprocess.run(
                ["eslint", "--format", "json", filepath],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if proc.stdout:
                try:
                    eslint_results = json.loads(proc.stdout)
                    for file_result in eslint_results:
                        for msg in file_result.get("messages", []):
                            result["findings"].append({
                                "line": msg.get("line", 0),
                                "column": msg.get("column", 0),
                                "message": msg.get("message", ""),
                                "rule": msg.get("ruleId", ""),
                                "severity": "error" if msg.get("severity") == 2 else "warning",
                            })
                except json.JSONDecodeError:
                    pass
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    return result
