"""TDD contract for the Phase 2 local provenance collector."""

import importlib.util
import json
import io
import contextlib
import shutil
import tempfile
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
MODULE_PATH = HERE.parent / "audit" / "collector.py"


def load_collector():
    spec = importlib.util.spec_from_file_location("audit_collector", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("collector module is missing")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def fixture_input(root):
    plugin = root / "plugin"
    manifest = json.loads((HERE.parent / "agent-workflow.json").read_text())
    names = manifest["required_plugins"]["superpowers"]["skills"]
    for name in names:
        (plugin / "skills" / name).mkdir(parents=True, exist_ok=True)
    (plugin / "plugin.json").write_text('{"name":"superpowers","version":"6.3.0"}\n')
    for name in names:
        (plugin / "skills" / name / "SKILL.md").write_text(f"# {name}\n")
    definition = root / "agent.md"
    definition.write_text("public agent definition\n")
    return {
        "repository": "example/audit-fixture",
        "subject": {"issue": 218, "pull_request": None, "base_sha": None, "head_sha": None},
        "agent": {
            "name": "codex",
            "role": "implementation",
            "cli_version": "1.0.0",
            "definition_path": str(definition),
        },
        "model": {"requested": "synthetic-model", "reasoning_effort": "medium"},
        "plugin_path": str(plugin),
        "plugin_version": "6.3.0",
    }


class ProvenanceCollectorTests(unittest.TestCase):
    def test_module_exists_and_collects_deterministic_record(self):
        collector = load_collector()
        with tempfile.TemporaryDirectory() as directory:
            first = collector.collect(fixture_input(Path(directory)), HERE.parent / "agent-workflow.json")
            second = collector.collect(fixture_input(Path(directory)), HERE.parent / "agent-workflow.json")
        self.assertEqual(first, second)
        self.assertEqual(list(first), [
            "schema_version", "record_type", "result", "repository", "subject",
            "provenance", "events", "bypasses", "verification", "privacy",
            "integrity", "summary",
        ])
        self.assertEqual(first["provenance"]["model"]["observed"], None)
        self.assertEqual(first["provenance"]["model"]["assurance"], "SELF_DECLARED")
        self.assertEqual(first["result"], "FAIL")
        self.assertEqual(first["verification"]["required_checks"], "FAIL")
        self.assertEqual(
            next(item for item in first["verification"]["controls"] if item["control"] == "REQUIRED_CHECKS"),
            {"control": "REQUIRED_CHECKS", "result": "FAIL", "reason_code": "MISSING_EVIDENCE"},
        )
        self.assertRegex(first["integrity"]["sha256"], r"^[0-9a-f]{64}$")

    def test_provider_attestation_is_rejected_without_authenticated_source(self):
        collector = load_collector()
        with tempfile.TemporaryDirectory() as directory:
            data = fixture_input(Path(directory))
            data["model"]["provider_attestation"] = {"observed": "synthetic-model"}
            with self.assertRaises(collector.CollectionError) as raised:
                collector.collect(data, HERE.parent / "agent-workflow.json")
        self.assertEqual(raised.exception.code, "AUDIT_PROVENANCE_INVALID")

    def test_forbidden_input_is_rejected_without_echoing_value(self):
        collector = load_collector()
        with tempfile.TemporaryDirectory() as directory:
            data = fixture_input(Path(directory))
            data["prompt"] = "SECRET-SYNTHETIC-PROMPT"
            with self.assertRaises(collector.CollectionError) as raised:
                collector.collect(data, HERE.parent / "agent-workflow.json")
        self.assertEqual(raised.exception.code, "AUDIT_PRIVACY_REJECTED")
        self.assertNotIn("SECRET-SYNTHETIC-PROMPT", str(raised.exception))

    def test_temporary_evidence_is_removed_on_success_and_rejection(self):
        collector = load_collector()
        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory) / "evidence"
            data = fixture_input(Path(directory))
            collector.collect(data, HERE.parent / "agent-workflow.json", evidence)
            self.assertEqual(list(evidence.iterdir()), [])
            data["reasoning"] = "SECRET-SYNTHETIC-REASONING"
            with self.assertRaises(collector.CollectionError):
                collector.collect(data, HERE.parent / "agent-workflow.json", evidence)
            self.assertEqual(list(evidence.iterdir()), [])

    def test_missing_plugin_and_skill_metadata_fail_closed(self):
        collector = load_collector()
        with tempfile.TemporaryDirectory() as directory:
            data = fixture_input(Path(directory))
            data["plugin_path"] = str(Path(directory) / "missing")
            record = collector.collect(data, HERE.parent / "agent-workflow.json")
        self.assertEqual(record["result"], "FAIL")
        self.assertEqual(record["provenance"]["plugins"], [])
        self.assertEqual(record["summary"]["failed"], 1)
        self.assertEqual(
            next(item for item in record["verification"]["controls"] if item["control"] == "SUPERPOWERS"),
            {"control": "SUPERPOWERS", "result": "FAIL", "reason_code": "MISSING_EVIDENCE"},
        )

    def test_failure_documents_preserve_missing_and_invalid_evidence(self):
        collector = load_collector()
        policy = json.loads((HERE.parent / "agent-workflow.json").read_text())["audit"]
        missing = collector._failure_document(policy, "AUDIT_SUPERPOWERS_MISSING")
        unreadable = collector._failure_document(policy, "AUDIT_PROVENANCE_UNREADABLE")
        self.assertEqual(missing["verification"]["controls"][-1]["reason_code"], "MISSING_EVIDENCE")
        self.assertEqual(unreadable["verification"]["controls"][-1]["reason_code"], "INVALID_EVIDENCE")

    def test_skill_outside_plugin_is_rejected(self):
        collector = load_collector()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data = fixture_input(root)
            outside = root / "outside.md"
            outside.write_text("outside package\n")
            data["skill_paths"] = {"using-superpowers": str(outside)}
            with self.assertRaises(collector.CollectionError) as raised:
                collector.collect(data, HERE.parent / "agent-workflow.json")
        self.assertEqual(raised.exception.code, "AUDIT_PROVENANCE_SCOPE_REJECTED")

    def test_symlinked_plugin_ancestor_is_rejected(self):
        collector = load_collector()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data = fixture_input(root)
            skills = root / "plugin" / "skills"
            external = root / "external-skills"
            shutil.move(str(skills), str(external))
            skills.symlink_to(external, target_is_directory=True)
            with self.assertRaises(collector.CollectionError) as raised:
                collector.collect(data, HERE.parent / "agent-workflow.json")
        self.assertEqual(raised.exception.code, "AUDIT_PROVENANCE_SCOPE_REJECTED")

    def test_symlinked_plugin_parent_is_rejected(self):
        collector = load_collector()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data = fixture_input(root)
            real_parent = root / "real-parent"
            real_parent.mkdir()
            plugin = real_parent / "plugin"
            shutil.move(data["plugin_path"], plugin)
            parent = root / "parent"
            parent.symlink_to(real_parent, target_is_directory=True)
            data["plugin_path"] = str(parent / "plugin")
            with self.assertRaises(collector.CollectionError) as raised:
                collector.collect(data, HERE.parent / "agent-workflow.json")
        self.assertEqual(raised.exception.code, "AUDIT_PROVENANCE_SCOPE_REJECTED")

    def test_provider_attestation_must_match_requested_identity(self):
        collector = load_collector()
        with tempfile.TemporaryDirectory() as directory:
            data = fixture_input(Path(directory))
            data["model"]["provider_attestation"] = {"requested": "other-model", "observed": "other-model", "reasoning_effort": "medium"}
            with self.assertRaises(collector.CollectionError) as raised:
                collector.collect(data, HERE.parent / "agent-workflow.json")
        self.assertEqual(raised.exception.code, "AUDIT_PROVENANCE_INVALID")

    def test_cleanup_rejects_symlinked_evidence_root(self):
        collector = load_collector()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target"
            target.mkdir()
            (target / "keep").write_text("keep")
            link = root / "evidence"
            link.symlink_to(target, target_is_directory=True)
            with self.assertRaises(collector.CollectionError) as raised:
                collector._cleanup(link)
            self.assertEqual(raised.exception.code, "AUDIT_EVIDENCE_CLEANUP_FAILED")
            self.assertTrue((target / "keep").exists())

    def test_cleanup_rejects_symlinked_evidence_parent(self):
        collector = load_collector()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target"
            target.mkdir()
            (target / "raw-evidence.json").write_text("keep")
            link = root / "evidence"
            link.symlink_to(target, target_is_directory=True)
            with self.assertRaises(collector.CollectionError):
                collector.collect(fixture_input(root), HERE.parent / "agent-workflow.json", link)
            self.assertTrue((target / "raw-evidence.json").exists())

    def test_cleanup_rejects_symlinked_evidence_ancestor(self):
        collector = load_collector()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target"
            target.mkdir()
            (target / "raw-evidence.json").write_text("keep")
            parent = root / "parent"
            parent.symlink_to(target, target_is_directory=True)
            with self.assertRaises(collector.CollectionError):
                collector.collect(fixture_input(root), HERE.parent / "agent-workflow.json", parent / "evidence")
            self.assertTrue((target / "raw-evidence.json").exists())

    def test_cli_emits_safe_canonical_failure(self):
        collector = load_collector()
        with tempfile.TemporaryDirectory() as directory:
            input_path = Path(directory) / "input.json"
            input_path.write_text('{"prompt":"SECRET-SYNTHETIC-PROMPT"}')
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                status = collector.main(["--input", str(input_path)])
        self.assertEqual(status, 1)
        document = json.loads(output.getvalue())
        self.assertEqual(document["result"], "FAIL")
        self.assertNotIn("SECRET-SYNTHETIC-PROMPT", output.getvalue())

    def test_cli_rejects_duplicate_json_keys(self):
        collector = load_collector()
        with tempfile.TemporaryDirectory() as directory:
            input_path = Path(directory) / "input.json"
            input_path.write_text('{"repository":"example/audit-fixture","repository":"other/value"}')
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                status = collector.main(["--input", str(input_path)])
        self.assertEqual(status, 1)
        self.assertNotIn("other/value", output.getvalue())


if __name__ == "__main__":
    unittest.main()
