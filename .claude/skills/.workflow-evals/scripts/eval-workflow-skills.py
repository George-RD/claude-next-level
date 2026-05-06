#!/usr/bin/env python3
"""Deterministic evals for Jcode workflow skills.

Runs two gates:
1. Documentation contract checks: required phrases and forbidden phrases.
2. Scenario/golden-decision checks: a small policy oracle maps workflow signals to
   expected decisions so over-process and under-process regressions are caught.

This still does not prove an LLM will follow the skills. It is the fast,
deterministic gate before independent adversarial model review.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


def decide(signals: dict[str, Any]) -> dict[str, Any]:
    scale = signals.get("scale", "medium")
    feedback_scale = signals.get("feedback_delta_scale")
    risky = any(
        signals.get(k)
        for k in [
            "phase_checkpoint",
            "process_sensitive",
            "security",
            "destructive",
            "data_loss_risk",
            "payment",
            "external_commitment",
            "pre_submit",
        ]
    )
    decision: dict[str, Any] = {
        "entrypoint": "request-code-review",
        "review_mode": "standard",
        "review_target": "diff",
        "subagents": True,
        "simplify": "run" if scale in {"medium", "large"} else "skip",
        "repeat_simplify": feedback_scale in {"medium", "large"},
        "repeat_simplify_limit": 1 if feedback_scale in {"medium", "large"} else 0,
        "deep_review": False,
        "rerun_gates": bool(feedback_scale),
        "max_review_passes": 1,
        "lens_count_min": 2 if scale == "medium" and signals.get("cheap_models_available") else 1,
        "lens_count_max": 4 if scale == "medium" and signals.get("cheap_models_available") else 1,
        "create_follow_up": False,
        "expand_scope": False,
        "plan_review_before_code": False,
        "file_ownership_map": bool(signals.get("parallel_tasks")),
        "serialize_overlaps": bool(signals.get("overlapping_file_claims")),
        "max_workers": 4,
        "apply_feedback": True,
        "choose_no_change": False,
        "user_approval_required": False,
        "static_validation_required": False,
        "behavior_eval_required": False,
        "gpt_5_5_review_required": False,
        "opus_4_7_review_required": False,
        "evidence_packet_required": False,
        "log_signal": False,
        "update_skill": False,
        "add_eval": False,
        "create_persona": False,
        "trim_or_clarify": False,
        "prefer_simplification": True,
        "add_process": False,
        "edit_diagram": False,
        "reject_change": False,
        "evidence_threshold": "normal",
        "log_usage": False,
        "usage_event_type": "",
        "candidate_skill": False,
        "create_skill": False,
    }

    recurrence = int(signals.get("recurrence_count", 0) or 0)

    if signals.get("skill_used") and signals.get("usage_logging_relevant"):
        decision.update({"log_usage": True, "usage_event_type": "used"})
    if signals.get("missed_skill") or signals.get("skill_should_have_been_used"):
        decision.update({"log_usage": True, "usage_event_type": "missed", "update_skill": False})
    if signals.get("repeated_manual_work") and recurrence >= 2 and signals.get("non_obvious"):
        decision.update({"log_usage": True, "usage_event_type": "candidate", "candidate_skill": True, "create_skill": False})

    # Closeout learning decisions. These are intentionally conservative:
    # log broadly, update narrowly, prefer simplification over new process.
    closeout_signal = signals.get("closeout_signal")
    recurrence = int(signals.get("recurrence_count", 0) or 0)
    maturity = signals.get("skill_maturity", "recent")
    severity = signals.get("severity", "minor")
    if closeout_signal:
        decision["log_signal"] = True
    if closeout_signal in {"preference", "false_positive"}:
        decision.update({"update_skill": False, "add_eval": False, "create_persona": False, "add_process": False})
    if closeout_signal == "real_miss" and signals.get("finding_evidenced"):
        repeated = recurrence >= 2
        high_severity = severity in {"major", "critical", "high"}
        if maturity == "high-success" and not (repeated and high_severity):
            decision.update({"evidence_threshold": "strong_repeated", "update_skill": False, "add_eval": False})
        elif repeated or high_severity:
            decision.update({"add_eval": True, "update_skill": False})
    if closeout_signal == "process_friction" and recurrence >= 2:
        decision.update({"trim_or_clarify": True, "prefer_simplification": True, "add_process": False})
    if closeout_signal == "unclear_instruction" and signals.get("diagram_ambiguity"):
        decision.update({"edit_diagram": True, "add_process": False})
    if signals.get("persona_gap") and recurrence >= 3 and signals.get("finding_evidenced") and signals.get("existing_lens_covers_gap") is False:
        decision.update({"create_persona": True, "add_eval": True})
    if signals.get("proposed_change_breaks_regression"):
        decision.update({"reject_change": True, "update_skill": False})

    if scale in {"tiny", "small"} and not risky:
        decision.update(
            {
                "review_mode": "quick",
                "subagents": False,
                "simplify": "skip",
                "deep_review": False,
                "lens_count_min": 0,
                "lens_count_max": 1,
            }
        )

    if risky or scale == "large":
        decision.update({"review_mode": "deep", "deep_review": True, "simplify": "run"})

    if signals.get("openspec") and signals.get("scope_non_obvious"):
        decision.update(
            {
                "plan_review_before_code": True,
                "entrypoint": "request-code-review",
                "review_target": "plan/spec",
            }
        )

    if signals.get("out_of_scope_finding") and signals.get("finding_evidenced"):
        if signals.get("blocks_current_acceptance"):
            decision.update({"expand_scope": True, "create_follow_up": False})
        else:
            decision.update({"expand_scope": False, "create_follow_up": True})

    if signals.get("reviewers_conflict") and signals.get("evidence_level") == "none":
        decision.update({"apply_feedback": False, "choose_no_change": True})

    if any(signals.get(k) for k in ["destructive", "data_loss_risk", "payment", "external_commitment"]):
        decision.update({"user_approval_required": True, "review_mode": "deep", "deep_review": True})

    if signals.get("skill_change"):
        decision.update(
            {
                "static_validation_required": True,
                "behavior_eval_required": True,
                "gpt_5_5_review_required": True,
                "opus_4_7_review_required": True,
                "evidence_packet_required": True,
            }
        )

    return decision


def run_doc_cases(skills_root: Path) -> tuple[int, int]:
    cases = json.loads((skills_root / ".workflow-evals" / "cases.json").read_text())
    passed = failed = 0
    for case in cases:
        corpus_parts: list[str] = []
        missing_files: list[str] = []
        for rel in case["files"]:
            path = skills_root / rel
            if not path.exists():
                missing_files.append(rel)
            else:
                corpus_parts.append(path.read_text())
        corpus = "\n".join(corpus_parts)
        missing_terms = [term for term in case.get("must", []) if re.search(re.escape(term), corpus, flags=re.IGNORECASE) is None]
        forbidden_hits = [term for term in case.get("must_not", []) if re.search(re.escape(term), corpus, flags=re.IGNORECASE) is not None]
        if missing_files or missing_terms or forbidden_hits:
            failed += 1
            print(f"FAIL doc:{case['id']}: {case['description']}")
            if missing_files:
                print(f"  missing files: {', '.join(missing_files)}")
            if missing_terms:
                print(f"  missing required terms: {', '.join(missing_terms)}")
            if forbidden_hits:
                print(f"  forbidden terms present: {', '.join(forbidden_hits)}")
        else:
            passed += 1
            print(f"PASS doc:{case['id']}: {case['description']}")
    return passed, failed


def run_scenarios(skills_root: Path) -> tuple[int, int]:
    scenarios = json.loads((skills_root / ".workflow-evals" / "scenarios.json").read_text())
    passed = failed = 0
    for scenario in scenarios:
        got = decide(scenario.get("signals", {}))
        mismatches = []
        for key, expected in scenario.get("expect", {}).items():
            actual = got.get(key)
            if actual != expected:
                mismatches.append((key, expected, actual))
        if mismatches:
            failed += 1
            print(f"FAIL scenario:{scenario['id']}: {scenario['description']}")
            for key, expected, actual in mismatches:
                print(f"  {key}: expected {expected!r}, got {actual!r}")
        else:
            passed += 1
            print(f"PASS scenario:{scenario['id']}: {scenario['description']}")
    return passed, failed


def main() -> int:
    skills_root = Path(__file__).resolve().parents[2]
    doc_pass, doc_fail = run_doc_cases(skills_root)
    scenario_pass, scenario_fail = run_scenarios(skills_root)
    passed = doc_pass + scenario_pass
    failed = doc_fail + scenario_fail
    print(f"\nWorkflow eval summary: {passed}/{passed + failed} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
