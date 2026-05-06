#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path

VALID_EVENTS = {"used", "missed", "candidate", "closeout", "review-finding"}
VALID_OUTCOMES = {"success", "partial", "failed", "skipped", "false-positive", "deferred"}


def default_state_dir() -> Path:
    return Path(os.environ.get("JCODE_SKILL_STATE_DIR", str(Path.home() / ".jcode/skill-state")))


def hash_repo(path: str) -> str:
    return hashlib.sha256(path.encode("utf-8")).hexdigest()[:16]


def main() -> int:
    p = argparse.ArgumentParser(description="Append a cross-repo Jcode skill usage event")
    p.add_argument("--skill", required=True)
    p.add_argument("--event-type", required=True, choices=sorted(VALID_EVENTS))
    p.add_argument("--repo-path", default=os.getcwd())
    p.add_argument("--trigger", default="inferred")
    p.add_argument("--task-kind", default="")
    p.add_argument("--scale", default="")
    p.add_argument("--outcome", default="success", choices=sorted(VALID_OUTCOMES))
    p.add_argument("--tool-calls", type=int, default=0)
    p.add_argument("--review-passes", type=int, default=0)
    p.add_argument("--simplify-passes", type=int, default=0)
    p.add_argument("--followups-created", type=int, default=0)
    p.add_argument("--note", default="")
    p.add_argument("--output", default="")
    args = p.parse_args()

    repo_path = str(Path(args.repo_path).resolve())
    item = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "repo_path": repo_path,
        "repo_hash": hash_repo(repo_path),
        "skill": args.skill,
        "event_type": args.event_type,
        "trigger": args.trigger,
        "task_kind": args.task_kind,
        "scale": args.scale,
        "outcome": args.outcome,
        "metrics": {
            "tool_calls": args.tool_calls,
            "review_passes": args.review_passes,
            "simplify_passes": args.simplify_passes,
            "followups_created": args.followups_created,
        },
        "note": args.note,
    }
    out = Path(args.output) if args.output else default_state_dir() / "skill-usage.jsonl"
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("a") as fh:
        fh.write(json.dumps(item, sort_keys=True) + "\n")
    print(json.dumps(item, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
