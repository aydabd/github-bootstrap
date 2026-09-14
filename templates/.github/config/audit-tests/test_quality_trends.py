"""TDD contract for Phase 5 quality trends."""

import importlib.util
import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from copy import deepcopy
from pathlib import Path


HERE = Path(__file__).resolve().parent
MODULE_PATH = HERE.parent / "audit" / "quality_trends.py"


def load_quality():
    spec = importlib.util.spec_from_file_location("quality_trends", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("quality trends module is missing")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def outcome(issue, completed_at, score=80):
    return {
        "issue": issue,
        "pull_request": issue + 100,
        "completed_at": completed_at,
        "cohort": {"work_type": "Story", "risk": "Medium", "effort": "M"},
        "evidence": {
            "provenance_complete": True,
            "signature_verified": True,
            "unexpected_skips": 0,
            "unauthorized_bypasses": 0,
            "required_checks_failed": 0,
            "regressions": 0,
            "reverts": 0,
            "reopened": 0,
            "actionable_findings": 2,
            "actionable_resolved": 2,
            "stale_approvals": 0,
            "unresolved_threads": 0,
            "hours_to_merge": score,
            "pushes_after_first_ci": 0,
            "repeated_ci_failures": 0,
            "process_refinement_recorded": True,
        },
    }


def request(history):
    return {
        "schema_version": 1,
        "current": outcome(218, "2026-09-14T12:00:00Z"),
        "history": history,
    }


class QualityTrendsTests(unittest.TestCase):
    def test_five_comparable_outcomes_produce_raw_components_and_score(self):
        quality = load_quality()
        history = [outcome(index, f"2026-09-{index:02d}T12:00:00Z") for index in range(1, 6)]
        result = quality.evaluate(request(history), quality.policy(HERE.parent / "agent-workflow.json"))
        self.assertEqual(result["result"], "PASS")
        self.assertEqual(result["cohort"]["eligible_count"], 5)
        self.assertEqual(list(result), ["schema_version", "result", "cohort", "raw", "components", "score", "trend"])
        self.assertEqual(set(result["components"]), {"compliance", "correctness", "review_quality", "delivery_efficiency", "process_improvement"})
        self.assertEqual(result["raw"]["compliance"]["outcomes"], 5)
        self.assertGreaterEqual(result["score"], 0)
        self.assertLessEqual(result["score"], 100)

    def test_pass_reports_full_eligible_cohort_before_selection(self):
        quality = load_quality()
        history = [outcome(index, f"2026-09-{index:02d}T12:00:00Z") for index in range(1, 7)]
        result = quality.evaluate(request(history), quality.policy(HERE.parent / "agent-workflow.json"))
        self.assertEqual(result["cohort"], {"eligible_count": 6, "required_count": 5})
        self.assertEqual(result["raw"]["compliance"]["outcomes"], 5)

    def test_component_output_names_follow_manifest_policy(self):
        quality = load_quality()
        manifest_policy = quality.policy(HERE.parent / "agent-workflow.json")
        custom_policy = deepcopy(manifest_policy)
        custom_policy["components"] = ["correctness"]
        result = quality.evaluate(request([outcome(index, f"2026-09-{index:02d}T12:00:00Z") for index in range(1, 6)]), custom_policy)
        self.assertEqual(list(result["components"]), ["correctness"])
        self.assertEqual(result["score"], result["components"]["correctness"])

    def test_usage_failure_includes_schema_version(self):
        quality = load_quality()
        output = io.StringIO()
        with redirect_stdout(output):
            self.assertEqual(quality.main([]), 1)
        self.assertEqual(json.loads(output.getvalue()), {"schema_version": 1, "result": "FAIL", "error_code": "AUDIT_USAGE"})

    def test_insufficient_cohort_does_not_publish_trend(self):
        quality = load_quality()
        result = quality.evaluate(request([outcome(index, f"2026-09-{index:02d}T12:00:00Z") for index in range(1, 5)]), quality.policy(HERE.parent / "agent-workflow.json"))
        self.assertEqual(result, {"schema_version": 1, "result": "SKIP", "reason_code": "INSUFFICIENT_COHORT", "cohort": {"eligible_count": 4, "required_count": 5}})

    def test_mismatched_cohort_and_missing_evidence_are_invalid(self):
        quality = load_quality()
        history = [outcome(index, f"2026-09-{index:02d}T12:00:00Z") for index in range(1, 6)]
        history[0]["cohort"]["risk"] = "High"
        history[1]["evidence"].pop("signature_verified")
        result = quality.evaluate(request(history), quality.policy(HERE.parent / "agent-workflow.json"))
        self.assertEqual(result, {"schema_version": 1, "result": "FAIL", "error_code": "QUALITY_EVIDENCE_INVALID"})

    def test_forbidden_input_is_rejected_without_echoing_value(self):
        quality = load_quality()
        history = [outcome(index, f"2026-09-{index:02d}T12:00:00Z") for index in range(1, 6)]
        history[0]["evidence"]["raw_log"] = "SECRET"
        result = quality.evaluate(request(history), quality.policy(HERE.parent / "agent-workflow.json"))
        self.assertEqual(result, {"schema_version": 1, "result": "FAIL", "error_code": "QUALITY_PRIVACY_REJECTED"})
        self.assertNotIn("SECRET", json.dumps(result))

    def test_repeated_serialization_is_byte_stable(self):
        quality = load_quality()
        history = [outcome(index, f"2026-09-{index:02d}T12:00:00Z") for index in range(1, 6)]
        first = json.dumps(quality.evaluate(request(history), quality.policy(HERE.parent / "agent-workflow.json")), separators=(",", ":"))
        second = json.dumps(quality.evaluate(request(history), quality.policy(HERE.parent / "agent-workflow.json")), separators=(",", ":"))
        self.assertEqual(first, second)

    def test_cleanup_removes_transient_evidence_idempotently(self):
        quality = load_quality()
        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory) / "raw-evidence.json"
            evidence.write_text("synthetic raw evidence")
            quality.cleanup(Path(directory))
            quality.cleanup(Path(directory))
            self.assertFalse(evidence.exists())


if __name__ == "__main__":
    unittest.main()
