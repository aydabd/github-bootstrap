"""Calculate deterministic quality trends from sanitized audit outcomes."""

from datetime import datetime
import json
import math
import sys
from pathlib import Path


FORBIDDEN = {
    "prompt", "prompts", "model_response", "model_responses", "reasoning",
    "reasoning_summary", "chain_of_thought", "token", "tokens", "cookie",
    "cookies", "authorization", "authorization_headers", "private_key",
    "secrets", "environment", "environment_values", "ip_address", "home_path",
    "email", "provider_response_id", "raw_log", "raw_logs", "command_output",
}


def _failure(code):
    return {"schema_version": 1, "result": "FAIL", "error_code": code}


def policy(manifest_path):
    with open(manifest_path, encoding="utf-8") as source:
        return json.load(source)["audit"]["quality"]


def _contains_forbidden(value):
    if isinstance(value, dict):
        return any(key in FORBIDDEN or _contains_forbidden(child) for key, child in value.items())
    if isinstance(value, list):
        return any(_contains_forbidden(child) for child in value)
    return False


def _valid_time(value):
    try:
        return isinstance(value, str) and value.endswith("Z") and datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError:
        return False


def cleanup(directory):
    """Delete the only permitted transient evidence file, safely and repeatedly."""
    path = Path(directory) / "raw-evidence.json"
    try:
        if path.exists():
            path.unlink()
    except OSError:
        raise ValueError("QUALITY_CLEANUP_FAILED") from None


def _valid_outcome(item, quality):
    if not isinstance(item, dict) or set(item) != {"issue", "pull_request", "completed_at", "cohort", "evidence"}:
        return False
    if any(isinstance(item[key], bool) or not isinstance(item[key], int) or item[key] < 1 for key in ("issue", "pull_request")):
        return False
    if not _valid_time(item["completed_at"]):
        return False
    cohort = item["cohort"]
    if not isinstance(cohort, dict) or list(cohort) != quality["cohort_fields"]:
        return False
    if any(not isinstance(cohort[field], str) or cohort[field] not in quality["cohort_values"][field] for field in quality["cohort_fields"]):
        return False
    evidence = item["evidence"]
    if not isinstance(evidence, dict) or list(evidence) != quality["evidence_fields"]:
        return False
    for field, value in evidence.items():
        if field == "provenance_complete" or field == "signature_verified" or field == "process_refinement_recorded":
            if not isinstance(value, bool):
                return False
        elif field == "hours_to_merge":
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                return False
        elif isinstance(value, bool) or not isinstance(value, int) or value < 0:
            return False
    return True


def _same_cohort(left, right, fields):
    return all(left["cohort"][field] == right["cohort"][field] for field in fields)


def _component_scores(item):
    evidence = item["evidence"]
    compliance = 100 - min(100, 25 * (not evidence["provenance_complete"] or not evidence["signature_verified"]) + 10 * evidence["unexpected_skips"] + 25 * evidence["unauthorized_bypasses"] + 25 * evidence["required_checks_failed"])
    correctness = max(0, 100 - 25 * (evidence["regressions"] + evidence["reverts"] + evidence["reopened"]))
    review = max(0, 100 - 20 * evidence["stale_approvals"] - 20 * evidence["unresolved_threads"] - 10 * max(0, evidence["actionable_findings"] - evidence["actionable_resolved"]))
    delivery = max(0, 100 - 10 * evidence["pushes_after_first_ci"] - 15 * evidence["repeated_ci_failures"])
    process = 100 if evidence["process_refinement_recorded"] else 0
    return {"compliance": compliance, "correctness": correctness, "review_quality": review, "delivery_efficiency": delivery, "process_improvement": process}


def _raw(items):
    fields = {
        "compliance": ["provenance_complete", "signature_verified", "unexpected_skips", "unauthorized_bypasses", "required_checks_failed"],
        "correctness": ["regressions", "reverts", "reopened"],
        "review_quality": ["actionable_findings", "actionable_resolved", "stale_approvals", "unresolved_threads"],
        "delivery_efficiency": ["hours_to_merge", "pushes_after_first_ci", "repeated_ci_failures"],
        "process_improvement": ["process_refinement_recorded"],
    }
    return {component: {field: sum(item["evidence"][field] for item in items) if field != "hours_to_merge" else sum(item["evidence"][field] for item in items) / len(items) for field in names} | {"outcomes": len(items)} for component, names in fields.items()}


def evaluate(data, quality):
    if not isinstance(data, dict) or set(data) != {"schema_version", "current", "history"} or data["schema_version"] != 1:
        return _failure("QUALITY_INPUT_INVALID")
    if _contains_forbidden(data):
        return _failure("QUALITY_PRIVACY_REJECTED")
    current = data["current"]
    history = data["history"]
    if not isinstance(history, list) or not _valid_outcome(current, quality) or any(not _valid_outcome(item, quality) for item in history):
        return _failure("QUALITY_EVIDENCE_INVALID")
    identities = {(item["issue"], item["pull_request"]) for item in [current, *history]}
    if len(identities) != len(history) + 1:
        return _failure("QUALITY_EVIDENCE_INVALID")
    current_time = datetime.fromisoformat(current["completed_at"][:-1] + "+00:00")
    cohort = [item for item in history if _same_cohort(item, current, quality["cohort_fields"]) and datetime.fromisoformat(item["completed_at"][:-1] + "+00:00") < current_time]
    cohort.sort(key=lambda item: item["completed_at"], reverse=True)
    required = quality["required_cohort_size"]
    if len(cohort) < required:
        return {"schema_version": 1, "result": "SKIP", "reason_code": "INSUFFICIENT_COHORT", "cohort": {"eligible_count": len(cohort), "required_count": required}}
    selected = cohort[:required]
    component_names = ["compliance", "correctness", "review_quality", "delivery_efficiency", "process_improvement"]
    current_components = _component_scores(current)
    cohort_components = [_component_scores(item) for item in selected]
    components = {name: current_components[name] for name in component_names}
    score = round(sum(components.values()) / len(components), 2)
    cohort_average = round(sum(sum(scores.values()) / len(scores) for scores in cohort_components) / len(cohort_components), 2)
    return {"schema_version": 1, "result": "PASS", "cohort": {"eligible_count": len(selected), "required_count": required}, "raw": _raw(selected), "components": components, "score": score, "trend": {"cohort_average": cohort_average, "delta": round(score - cohort_average, 2)}}


def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    if len(args) != 4 or args[0] != "--input" or args[2] != "--manifest":
        print('{"result":"FAIL","error_code":"AUDIT_USAGE"}')
        return 1
    try:
        with open(args[1], encoding="utf-8") as source:
            data = json.load(source)
        result = evaluate(data, policy(args[3]))
    except (OSError, TypeError, ValueError, KeyError):
        result = _failure("QUALITY_INPUT_INVALID")
    print(json.dumps(result, separators=(",", ":"), ensure_ascii=True))
    return 0 if result["result"] in {"PASS", "SKIP"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
