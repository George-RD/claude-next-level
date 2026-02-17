"""Swift checker.

Format: swiftformat <file>
Lint: swiftlint lint --path <file>
Graceful degradation: if tools not installed, skip.
"""

import os
import re
import shutil
import subprocess
from typing import Any


def check(filepath: str) -> dict[str, Any]:
    """Run Swift checks on a file."""
    result: dict[str, Any] = {"findings": [], "formatted": False}

    # File length check
    try:
        with open(filepath) as f:
            lines = f.readlines()
        line_count = len(lines)
        if line_count > 500:
            result["length_warning"] = f"File is {line_count} lines (>500) — consider splitting"
        elif line_count > 300:
            result["length_warning"] = f"File is {line_count} lines (>300) — getting long"
    except OSError:
        pass

    # Format with swiftformat
    if shutil.which("swiftformat"):
        try:
            subprocess.run(
                ["swiftformat", filepath],
                capture_output=True,
                timeout=15,
            )
            result["formatted"] = True
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # Strip unnecessary comments
    from comment_stripper import strip_comments
    strip_result = strip_comments(filepath, "swift")
    result["comments_stripped"] = strip_result.get("stripped", 0)

    # Lint with swiftlint
    if shutil.which("swiftlint"):
        try:
            proc = subprocess.run(
                ["swiftlint", "lint", "--path", filepath, "--reporter", "json"],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if proc.stdout:
                try:
                    import json
                    lint_results = json.loads(proc.stdout)
                    for issue in lint_results:
                        result["findings"].append({
                            "line": issue.get("line", 0),
                            "column": issue.get("character", 0),
                            "message": issue.get("reason", ""),
                            "rule": issue.get("rule_id", ""),
                            "severity": issue.get("severity", "warning").lower(),
                        })
                except (json.JSONDecodeError, ImportError):
                    # Fallback: parse text output
                    _parse_swiftlint_text(proc.stdout, result)
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    return result


def _parse_swiftlint_text(output: str, result: dict[str, Any]) -> None:
    """Parse swiftlint text output as fallback."""
    # Pattern: filepath:line:col: severity: message (rule)
    pattern = re.compile(r":(\d+):(\d+): (\w+): (.+?) \((\w+)\)")
    for match in pattern.finditer(output):
        result["findings"].append({
            "line": int(match.group(1)),
            "column": int(match.group(2)),
            "message": match.group(4),
            "rule": match.group(5),
            "severity": match.group(3).lower(),
        })
