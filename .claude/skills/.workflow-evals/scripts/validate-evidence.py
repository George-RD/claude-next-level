#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

VALID_PACKET_REVIEW_VERDICTS = {"PASS", "WARN", "FAIL", "UNAVAILABLE"}
VALID_LEARNING_STATUS = {"new", "eval-added", "doc-updated", "validator-rule", "rejected", "deferred"}
VALID_MATURITY = {"draft", "recent", "stable", "high-success", "needs-repair"}
VALID_EVAL_SCOPES = {"global", "project"}
VALID_EVAL_RESULTS = {"pass", "fail", "warn", "skip", "error"}


def fail(msg: str) -> int:
    print(f"FAIL {msg}")
    return 1


def validate_maturity(root: Path) -> int:
    path = root / "maturity.json"
    if not path.exists():
        return fail("maturity registry missing")
    data = json.loads(path.read_text())
    required_skills = {"swarm-improve", "simplify", "request-code-review", "deep-review", "apply-review-feedback", "workflow-closeout"}
    missing = required_skills - data.keys()
    if missing:
        return fail(f"maturity registry missing skills: {sorted(missing)}")
    for skill, item in data.items():
        if item.get("state") not in VALID_MATURITY:
            return fail(f"maturity:{skill}: invalid state {item.get('state')!r}")
        for key in ["success_count", "miss_count", "friction_count", "regression_count"]:
            if not isinstance(item.get(key), int) or item.get(key) < 0:
                return fail(f"maturity:{skill}: {key} must be nonnegative integer")
        if not item.get("last_changed"):
            return fail(f"maturity:{skill}: last_changed missing")
    print(f"PASS maturity registry: {len(data)} skills")
    return 0


def state_root() -> Path:
    return Path(os.environ.get("JCODE_SKILL_STATE_DIR", str(Path.home() / ".jcode/skill-state")))


def validate_learning_jsonl(root: Path) -> int:
    path = state_root() / "workflow-learnings.jsonl"
    if not path.exists():
        print("PASS workflow-learnings.jsonl: absent")
        return 0
    failures = 0
    for idx, line in enumerate(path.read_text().splitlines(), start=1):
        if not line.strip():
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError as exc:
            print(f"FAIL workflow-learnings.jsonl:{idx}: invalid JSON: {exc}")
            failures += 1
            continue
        required = {"date", "source", "symptom", "impact", "status"}
        missing = required - item.keys()
        if missing:
            print(f"FAIL workflow-learnings.jsonl:{idx}: missing {sorted(missing)}")
            failures += 1
        if item.get("status") not in VALID_LEARNING_STATUS:
            print(f"FAIL workflow-learnings.jsonl:{idx}: invalid status {item.get('status')!r}")
            failures += 1
    if failures == 0:
        print("PASS workflow-learnings.jsonl")
    return 1 if failures else 0


def validate_usage_jsonl(root: Path) -> int:
    path = state_root() / "skill-usage.jsonl"
    if not path.exists():
        print("PASS skill-usage.jsonl: absent")
        return 0
    failures = 0
    valid_events = {"used", "missed", "candidate", "closeout", "review-finding"}
    for idx, line in enumerate(path.read_text().splitlines(), start=1):
        if not line.strip():
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError as exc:
            print(f"FAIL skill-usage.jsonl:{idx}: invalid JSON: {exc}")
            failures += 1
            continue
        required = {"timestamp", "repo_hash", "skill", "event_type", "trigger", "outcome", "metrics"}
        missing = required - item.keys()
        if missing:
            print(f"FAIL skill-usage.jsonl:{idx}: missing {sorted(missing)}")
            failures += 1
        if item.get("event_type") not in valid_events:
            print(f"FAIL skill-usage.jsonl:{idx}: invalid event_type {item.get('event_type')!r}")
            failures += 1
    if failures == 0:
        print("PASS skill-usage.jsonl")
    return 1 if failures else 0


def eval_run_paths() -> list[Path]:
    root = state_root()
    paths = [root / "eval-runs.jsonl"]
    projects = root / "projects"
    if projects.exists():
        paths.extend(sorted(projects.glob("*/eval-runs.jsonl")))
    return paths


