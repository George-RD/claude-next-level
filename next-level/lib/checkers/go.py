"""Go checker.

Format: gofmt -w <file>
Lint: go vet ./... + golangci-lint run --fast <file>
Graceful degradation: if tools not installed, skip.
"""

import json
import os
import re
import shutil
import subprocess
from typing import Any


def check(filepath: str) -> dict[str, Any]:
    """Run Go checks on a file."""
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

    # Format with gofmt
    if shutil.which("gofmt"):
        try:
            proc = subprocess.run(
                ["gofmt", "-w", filepath],
                capture_output=True,
                timeout=15,
            )
            result["formatted"] = proc.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # Strip unnecessary comments
    try:
        from comment_stripper import strip_comments
        strip_result = strip_comments(filepath, "go")
        result["comments_stripped"] = strip_result.get("stripped", 0)
    except (ImportError, Exception):
        result["comments_stripped"] = 0

    # Find Go module root
    module_root = _find_go_module_root(filepath)

    # Lint with go vet
    if module_root and shutil.which("go"):
        try:
            proc = subprocess.run(
                ["go", "vet", "./..."],
                capture_output=True,
                text=True,
                timeout=30,
                cwd=module_root,
            )
            if proc.stderr:
                basename = os.path.basename(filepath)
                _parse_go_vet_output(proc.stderr, basename, result)
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # Lint with golangci-lint
    if shutil.which("golangci-lint"):
        try:
            proc = subprocess.run(
                ["golangci-lint", "run", "--out-format", "json", "--fast", filepath],
                capture_output=True,
                text=True,
                timeout=30,
                cwd=module_root or os.path.dirname(filepath),
            )
            if proc.stdout:
                try:
                    lint_result = json.loads(proc.stdout)
                    for issue in lint_result.get("Issues", []):
                        result["findings"].append({
                            "line": issue.get("Pos", {}).get("Line", 0),
                            "column": issue.get("Pos", {}).get("Column", 0),
                            "message": issue.get("Text", ""),
                            "rule": issue.get("FromLinter", ""),
                            "severity": issue.get("Severity", "warning"),
                        })
                except json.JSONDecodeError:
                    pass
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    return result


def _find_go_module_root(filepath: str) -> str | None:
    """Walk up from filepath to find go.mod."""
    current = os.path.dirname(os.path.abspath(filepath))
    while current != os.path.dirname(current):
        if os.path.isfile(os.path.join(current, "go.mod")):
            return current
        current = os.path.dirname(current)
    return None


def _parse_go_vet_output(output: str, target_basename: str, result: dict[str, Any]) -> None:
    """Parse go vet stderr output for findings related to target file."""
    # Pattern: filepath.go:line:col: message
    pattern = re.compile(r"([^:]+\.go):(\d+):(\d+): (.+)")
    for match in pattern.finditer(output):
        filename = os.path.basename(match.group(1))
        if filename == target_basename:
            result["findings"].append({
                "line": int(match.group(2)),
                "column": int(match.group(3)),
                "message": match.group(4),
                "rule": "go-vet",
                "severity": "warning",
            })
