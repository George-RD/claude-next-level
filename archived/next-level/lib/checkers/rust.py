"""Rust checker.

Format: rustfmt <file>
Lint: cargo clippy (project-level, not per-file)
Graceful degradation: if tools not installed, skip.
"""

import json
import os
import shutil
import subprocess
from typing import Any

from . import check_file_length, find_project_root, run_comment_strip


def check(filepath: str) -> dict[str, Any]:
    """Run Rust checks on a file."""
    result: dict[str, Any] = {"findings": [], "formatted": False}

    check_file_length(filepath, result)

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
    run_comment_strip(filepath, "rust", result)

    # Lint with cargo clippy (project-level)
    project_root = find_project_root(filepath, "Cargo.toml")
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
