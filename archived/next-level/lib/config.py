"""Configuration reader for next-level.

Reads and writes ~/.next-level/config.json.

Schema:
{
  "setup_complete": bool,
  "last_updated": "ISO timestamp",
  "project_root": "/path/to/project",
  "languages_detected": ["python", "typescript", ...],
  "features_enabled": {
    "file_checker": true,
    "comment_stripping": true,
    "tdd_enforcement": true,
    ...
  },
  "plugins_available": {
    "omega_memory": false,
    "coderabbit": false,
    ...
  },
  "linters": {
    "python": {"formatter": "ruff", "linter": "ruff", "type_checker": "basedpyright"},
    "typescript": {"formatter": "prettier", "linter": "eslint"},
    ...
  },
  "trust_level": "balanced",       // "cautious" | "balanced" | "autonomous"
  "checkpoint_depth": "medium",    // "full" | "medium" | "light"
}
"""

import copy
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

CONFIG_PATH = Path(os.environ.get("NEXT_LEVEL_CONFIG", Path.home() / ".next-level" / "config.json"))

DEFAULT_CONFIG: dict[str, Any] = {
    "setup_complete": False,
    "last_updated": "",
    "project_root": "",
    "languages_detected": [],
    "features_enabled": {
        "file_checker": True,
        "comment_stripping": True,
        "tdd_enforcement": True,
    },
    "plugins_available": {
        "omega_memory": False,
        "coderabbit": False,
    },
    "linters": {},
    "trust_level": "balanced",
    "checkpoint_depth": "medium",
}

TRUST_LEVELS = ("cautious", "balanced", "autonomous")
CHECKPOINT_DEPTHS = ("full", "medium", "light")


def config_path() -> Path:
    """Get the path to the next-level config file."""
    return CONFIG_PATH


def exists() -> bool:
    """Check if the config file exists."""
    return config_path().is_file()


def read() -> dict[str, Any]:
    """Read and return the config, falling back to defaults on error."""
    if not exists():
        return copy.deepcopy(DEFAULT_CONFIG)
    try:
        with open(config_path(), encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return copy.deepcopy(DEFAULT_CONFIG)


def write(config: dict[str, Any]) -> None:
    """Write config to disk with a timestamp update."""
    config["last_updated"] = datetime.now(timezone.utc).isoformat()
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)
        f.write("\n")


def setup_complete() -> bool:
    """Check if initial setup has been completed."""
    return read().get("setup_complete", False)


def languages() -> list[str]:
    """Get the list of detected languages for the project."""
    return read().get("languages_detected", [])


def feature_enabled(name: str) -> bool:
    """Check if a feature is enabled by name."""
    return read().get("features_enabled", {}).get(name, False)


def plugin_available(name: str) -> bool:
    """Check if a Claude Code plugin is available by name."""
    return read().get("plugins_available", {}).get(name, False)


def linters_for(language: str) -> dict[str, str]:
    """Get linter/formatter configuration for a specific language."""
    return read().get("linters", {}).get(language, {})


def trust_level() -> str:
    """Get the current trust level (cautious, balanced, or autonomous)."""
    return read().get("trust_level", "balanced")


def checkpoint_depth() -> str:
    """Get the checkpoint depth setting (full, medium, or light)."""
    return read().get("checkpoint_depth", "medium")


def checkpoint_depth_for_task(task_index: int, total_tasks: int) -> str:
    """Determine checkpoint depth based on task position and trust level.

    Trust auto-escalates within an epic as tasks succeed:
    - First 2-3 tasks: full review
    - Middle tasks: medium review
    - Final tasks: light review

    Trust level overrides:
    - cautious: always full
    - balanced: auto-escalate as described
    - autonomous: always light (unless FLAG_FOR_HUMAN)
    """
    level = trust_level()
    if level == "cautious":
        return "full"
    if level == "autonomous":
        return "light"

    # balanced: auto-escalate
    # For small epics (<=5 tasks), only use full and light
    if task_index < 3:
        return "full"
    elif total_tasks <= 5 or task_index >= total_tasks - 2:
        return "light"
    else:
        return "medium"
