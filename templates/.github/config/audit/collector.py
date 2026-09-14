"""Collect the Phase 2 allowlisted local provenance record."""

import copy
import hashlib
import json
import sys
import signal
import tempfile
from pathlib import Path

import rfc8785
from jsonschema import Draft202012Validator, FormatChecker


class CollectionError(Exception):
    """A safe, fixed-code collection failure."""

    def __init__(self, code):
        super().__init__(code)
        self.code = code


ALLOWED_INPUT = {"repository", "subject", "agent", "model", "plugin_path", "plugin_version", "skill_paths"}
FORBIDDEN_KEYS = {
    "prompt", "prompts", "model_response", "model_responses", "reasoning", "reasoning_summary",
    "chain_of_thought", "token", "tokens", "cookie", "cookies", "authorization",
    "authorization_headers", "private_key", "secrets", "environment", "environment_values",
    "ip_address", "home_path", "email", "provider_response_id", "raw_log", "raw_logs",
    "prompt_hash", "secret_hash", "command_output",
}
SAFE_IDENTIFIER = r"^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$"


def _digest_bytes(value):
    return hashlib.sha256(value).hexdigest()


def _digest_file(path):
    try:
        if not path.is_file() or path.is_symlink():
            raise CollectionError("AUDIT_PROVENANCE_UNREADABLE")
        return _digest_bytes(path.read_bytes())
    except (OSError, ValueError):
        raise CollectionError("AUDIT_PROVENANCE_UNREADABLE") from None


def _assert_no_symlink_path(path, boundary=None, code="AUDIT_PROVENANCE_SCOPE_REJECTED"):
    path = Path(path)
    if boundary is not None:
        boundary = Path(boundary)
        try:
            parts = path.absolute().relative_to(boundary.absolute()).parts
        except ValueError:
            raise CollectionError(code) from None
        current = boundary
        candidates = [current]
        for part in parts:
            current = current / part
            candidates.append(current)
    else:
        trusted_temp = Path(tempfile.gettempdir()).absolute()
        candidates = (path.absolute(), *path.absolute().parents)
        candidates = [candidate for candidate in candidates if candidate not in trusted_temp.parents and candidate != trusted_temp]
    if any(candidate.is_symlink() for candidate in candidates):
        raise CollectionError(code)


def _unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise CollectionError("AUDIT_DUPLICATE_JSON_KEY")
        result[key] = value
    return result


def _plugin_digest(root, expected_version, required_skills):
    root = Path(root)
    _assert_no_symlink_path(root)
    if not root.is_dir() or root.is_symlink():
        raise CollectionError("AUDIT_SUPERPOWERS_MISSING")
    manifests = [root / "plugin.json", root / ".codex-plugin" / "plugin.json"]
    manifest = next((path for path in manifests if path.is_file() and not path.is_symlink()), None)
    if manifest is None:
        raise CollectionError("AUDIT_SUPERPOWERS_MISSING")
    try:
        package = json.loads(manifest.read_text(), object_pairs_hook=_unique_pairs)
    except (OSError, ValueError):
        raise CollectionError("AUDIT_SUPERPOWERS_INVALID") from None
    if package.get("name") != "superpowers" or package.get("version") != expected_version:
        raise CollectionError("AUDIT_SUPERPOWERS_INVALID")
    entries = []
    try:
        entries.append({"path": manifest.relative_to(root).as_posix(), "sha256": _digest_file(manifest)})
        for name in required_skills:
            path = root / "skills" / name / "SKILL.md"
            _assert_no_symlink_path(path, root)
            entries.append({"path": path.relative_to(root).as_posix(), "sha256": _digest_file(path)})
    except (OSError, ValueError):
        raise CollectionError("AUDIT_PROVENANCE_UNREADABLE") from None
    if not entries:
        raise CollectionError("AUDIT_SUPERPOWERS_MISSING")
    return _digest_bytes(rfc8785.dumps(sorted(entries, key=lambda item: item["path"].encode("ascii"))))


def _reject_forbidden(value):
    if isinstance(value, dict):
        if any(key in FORBIDDEN_KEYS for key in value):
            raise CollectionError("AUDIT_PRIVACY_REJECTED")
        for child in value.values():
            _reject_forbidden(child)
    elif isinstance(value, list):
        for child in value:
            _reject_forbidden(child)


def _safe_string(value, code):
    if not isinstance(value, str) or not value or len(value) > 128:
        raise CollectionError(code)
    import re
    if re.fullmatch(SAFE_IDENTIFIER, value) is None:
        raise CollectionError(code)
    return value


