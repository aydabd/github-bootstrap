"""TDD contract for Phase 4 bypass governance and alerts."""

import importlib.util
import contextlib
import io
import json
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path


HERE = Path(__file__).resolve().parent
MODULE_PATH = HERE.parent / "audit" / "bypass_governance.py"


def load_governance():
    spec = importlib.util.spec_from_file_location("bypass_governance", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("bypass governance module is missing")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def policy():
    return json.loads((HERE.parent / "agent-workflow.json").read_text())["audit"]


def bypass(state="EXERCISED", sha="a" * 40, approving=2, expires="2026-09-15T12:00:00Z"):
    return {
        "id": 1, "control": "REQUIRED_CHECKS", "state": state, "reason_code": "DEPENDENCY_OUTAGE",
        "requesting_human_id": 1, "approving_human_id": approving, "issue": 218, "sha": sha,
        "requested_at": "2026-09-14T12:00:00Z", "expires_at": expires,
        "compensating_controls": ["AUDIT_PRIVACY", "AUDIT_SCHEMA"],
        "approval_reference": {"kind": "CHECK_RUN", "id": 10, "sha": sha, "attempt": None, "assurance": "GITHUB_VERIFIED"},
    }


def events(states):
    return [{"sequence": index, "type": "BYPASS_" + state, "bypass_id": 1, "result": "PASS", "reason_code": "NONE", "evidence": []} for index, state in enumerate(states, 1)]


class BypassGovernanceTests(unittest.TestCase):
    def test_exercised_bypass_is_valid_and_visible(self):
        governance = load_governance()
        record = {"repository": "aydabd/repository", "subject": {"issue": 218, "pull_request": 227, "base_sha": "b" * 40, "head_sha": "a" * 40}, "bypasses": [bypass()], "events": events(["REQUESTED", "APPROVED", "EXERCISED"])}
        result = governance.evaluate(record, policy(), datetime(2026, 9, 14, 13, tzinfo=timezone.utc))
        self.assertEqual(result["result"], "PASS")
        self.assertEqual(result["summary"], {"approved_bypasses": 1})
        self.assertEqual(result["warning"], "APPROVED_BYPASS")

    def test_wrong_sha_and_self_approval_fail_without_echoing_record(self):
        governance = load_governance()
        record = {"repository": "aydabd/repository", "subject": {"issue": 218, "pull_request": 227, "base_sha": "b" * 40, "head_sha": "a" * 40}, "bypasses": [bypass(sha="c" * 40, approving=1)], "events": events(["REQUESTED", "APPROVED", "EXERCISED"])}
        result = governance.evaluate(record, policy())
        self.assertEqual(result, {"result": "FAIL", "error_code": "BYPASS_BINDING_INVALID"})
        self.assertNotIn("cccc", json.dumps(result))

    def test_expired_bypass_and_missing_event_fail_closed(self):
        governance = load_governance()
        record = {"repository": "aydabd/repository", "subject": {"issue": 218, "pull_request": 227, "base_sha": "b" * 40, "head_sha": "a" * 40}, "bypasses": [bypass(state="EXPIRED", expires="2026-09-14T13:00:00Z")], "events": events(["REQUESTED"])}
        result = governance.evaluate(record, policy(), datetime(2026, 9, 15, tzinfo=timezone.utc))
        self.assertEqual(result, {"result": "FAIL", "error_code": "BYPASS_TRANSITION_INVALID"})

    def test_alert_is_deterministic_and_idempotent(self):
        governance = load_governance()
        record = {"repository": "aydabd/repository", "subject": {"issue": 218, "pull_request": 227, "base_sha": "b" * 40, "head_sha": "a" * 40}, "bypasses": [bypass()], "events": events(["REQUESTED", "APPROVED", "EXERCISED"])}
        first = governance.post_merge_alert(record, policy())
        second = governance.post_merge_alert(record, policy())
        self.assertEqual(first, second)
        self.assertEqual(first, {"schema_version": 1, "result": "PASS", "repository": "aydabd/repository", "issue": 218, "pull_request": 227, "head_sha": "a" * 40, "control": "REQUIRED_CHECKS", "bypass_id": 1, "reason_code": "APPROVED_BYPASS"})

    def test_malformed_input_fails_closed_without_echoing_values(self):
        governance = load_governance()
        record = {"repository": "SECRET", "subject": {"head_sha": ["SECRET"]}, "bypasses": [{"control": []}], "events": []}
        result = governance.evaluate(record, policy())
        self.assertEqual(result, {"result": "FAIL", "error_code": "BYPASS_BINDING_INVALID"})
        self.assertNotIn("SECRET", json.dumps(result))

    def test_cli_emits_only_fixed_failure_for_malformed_input(self):
        governance = load_governance()
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json") as source:
            source.write('{"bypasses":"SECRET"}')
            source.flush()
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                status = governance.main(["--input", source.name, "--policy", str(HERE.parent / "agent-workflow.json")])
        self.assertEqual(status, 1)
        self.assertEqual(output.getvalue(), '{"result":"FAIL","error_code":"BYPASS_INPUT_INVALID"}\n')
        self.assertNotIn("SECRET", output.getvalue())


if __name__ == "__main__":
    unittest.main()
