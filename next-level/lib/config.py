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
    return CONFIG_PATH


def exists() -> bool:
    return config_path().is_file()


def read() -> dict[str, Any]:
    if not exists():
        return dict(DEFAULT_CONFIG)
    with open(config_path()) as f:
        return json.load(f)


def write(config: dict[str, Any]) -> None:
    config["last_updated"] = datetime.now(timezone.utc).isoformat()
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")


def setup_complete() -> bool:
    return read().get("setup_complete", False)


def languages() -> list[str]:
    return read().get("languages_detected", [])


def feature_enabled(name: str) -> bool:
    return read().get("features_enabled", {}).get(name, False)


def plugin_available(name: str) -> bool:
    return read().get("plugins_available", {}).get(name, False)


def linters_for(language: str) -> dict[str, str]:
    return read().get("linters", {}).get(language, {})


def trust_level() -> str:
    return read().get("trust_level", "balanced")


def checkpoint_depth() -> str:
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
    if task_index < 3:
        return "full"
    elif task_index >= total_tasks - 2:
        return "light"
    else:
        return "medium"
