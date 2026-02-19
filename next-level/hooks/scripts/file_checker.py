#!/usr/bin/env python3
"""File checker — PostToolUse hook for Edit|Write.

Reads hook input JSON, extracts file path, detects language, routes to
language-specific checker. Exits 2 with findings for non-blocking feedback.
"""

import json
import os
import sys

# Add lib to path
PLUGIN_ROOT = os.environ.get("CLAUDE_PLUGIN_ROOT", os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(PLUGIN_ROOT, "lib"))

from checkers import check_file


def main() -> int:
    """Dispatch file checks for PostToolUse hook events."""
    # Read hook input from stdin
    try:
        raw = sys.stdin.read()
        hook_input = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        return 0  # Can't parse input, skip silently

    tool_name = hook_input.get("tool_name", "")

    # Only check Edit and Write tools
    if tool_name not in ("Edit", "Write"):
        return 0

    tool_input = hook_input.get("tool_input", {})
    file_path = tool_input.get("file_path", "")

    if not file_path:
        return 0

    # Skip non-existent files (file might have been deleted)
    if not os.path.isfile(file_path):
        return 0

    # Guard against out-of-workspace paths (including symlinks)
    real_path = os.path.realpath(file_path)
    workspace = os.path.realpath(os.getcwd())
    if not real_path.startswith(workspace + os.sep) and real_path != workspace:
        return 0

    # Run checks using the resolved path for consistency with the guard
    result = check_file(real_path)

    if result.get("skipped"):
        return 0

    # Collect findings
    findings = result.get("findings", [])
    formatted = result.get("formatted", False)
    stripped = result.get("comments_stripped", 0)

    length_warning = result.get("length_warning")

    if not findings and not formatted and not stripped and not length_warning:
        return 0

    # Build feedback message
    parts = []
    basename = os.path.basename(real_path)

    if formatted:
        parts.append(f"Formatted {basename}")

    if stripped:
        parts.append(f"Stripped {stripped} unnecessary comment(s)")

    if findings:
        parts.append(f"{len(findings)} issue(s) found:")
        for f in findings[:10]:  # Cap at 10 findings
            severity = f.get("severity", "warning")
            line = f.get("line", "?")
            msg = f.get("message", "")
            parts.append(f"  [{severity}] line {line}: {msg}")
        if len(findings) > 10:
            parts.append(f"  ... and {len(findings) - 10} more")

    if length_warning:
        parts.append(length_warning)

    message = " | ".join(parts) if len(parts) <= 2 else "\n".join(parts)

    print(json.dumps({"result": message}))
    return 2  # Non-blocking feedback


if __name__ == "__main__":
    sys.exit(main())
