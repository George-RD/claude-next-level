"""TypeScript/JavaScript checker.

Format: prettier --write <file>
Lint: eslint --format json <file>
File length warnings: >300 lines warn, >500 lines critical
Graceful degradation: if tools not installed, skip.
"""

import json
import shutil
import subprocess
from typing import Any

from . import check_file_length, run_comment_strip


def check(filepath: str) -> dict[str, Any]:
    """Run TypeScript/JavaScript checks on a file."""
    result: dict[str, Any] = {"findings": [], "formatted": False}

    check_file_length(filepath, result)

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
    run_comment_strip(filepath, "typescript", result)

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