def _cleanup(directory):
    if directory is None:
        return
    try:
        if directory.exists() and directory.is_symlink():
            raise CollectionError("AUDIT_EVIDENCE_CLEANUP_FAILED")
        directory.mkdir(parents=True, exist_ok=True)
        for child in directory.iterdir():
            if child.name == "raw-evidence.json" and not child.is_symlink():
                child.unlink()
    except OSError:
        raise CollectionError("AUDIT_EVIDENCE_CLEANUP_FAILED") from None


def _digest_record(record, policy):
    payload = copy.deepcopy(record)
    parent, field = policy["serialization"]["integrity"]["excluded_pointer"].strip("/").split("/")
    del payload[parent][field]
    return _digest_bytes(rfc8785.dumps(payload))


def _record(data, policy, provenance, result, control_result, reason):
    controls = []
    for control in ("AUDIT_INTEGRITY", "AUDIT_PRIVACY", "AUDIT_SCHEMA", "PROVENANCE_SCHEMA", "SUPERPOWERS"):
        controls.append({"control": control, "result": "PASS", "reason_code": "NONE"})
    if result == "FAIL":
        if reason == "NONE":
            controls.append({"control": "REQUIRED_CHECKS", "result": "FAIL", "reason_code": "MISSING_EVIDENCE"})
        else:
            controls[-1] = {"control": "SUPERPOWERS", "result": control_result, "reason_code": reason}
    passed = sum(item["result"] == "PASS" for item in controls)
    failed = sum(item["result"] == "FAIL" for item in controls)
    skipped = sum(item["result"] == "SKIP" for item in controls)
    record = {
        "schema_version": 1,
        "record_type": "agent_work_audit",
        "result": result,
        "repository": data["repository"],
        "subject": data["subject"],
        "provenance": provenance,
        "events": [],
        "bypasses": [],
        "verification": {
            "signed_off": None, "commit_signature_verified": None, "required_checks": "FAIL",
            "unexpected_skips": 0, "controls": controls,
        },
        "privacy": {
            "classification": "NON_SENSITIVE", "redaction_version": 1,
            "contains_prompt": False, "contains_credentials": False, "contains_personal_data": False,
        },
        "integrity": {"canonicalization": "RFC8785", "sha256": None},
        "summary": {"passed": passed, "failed": failed, "skipped": skipped, "approved_bypasses": 0},
    }
    return record


def _finalize(record, policy):
    record["integrity"]["sha256"] = _digest_record(record, policy)
    return record


def collect(data, manifest_path, evidence_dir=None):
    """Return one deterministic record from explicit, allowlisted local metadata."""
    evidence = Path(evidence_dir) if evidence_dir is not None else None
    owned_evidence = evidence / "local-provenance" if evidence is not None else None
    if evidence is not None:
        _assert_no_symlink_path(evidence, tempfile.gettempdir(), "AUDIT_EVIDENCE_CLEANUP_FAILED")
    if evidence is not None and evidence.is_symlink():
        raise CollectionError("AUDIT_EVIDENCE_CLEANUP_FAILED")
    try:
        if not isinstance(data, dict) or set(data) - ALLOWED_INPUT:
            raise CollectionError("AUDIT_PRIVACY_REJECTED")
        _reject_forbidden(data)
        manifest = json.loads(Path(manifest_path).read_text())
        policy = manifest["audit"]
        required_skills = manifest["required_plugins"]["superpowers"]["skills"]
        try:
            plugin_digest = _plugin_digest(data.get("plugin_path"), data.get("plugin_version"), required_skills)
        except CollectionError as error:
            if error.code not in {"AUDIT_SUPERPOWERS_MISSING", "AUDIT_PROVENANCE_UNREADABLE"}:
                raise
            failure = {
                "agent": {"name": "unknown", "role": "implementation", "cli_version": None, "cli_assurance": "UNAVAILABLE", "definition_sha256": None, "definition_assurance": "UNAVAILABLE"},
                "model": {"requested": None, "observed": None, "reasoning_effort": None, "assurance": "UNAVAILABLE"},
                "plugins": [], "skills": [],
            }
            return _failure_document(policy, error.code)
        skill_paths = data.get("skill_paths", {})
        skills = []
        for name in required_skills:
            path = skill_paths.get(name) if isinstance(skill_paths, dict) else None
            path = path or str(Path(data["plugin_path"]) / "skills" / name / "SKILL.md")
            try:
                _assert_no_symlink_path(path, data["plugin_path"])
                Path(path).resolve().relative_to(Path(data["plugin_path"]).resolve())
            except ValueError:
                raise CollectionError("AUDIT_PROVENANCE_SCOPE_REJECTED") from None
            skills.append({"name": name, "plugin": "superpowers", "version": None, "content_sha256": _digest_file(Path(path)), "assurance": "LOCALLY_OBSERVED"})
        agent = data.get("agent", {})
        definition = agent.get("definition_path")
        provenance_agent = {
            "name": _safe_string(agent.get("name"), "AUDIT_AGENT_INVALID"),
            "role": agent.get("role"),
            "cli_version": agent.get("cli_version"),
            "cli_assurance": "LOCALLY_OBSERVED" if agent.get("cli_version") else "UNAVAILABLE",
            "definition_sha256": _digest_file(Path(definition)) if definition else None,
            "definition_assurance": "LOCALLY_OBSERVED" if definition else "UNAVAILABLE",
        }
        if provenance_agent["role"] not in {"implementation", "review", "verification", "coordination"}:
            raise CollectionError("AUDIT_AGENT_INVALID")
        model = data.get("model", {})
        if "provider_attestation" in model:
            raise CollectionError("AUDIT_PROVENANCE_INVALID")
        provenance_model = {"requested": _safe_string(model.get("requested"), "AUDIT_MODEL_INVALID"), "observed": None, "reasoning_effort": model.get("reasoning_effort"), "assurance": "SELF_DECLARED"}
        provenance = {
            "agent": provenance_agent,
            "model": provenance_model,
            "plugins": [{"name": "superpowers", "source": "openai-curated-remote/superpowers", "version": _safe_string(data.get("plugin_version"), "AUDIT_SUPERPOWERS_VERSION"), "content_sha256": plugin_digest, "assurance": "LOCALLY_OBSERVED"}],
            "skills": skills,
        }
        record = _record(data, policy, provenance, "FAIL", "PASS", "NONE")
        record["integrity"]["sha256"] = "0" * 64
        if not Draft202012Validator(policy["record_schema"], format_checker=FormatChecker()).is_valid(record):
            raise CollectionError("AUDIT_SCHEMA_INVALID")
        return _finalize(record, policy)
    finally:
        _cleanup(owned_evidence)
        if owned_evidence is not None:
            try:
                owned_evidence.rmdir()
            except OSError:
                raise CollectionError("AUDIT_EVIDENCE_CLEANUP_FAILED") from None


