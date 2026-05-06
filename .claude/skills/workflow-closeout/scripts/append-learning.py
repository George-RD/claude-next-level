#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path

VALID = {"new", "eval-added", "doc-updated", "validator-rule", "rejected", "deferred"}


def main() -> int:
    p = argparse.ArgumentParser(description="Append a workflow learning JSONL record")
    p.add_argument("--source", required=True)
    p.add_argument("--symptom", required=True)
    p.add_argument("--impact", required=True)
    p.add_argument("--status", default="new", choices=sorted(VALID))
    p.add_argument("--evidence", action="append", default=[])
    p.add_argument("--next-action", default="")
    p.add_argument("--related-eval", default="")
    p.add_argument("--output", default=str(Path.home() / ".jcode/skill-state/workflow-learnings.jsonl"))
    args = p.parse_args()
    item = {
        "date": date.today().isoformat(),
        "source": args.source,
        "symptom": args.symptom,
        "impact": args.impact,
        "status": args.status,
        "evidence": args.evidence,
        "next_action": args.next_action,
        "related_eval": args.related_eval,
    }
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("a") as fh:
        fh.write(json.dumps(item, sort_keys=True) + "\n")
    print(json.dumps(item, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
