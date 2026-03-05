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

from . import check_file_length, find_project_root, run_comment_strip


def check(filepath: str) -> dict[str, Any]:
    """Run Go checks on a file."""
    result: dict[str, Any] = {"findings": [], "formatted": False}

    check_file_length(filepath, result)

    # Format with gofmt
    gofmt_path = shutil.which("gofmt")
    if gofmt_path:
        try:
            proc = subprocess.run(
                [gofmt_path, "-w", filepath],
                capture_output=True,
                timeout=15,
            )
            result["formatted"] = proc.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # Strip unnecessary comments
    run_comment_strip(filepath, "go", result)

    # Find Go module root
    module_root = find_project_root(filepath, "go.mod")

    # Lint with go vet
    go_path = shutil.which("go")
    if module_root and go_path:
        try:
            proc = subprocess.run(
                [go_path, "vet", "./..."],
                capture_output=True,
                text=True,
                timeout=30,
                cwd=module_root,
            )
            if proc.stderr:
                rel_path = os.path.relpath(os.path.abspath(filepath), module_root)
                _parse_go_vet_output(proc.stderr, rel_path, result)
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # Lint with golangci-lint
    golangci_path = shutil.which("golangci-lint")
    if golangci_path:
        try:
            proc = subprocess.run(
                [golangci_path, "run", "--out-format", "json", "--fast", filepath],
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


def _parse_go_vet_output(output: str, target_rel_path: str, result: dict[str, Any]) -> None:
    """Parse go vet stderr output for findings related to target file."""
    # Pattern: filepath.go:line:col: message
    pattern = re.compile(r"(.+?\.go):(\d+):(\d+): (.+)")
    for match in pattern.finditer(output):
        file_path = match.group(1)
        if file_path == target_rel_path or file_path.endswith("/" + target_rel_path):
            result["findings"].append({
                "line": int(match.group(2)),
                "column": int(match.group(3)),
                "message": match.group(4),
                "rule": "go-vet",
                "severity": "warning",
            })
