"""Validate Phase 4 bypass records and produce safe post-merge alerts."""

from datetime import datetime, timedelta, timezone
import json
import re
import sys


SHA = re.compile(r"^[0-9a-f]{40}$")
STATES = {"REQUESTED", "APPROVED", "DENIED", "EXPIRED", "EXERCISED"}


def _failure(code):
    return {"result": "FAIL", "error_code": code}


def _timestamp(value):
    try:
        if not isinstance(value, str) or not value.endswith("Z"):
            return None
        return datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError:
        return None


def _reference_valid(reference, sha):
    return isinstance(reference, dict) and reference.get("kind") in {"CHECK_RUN", "WORKFLOW_RUN", "SANITIZED_ARTIFACT"} and isinstance(reference.get("id"), int) and reference.get("id") > 0 and reference.get("sha") == sha and reference.get("assurance") == "GITHUB_VERIFIED"


def _binding_valid(item, record, policy):
    subject = record.get("subject", {})
    if item.get("control") not in policy["controls"] or not policy["controls"][item["control"]]["human_exception_eligible"]:
        return False
    if item.get("issue") != subject.get("issue") or item.get("sha") != subject.get("head_sha") or not SHA.fullmatch(item.get("sha", "")):
        return False
    requester = item.get("requesting_human_id")
    approver = item.get("approving_human_id")
    if not isinstance(requester, int) or isinstance(requester, bool) or requester < 1 or not isinstance(approver, int) or isinstance(approver, bool) or approver < 1 or requester == approver:
        return False
    requested = _timestamp(item.get("requested_at"))
    expires = _timestamp(item.get("expires_at"))
    if requested is None or expires is None or expires <= requested or expires > requested + timedelta(seconds=policy["bypasses"]["maximum_validity_seconds"]):
        return False
    if not isinstance(item.get("compensating_controls"), list) or not item["compensating_controls"] or len(set(item["compensating_controls"])) != len(item["compensating_controls"]):
        return False
    if any(control not in policy["controls"] for control in item["compensating_controls"]):
        return False
    if item.get("state") in {"APPROVED", "EXERCISED"} and not _reference_valid(item.get("approval_reference"), item["sha"]):
        return False
    return True


def _events_valid(item, events):
    expected = {"REQUESTED": ["REQUESTED"], "APPROVED": ["REQUESTED", "APPROVED"], "EXERCISED": ["REQUESTED", "APPROVED", "EXERCISED"], "DENIED": ["REQUESTED", "DENIED"], "EXPIRED": ["REQUESTED", "EXPIRED"]}.get(item.get("state"))
    actual = [event.get("type", "").removeprefix("BYPASS_") for event in sorted(events, key=lambda event: event.get("sequence", 0)) if event.get("bypass_id") == item.get("id")]
    return expected == actual


def _validate_item(item, record, policy, now):
    if not isinstance(item, dict) or item.get("state") not in STATES or not _binding_valid(item, record, policy):
        return "BYPASS_BINDING_INVALID"
    related = record.get("events", [])
    if not isinstance(related, list) or not _events_valid(item, related):
        return "BYPASS_TRANSITION_INVALID"
    if item["state"] == "EXPIRED" and now < _timestamp(item["expires_at"]):
        return "BYPASS_TRANSITION_INVALID"
    if item["state"] not in {"APPROVED", "EXERCISED"}:
        return "BYPASS_TRANSITION_INVALID"
    return None


def evaluate(record, policy, now=None):
    """Validate all bypasses and return a sanitized governance result."""
    if not isinstance(record, dict) or not isinstance(record.get("bypasses"), list):
        return _failure("BYPASS_INPUT_INVALID")
    now = now or datetime.now(timezone.utc)
    try:
        for item in record["bypasses"]:
            failure = _validate_item(item, record, policy, now)
            if failure is not None:
                return _failure(failure)
    except (AttributeError, TypeError, ValueError):
        return _failure("BYPASS_INPUT_INVALID")
    approved = sum(item["state"] in {"APPROVED", "EXERCISED"} for item in record["bypasses"])
    return {"result": "PASS", "summary": {"approved_bypasses": approved}, "warning": "APPROVED_BYPASS" if approved else "NONE"}


def post_merge_alert(record, policy):
    """Return one repeatable sanitized alert for the first approved bypass."""
    try:
        for item in record.get("bypasses", []):
            if item.get("state") in {"APPROVED", "EXERCISED"} and _binding_valid(item, record, policy):
                subject = record.get("subject", {})
                return {"schema_version": 1, "result": "PASS", "repository": record.get("repository"), "issue": subject.get("issue"), "pull_request": subject.get("pull_request"), "head_sha": item["sha"], "control": item["control"], "bypass_id": item["id"], "reason_code": "APPROVED_BYPASS"}
    except (AttributeError, TypeError, ValueError):
        return _failure("BYPASS_INPUT_INVALID")
    return _failure("NO_APPROVED_BYPASS")


def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    if len(args) not in {4, 5} or args[0] != "--input" or args[2] != "--policy":
        print('{"result":"FAIL","error_code":"AUDIT_USAGE"}')
        return 1
    try:
        with open(args[1], encoding="utf-8") as source:
            record = json.load(source)
        with open(args[3], encoding="utf-8") as source:
            policy = json.load(source)["audit"]
        result = post_merge_alert(record, policy) if len(args) == 5 and args[4] == "--alert" else evaluate(record, policy)
    except (AttributeError, KeyError, OSError, TypeError, ValueError):
        result = _failure("BYPASS_INPUT_INVALID")
    print(json.dumps(result, separators=(",", ":"), ensure_ascii=True))
    return 0 if result.get("result") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
