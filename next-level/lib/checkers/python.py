"""Python checker.

Format: ruff format <file>
Lint: ruff check <file>
Type check: basedpyright <file> (if available)
Graceful degradation: if tools not installed, skip.
"""

import json
import shutil
import subprocess
from typing import Any

from . import check_file_length, run_comment_strip


def check(filepath: str) -> dict[str, Any]:
    """Run Python checks on a file."""
    result: dict[str, Any] = {"findings": [], "formatted": False}

    check_file_length(filepath, result)

    # Format with ruff
    ruff_path = shutil.which("ruff")
    if ruff_path:
        try:
            proc = subprocess.run(
                [ruff_path, "format", filepath],
                capture_output=True,
                timeout=15,
            )
            result["formatted"] = proc.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # Strip unnecessary comments (before linting so line numbers match final file)
    run_comment_strip(filepath, "python", result)

    # Lint with ruff (after comment stripping so findings match final content)
    if ruff_path:
        try:
            proc = subprocess.run(
                [ruff_path, "check", "--output-format", "json", filepath],
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

    # Type check with basedpyright
    basedpyright_path = shutil.which("basedpyright")
    if basedpyright_path:
        try:
            proc = subprocess.run(
                [basedpyright_path, "--outputjson", filepath],
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