def _failure_document(policy, code):
    data = {"repository": "unknown/unknown", "subject": {"issue": None, "pull_request": None, "base_sha": None, "head_sha": None}}
    provenance = {
        "agent": {"name": "unknown", "role": "implementation", "cli_version": None, "cli_assurance": "UNAVAILABLE", "definition_sha256": None, "definition_assurance": "UNAVAILABLE"},
        "model": {"requested": None, "observed": None, "reasoning_effort": None, "assurance": "UNAVAILABLE"},
        "plugins": [], "skills": [],
    }
    reason = {
        "AUDIT_SUPERPOWERS_MISSING": "MISSING_EVIDENCE",
        "AUDIT_PROVENANCE_UNREADABLE": "INVALID_EVIDENCE",
    }.get(code, code if code in {"MISSING_EVIDENCE", "INVALID_EVIDENCE"} else "INVALID_EVIDENCE")
    return _finalize(_record(data, policy, provenance, "FAIL", "FAIL", reason), policy)


def main(argv=None):
    """CLI: read one explicit JSON declaration and emit one safe JSON record."""
    args = list(sys.argv[1:] if argv is None else argv)
    if len(args) != 2 or args[0] != "--input":
        print('{"schema_version":1,"result":"FAIL","error_code":"AUDIT_USAGE"}')
        return 1
    manifest_path = Path(__file__).parent.parent / "agent-workflow.json"
    evidence = Path(tempfile.mkdtemp(prefix="audit-"))
    previous_handlers = {name: signal.getsignal(name) for name in (signal.SIGINT, signal.SIGTERM)}

    def interrupt(_signum, _frame):
        raise CollectionError("AUDIT_INTERRUPTED")

    signal.signal(signal.SIGINT, interrupt)
    signal.signal(signal.SIGTERM, interrupt)
    manifest = None
    record = None
    try:
        manifest = json.loads(manifest_path.read_text())
        data = json.loads(Path(args[1]).read_text(), object_pairs_hook=_unique_pairs)
        record = collect(data, manifest_path, evidence)
    except CollectionError as error:
        record = _failure_document(manifest["audit"], error.code) if manifest else {"schema_version": 1, "result": "FAIL", "error_code": error.code}
    except (OSError, ValueError, KeyError, TypeError):
        record = _failure_document(manifest["audit"], "INVALID_EVIDENCE") if manifest else {"schema_version": 1, "result": "FAIL", "error_code": "INVALID_EVIDENCE"}
    finally:
        signal.signal(signal.SIGINT, previous_handlers[signal.SIGINT])
        signal.signal(signal.SIGTERM, previous_handlers[signal.SIGTERM])
        try:
            evidence.rmdir()
        except OSError:
            pass
    print(json.dumps(record, separators=(",", ":"), ensure_ascii=True))
    return 1 if record["result"] == "FAIL" else 0


if __name__ == "__main__":
    sys.exit(main())