def validate_eval_runs_jsonl(root: Path) -> int:
    paths = [path for path in eval_run_paths() if path.exists()]
    if not paths:
        print("PASS eval-runs.jsonl: absent")
        return 0

    failures = 0
    required = {"timestamp", "scope", "skill", "eval_suite", "case_id", "result", "metrics", "artifact_ref"}
    for path in paths:
        label = path.relative_to(state_root()) if path.is_relative_to(state_root()) else path
        for idx, line in enumerate(path.read_text().splitlines(), start=1):
            if not line.strip():
                continue
            try:
                item = json.loads(line)
            except json.JSONDecodeError as exc:
                print(f"FAIL {label}:{idx}: invalid JSON: {exc}")
                failures += 1
                continue
            missing = required - item.keys()
            if missing:
                print(f"FAIL {label}:{idx}: missing {sorted(missing)}")
                failures += 1
            if item.get("scope") not in VALID_EVAL_SCOPES:
                print(f"FAIL {label}:{idx}: invalid scope {item.get('scope')!r}")
                failures += 1
            if item.get("result") not in VALID_EVAL_RESULTS:
                print(f"FAIL {label}:{idx}: invalid result {item.get('result')!r}")
                failures += 1
            if item.get("scope") == "project" and not item.get("repo_hash"):
                print(f"FAIL {label}:{idx}: project eval run missing repo_hash")
                failures += 1
            if not isinstance(item.get("metrics"), dict):
                print(f"FAIL {label}:{idx}: metrics must be object")
                failures += 1
            artifact_ref = item.get("artifact_ref")
            if not isinstance(artifact_ref, str):
                print(f"FAIL {label}:{idx}: artifact_ref must be string")
                failures += 1
            elif Path(artifact_ref).is_absolute() or artifact_ref.startswith("~"):
                print(f"FAIL {label}:{idx}: artifact_ref must not be an absolute local path")
                failures += 1
            if item.get("scope") == "global" and item.get("repo_path"):
                print(f"FAIL {label}:{idx}: global eval run must not include repo_path")
                failures += 1
    if failures == 0:
        print(f"PASS eval-runs.jsonl: {len(paths)} file(s)")
    return 1 if failures else 0


def validate_packets(root: Path) -> int:
    packet_dir = state_root() / "evidence-packets"
    if not packet_dir.exists():
        print("PASS evidence packets: none present")
        return 0
    failures = 0
    count = 0
    for path in sorted(packet_dir.glob("*.json")):
        count += 1
        item = json.loads(path.read_text())
        required = {"date", "changed_files", "static_validation", "behavior_eval", "adversarial_reviews", "findings", "follow_ups"}
        missing = required - item.keys()
        if missing:
            print(f"FAIL evidence:{path.name}: missing {sorted(missing)}")
            failures += 1
        reviews = item.get("adversarial_reviews", [])
        if len(reviews) < 2:
            print(f"FAIL evidence:{path.name}: expected at least 2 adversarial reviews")
            failures += 1
        models = {r.get("model") for r in reviews}
        if not any("gpt" in str(m).lower() and "5.5" in str(m).lower() for m in models):
            print(f"FAIL evidence:{path.name}: missing GPT 5.5 review or UNAVAILABLE record")
            failures += 1
        if not any("opus" in str(m).lower() and "4.7" in str(m).lower() for m in models):
            print(f"FAIL evidence:{path.name}: missing Opus 4.7 review or UNAVAILABLE record")
            failures += 1
        for r in reviews:
            if r.get("verdict") not in VALID_PACKET_REVIEW_VERDICTS:
                print(f"FAIL evidence:{path.name}: bad review verdict {r.get('verdict')!r}")
                failures += 1
    if failures == 0:
        print(f"PASS evidence packets: {count} packet(s)")
    return 1 if failures else 0


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    failures = (
        validate_maturity(root)
        + validate_learning_jsonl(root)
        + validate_usage_jsonl(root)
        + validate_eval_runs_jsonl(root)
        + validate_packets(root)
    )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
