# /// script
# requires-python = ">=3.11"
# dependencies = ["jsonschema==4.25.1", "rfc8785==0.1.4", "rfc3339-validator==0.1.4"]
# ///
"""Test the shipped Phase 1 contract; never collect or print host evidence."""

import copy
import hashlib
import json
from pathlib import Path
import sys

from jsonschema import Draft202012Validator, FormatChecker
import rfc8785


HERE = Path(__file__).resolve().parent
RESULTS = []


def check(name, condition):
    RESULTS.append({"check": name, "result": "PASS" if condition else "FAIL"})


def report(error_code=None):
    if error_code:
        check(error_code, False)
    failed = sum(item["result"] == "FAIL" for item in RESULTS)
    output = {
        "schema_version": 1,
        "result": "FAIL" if failed or error_code else "PASS",
        "checks": RESULTS,
        "summary": {"passed": len(RESULTS) - failed, "failed": failed, "skipped": 0},
    }
    if error_code:
        output["error_code"] = error_code
    print(json.dumps(output, separators=(",", ":"), ensure_ascii=True))
    return 1 if failed or error_code else 0


def replace(record, path, value):
    result = copy.deepcopy(record)
    node = result
    for key in path[:-1]:
        node = node[key]
    node[path[-1]] = value
    return result


def ordered(value, schema, root):
    """Interpret the schema's property order, not a second field inventory."""
    if "$ref" in schema:
        return ordered(value, root["$defs"][schema["$ref"].split("/")[-1]], root)
    if "anyOf" in schema:
        return any(
            Draft202012Validator({"$defs": root["$defs"], **branch}).is_valid(value)
            and ordered(value, branch, root)
            for branch in schema["anyOf"]
        )
    if isinstance(value, dict):
        properties = schema.get("properties", {})
        return list(value) == list(properties) and all(
            ordered(value[key], properties[key], root) for key in value
        )
    if isinstance(value, list):
        return all(ordered(item, schema["items"], root) for item in value)
    return True


def array_ordered(record, policy):
    for rule in policy["serialization"]["arrays"]:
        value = record
        for key in rule["path"]:
            value = value[key]
        keys = [tuple(item[key] for key in rule["keys"]) for item in value]
        if keys != sorted(keys) or len(keys) != len(set(keys)):
            return False
    nested = policy["serialization"]["nested_arrays"]
    evidence_rule = nested["evidence"]
    for event in record["events"]:
        keys = [
            tuple((item[key] is not None, item[key]) for key in evidence_rule["order"])
            for item in event["evidence"]
        ]
        if evidence_rule["nulls"] != "FIRST" or keys != sorted(keys):
            return False
        if evidence_rule["unique"] and len(keys) != len(set(keys)):
            return False
    for bypass in record["bypasses"]:
        keys = bypass["compensating_controls"]
        rule = nested["compensating_controls"]
        if rule["order"] != "ASCII_ASCENDING" or keys != sorted(keys):
            return False
        if rule["unique"] and len(keys) != len(set(keys)):
            return False
    sequences = [event["sequence"] for event in record["events"]]
    return sequences == list(range(1, len(sequences) + 1))


def aggregate(checks, policy):
    """Exercise the manifest decision table against literal expected outcomes."""
    if not checks:
        return policy["outcomes"]["empty_checks"]
    mapped = []
    for item in checks:
        control = policy["controls"].get(item["control"])
        if control is None:
            return "FAIL"
        key = "mandatory" if control["mandatory"] else "optional"
        mapped.append(policy["outcomes"]["control_results"][key][item["result"]])
    return next(result for result in policy["outcomes"]["precedence"] if result in mapped)


def schema_cases(policy, fixtures, validator):
    good = fixtures["pass"]
    for name, record in fixtures.items():
        check("golden_" + name, validator.is_valid(record))
        check("field_order_" + name, ordered(record, policy["record_schema"], policy["record_schema"]))
        check("array_order_" + name, array_ordered(record, policy))
    cases = [
        ("unknown_schema", ["schema_version"], 2),
        ("result_enum", ["result"], "SUCCESS"),
        ("boolean_issue", ["subject", "issue"], True),
        ("string_issue", ["subject", "issue"], "218"),
        ("negative_count", ["summary", "passed"], -1),
        ("string_signature", ["verification", "commit_signature_verified"], "true"),
        ("model_local_assurance", ["provenance", "model", "assurance"], "LOCALLY_OBSERVED"),
        ("model_github_assurance", ["provenance", "model", "assurance"], "GITHUB_VERIFIED"),
        ("model_unavailable_with_values", ["provenance", "model", "assurance"], "UNAVAILABLE"),
        ("plugin_absent", ["provenance", "plugins"], []),
        ("plugin_version_null", ["provenance", "plugins", 0, "version"], None),
        ("plugin_version_empty", ["provenance", "plugins", 0, "version"], ""),
        ("plugin_hash_null", ["provenance", "plugins", 0, "content_sha256"], None),
        ("plugin_hash_invalid", ["provenance", "plugins", 0, "content_sha256"], "invalid"),
        ("plugin_wrong_identity", ["provenance", "plugins", 0, "name"], "replacement"),
        ("plugin_unavailable", ["provenance", "plugins", 0, "assurance"], "UNAVAILABLE"),
        ("skill_absent", ["provenance", "skills"], []),
        ("skill_hash_null", ["provenance", "skills", 0, "content_sha256"], None),
        ("unknown_event", ["events", 0, "type"], "ARBITRARY_EVENT"),
        ("unsafe_classification", ["privacy", "classification"], "SENSITIVE"),
        ("prompt_present", ["privacy", "contains_prompt"], True),
        ("signature_not_verified", ["verification", "commit_signature_verified"], False),
        ("signoff_missing", ["verification", "signed_off"], False),
        ("checks_absent", ["verification", "controls"], []),
    ]
    for name, path, value in cases:
        check(name, not validator.is_valid(replace(good, path, value)))
    for index in range(len(good["provenance"]["skills"])):
        record = copy.deepcopy(good)
        del record["provenance"]["skills"][index]
        check("required_skill_" + str(index), not validator.is_valid(record))


def privacy_cases(policy, good, validator):
    for index, key in enumerate(policy["privacy"]["forbidden_fields"]):
        for location_id, location in enumerate(([], ["provenance", "model"], ["events", 0])):
            record = copy.deepcopy(good)
            node = record
            for part in location:
                node = node[part]
            node[key] = "synthetic-forbidden-input"
            check("forbidden_field_" + str(index) + "_" + str(location_id), not validator.is_valid(record))
    # Synthetic categories only: rejected values and validation messages are never printed.
    invalid = ["text with spaces", "person@example.invalid", "/home/synthetic", "192.0.2.1", "Bearer synthetic"]
    for index, value in enumerate(invalid):
        check("unsafe_metadata_" + str(index), not validator.is_valid(
            replace(good, ["provenance", "model", "requested"], value)
        ))
    for key in good:
        record = copy.deepcopy(good)
        del record[key]
        check("required_field_" + key, not validator.is_valid(record))


def assurance_cases(good, validator):
    check("model_version_identifier", validator.is_valid(
        replace(good, ["provenance", "model", "requested"], "synthetic-model-1.2")
    ))
    model = good["provenance"]["model"]
    attested = dict(model, requested="synthetic-model-1.2", observed="synthetic-model-1.2", assurance="PROVIDER_ATTESTED")
    check("provider_attested_model", validator.is_valid(replace(good, ["provenance", "model"], attested)))
    check("self_declared_observation", not validator.is_valid(
        replace(good, ["provenance", "model", "observed"], "synthetic-model")
    ))
    check("attested_without_observation", not validator.is_valid(
        replace(good, ["provenance", "model", "assurance"], "PROVIDER_ATTESTED")
    ))
    unavailable = {"requested": None, "observed": None, "reasoning_effort": None, "assurance": "UNAVAILABLE"}
    check("unavailable_is_explicit", validator.is_valid(replace(good, ["provenance", "model"], unavailable)))


def outcome_cases(policy, good, validator):
    rows = [
        ([], "FAIL"),
        ([{"control": "AUDIT_SCHEMA", "result": "PASS"}], "PASS"),
        ([{"control": "AUDIT_SCHEMA", "result": "FAIL"}], "FAIL"),
        ([{"control": "AUDIT_SCHEMA", "result": "SKIP"}], "FAIL"),
        ([{"control": "OPTIONAL_DIAGNOSTICS", "result": "SKIP"}], "SKIP"),
        ([{"control": "OPTIONAL_DIAGNOSTICS", "result": "FAIL"}], "FAIL"),
        ([{"control": "UNKNOWN", "result": "PASS"}], "FAIL"),
    ]
    for index, (checks, expected) in enumerate(rows):
        check("outcome_" + str(index), aggregate(checks, policy) == expected)
    check("result_exit_codes", policy["outcomes"]["exit_codes"] == {"PASS": 0, "FAIL": 1, "SKIP": 0})
    check("precedence", policy["outcomes"]["precedence"] == ["FAIL", "PASS", "SKIP"])
    for index, item in enumerate(good["verification"]["controls"]):
        if policy["controls"][item["control"]]["mandatory"]:
            record = replace(good, ["verification", "controls", index, "result"], "SKIP")
            record["verification"]["controls"][index]["reason_code"] = "NOT_APPLICABLE"
            check("mandatory_skip_" + str(index), not validator.is_valid(record))


def ordering_cases(policy, good):
    scrambled = dict(reversed(list(good.items())))
    check("top_order_rejected", not ordered(scrambled, policy["record_schema"], policy["record_schema"]))
    record = replace(good, ["subject"], dict(reversed(list(good["subject"].items()))))
    check("nested_order_rejected", not ordered(record, policy["record_schema"], policy["record_schema"]))
    record = replace(good, ["provenance", "skills"], list(reversed(good["provenance"]["skills"])))
    check("skill_order_rejected", not array_ordered(record, policy))
    record = replace(good, ["events", 0, "sequence"], 2)
    check("event_gap_rejected", not array_ordered(record, policy))


def policy_cases(policy, manifest):
    definitions = policy["record_schema"]["$defs"]
    check("assurance_levels", definitions["assurance"]["enum"] == [
        "PROVIDER_ATTESTED", "GITHUB_VERIFIED", "LOCALLY_OBSERVED", "SELF_DECLARED", "UNAVAILABLE"
    ])
    check("skills_match_required_plugin", definitions["skill_name"]["enum"] == manifest["required_plugins"]["superpowers"]["skills"])
    check("controls_match_schema", sorted(definitions["control_id"]["enum"]) == sorted(policy["controls"]))
    for name in ("AUDIT_PRIVACY", "AUDIT_SCHEMA", "AUDIT_INTEGRITY", "PROVENANCE_SCHEMA", "SUPERPOWERS", "COMMIT_SIGNATURE", "PRIVILEGED_WORKFLOW_TRUST"):
        check("non_bypassable_" + name, policy["controls"][name] == {"mandatory": True, "human_exception_eligible": False})
    check("retention_bounded", type(policy["privacy"]["sanitized_ci_retention_days"]) is int and policy["privacy"]["sanitized_ci_retention_days"] == 30)
    check("raw_retention_zero", policy["privacy"]["raw_evidence_retention"] == "DELETE_AFTER_VALIDATION_INCLUDING_FAILURE")
    check("bypass_states", definitions["bypass_state"]["enum"] == ["REQUESTED", "APPROVED", "DENIED", "EXPIRED", "EXERCISED"])
    check("bypass_transitions", policy["bypasses"]["transitions"] == {
        "REQUESTED": ["APPROVED", "DENIED", "EXPIRED"], "APPROVED": ["EXPIRED", "EXERCISED"],
        "DENIED": [], "EXPIRED": [], "EXERCISED": []
    })
    check("bypass_max_seconds", policy["bypasses"]["maximum_validity_seconds"] == 86400)
    check("expiry_event", "BYPASS_EXPIRED" in definitions["event_type"]["enum"])
    check("no_fallback", policy["provenance"]["superpowers"]["fallback_allowed"] is False)
    check("digest_scope", policy["serialization"]["integrity"]["excluded_pointer"] == "/integrity/sha256")


def integrity_cases(policy, fixtures):
    def digest(record):
        payload = copy.deepcopy(record)
        parent, field = policy["serialization"]["integrity"]["excluded_pointer"].strip("/").split("/")
        del payload[parent][field]
        return hashlib.sha256(rfc8785.dumps(payload)).hexdigest()

    for name, record in fixtures.items():
        expected = record["integrity"]["sha256"]
        check("golden_integrity_" + name, digest(record) == expected)
        display = json.dumps(record, separators=(",", ":"), ensure_ascii=False) + "\n"
        check("golden_bytes_" + name, display == (HERE / "fixtures" / (name + ".golden")).read_text())
        check("integrity_tamper_" + name, digest(replace(record, ["subject", "issue"], 219)) != expected)
        check("integrity_event_deletion_" + name, digest(replace(record, ["events"], [])) != expected)
        check("integrity_digest_exclusion_" + name, digest(replace(record, ["integrity", "sha256"], "0" * 64)) == expected)
        checks = record["verification"]["controls"]
        check("golden_aggregate_" + name, aggregate(checks, policy) == record["result"])
        counts = {
            key: sum(item["result"] == result for item in checks)
            for key, result in (("passed", "PASS"), ("failed", "FAIL"), ("skipped", "SKIP"))
        }
        check("golden_counts_" + name, all(record["summary"][key] == count for key, count in counts.items()))


def nested_structure_cases(good, validator):
    def visit(node, path):
        if isinstance(node, dict):
            extra = dict(node, unrecognized="synthetic")
            candidate = replace(good, path, extra) if path else extra
            check("closed_object_" + str(len(RESULTS)), not validator.is_valid(candidate))
            for key in node:
                missing = {name: value for name, value in node.items() if name != key}
                candidate = replace(good, path, missing) if path else missing
                check("required_nested_" + str(len(RESULTS)), not validator.is_valid(candidate))
                visit(node[key], path + [key])
        elif isinstance(node, list):
            for index, value in enumerate(node):
                visit(value, path + [index])

    visit(good, [])


def bypass_structure_cases(policy, good, validator):
    bypass = {
        "id": 1, "control": "REQUIRED_CHECKS", "state": "REQUESTED",
        "reason_code": "DEPENDENCY_OUTAGE", "requesting_human_id": 100,
        "approving_human_id": None, "issue": 218, "sha": "2" * 40,
        "requested_at": "2026-09-11T12:00:00Z", "expires_at": "2026-09-12T12:00:00Z",
        "compensating_controls": ["AUDIT_SCHEMA"], "approval_reference": None,
    }
    record = replace(good, ["result"], "FAIL")
    record["bypasses"] = [bypass]
    check("bypass_request_structure", validator.is_valid(record))
    for state in ("DENIED", "EXPIRED"):
        check("bypass_state_" + state, validator.is_valid(replace(record, ["bypasses", 0, "state"], state)))
    for state in ("APPROVED", "EXERCISED"):
        check("bypass_approval_required_" + state, not validator.is_valid(replace(record, ["bypasses", 0, "state"], state)))
    for control, classification in policy["controls"].items():
        if not classification["human_exception_eligible"]:
            check("bypass_ineligible_" + control, not validator.is_valid(replace(record, ["bypasses", 0, "control"], control)))
    check("bypass_unknown_state", not validator.is_valid(replace(record, ["bypasses", 0, "state"], "UNKNOWN")))
    check("bypass_invalid_time", not validator.is_valid(replace(record, ["bypasses", 0, "expires_at"], "2026-99-99T12:00:00Z")))


def event_reference_cases(good, validator):
    record = replace(good, ["result"], "FAIL")
    event = {
        "sequence": 1, "type": "BYPASS_REQUESTED", "bypass_id": 1,
        "result": "PASS", "reason_code": "NONE", "evidence": []
    }
    record["events"] = [event, dict(event, sequence=2, bypass_id=2)]
    check("distinct_bypass_event_ids", validator.is_valid(record))
    check("bypass_event_requires_id", not validator.is_valid(replace(record, ["events", 0, "bypass_id"], None)))
    check("ordinary_event_no_bypass_id", not validator.is_valid(replace(record, ["events", 0, "type"], "SESSION_STARTED")))
    record["events"] = [copy.deepcopy(good["events"][0])]
    references = [
        {"kind": "COMMIT", "id": None, "sha": "2" * 40, "attempt": None, "assurance": "GITHUB_VERIFIED"},
        {"kind": "ISSUE", "id": 218, "sha": None, "attempt": None, "assurance": "GITHUB_VERIFIED"},
        {"kind": "WORKFLOW_RUN", "id": 100, "sha": "2" * 40, "attempt": 1, "assurance": "GITHUB_VERIFIED"},
    ]
    for index, evidence in enumerate(references):
        candidate = replace(record, ["events", 0, "evidence"], [evidence])
        check("typed_reference_" + str(index), validator.is_valid(candidate))
        empty = dict(evidence, id=None, sha=None, attempt=None)
        check("empty_reference_" + str(index), not validator.is_valid(replace(record, ["events", 0, "evidence"], [empty])))


def nested_order_cases(policy, record):
    schema = policy["record_schema"]
    reference = record["bypasses"][0]["approval_reference"]
    scrambled = replace(record, ["bypasses", 0, "approval_reference"], dict(reversed(list(reference.items()))))
    check("approval_reference_order_rejected", not ordered(scrambled, schema, schema))
    evidence = record["events"][0]["evidence"]
    scrambled = replace(record, ["events", 0, "evidence"], list(reversed(evidence)))
    check("nested_evidence_order_rejected", not array_ordered(scrambled, policy))
    duplicate = replace(record, ["events", 0, "evidence"], [evidence[0], evidence[0]])
    check("nested_evidence_duplicate_rejected", not array_ordered(duplicate, policy))
    controls = record["bypasses"][0]["compensating_controls"]
    scrambled = replace(record, ["bypasses", 0, "compensating_controls"], list(reversed(controls)))
    check("compensating_order_rejected", not array_ordered(scrambled, policy))
    duplicate = replace(record, ["bypasses", 0, "compensating_controls"], [controls[0], controls[0]])
    check("compensating_duplicate_rejected", not array_ordered(duplicate, policy))
    # Probe null-first comparator independently of evidence-kind structural constraints.
    null_id = dict(evidence[0], id=None)
    null_first = replace(record, ["events", 0, "evidence"], [null_id, evidence[0]])
    null_last = replace(record, ["events", 0, "evidence"], [evidence[0], null_id])
    check("nested_null_first", array_ordered(null_first, policy))
    check("nested_null_last_rejected", not array_ordered(null_last, policy))


def main():
    manifest = json.loads((HERE.parent / "agent-workflow.json").read_text())
    if "audit" not in manifest:
        return report("AUDIT_POLICY_MISSING")
    policy = manifest["audit"]
    schema = policy["record_schema"]
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    fixtures = {name: json.loads((HERE / "fixtures" / (name + ".json")).read_text()) for name in ("pass", "fail", "skip", "bypasses")}
    schema_cases(policy, fixtures, validator)
    privacy_cases(policy, fixtures["pass"], validator)
    assurance_cases(fixtures["pass"], validator)
    outcome_cases(policy, fixtures["pass"], validator)
    ordering_cases(policy, fixtures["pass"])
    policy_cases(policy, manifest)
    integrity_cases(policy, fixtures)
    nested_structure_cases(fixtures["pass"], validator)
    bypass_structure_cases(policy, fixtures["pass"], validator)
    event_reference_cases(fixtures["pass"], validator)
    nested_order_cases(policy, fixtures["bypasses"])
    check("unique_test_identifiers", len({item["check"] for item in RESULTS}) == len(RESULTS))
    return report()


if __name__ == "__main__":
    try:
        status = main()
    except Exception:
        # Exception messages may contain input values or paths. Emit only a stable code.
        status = report("AUDIT_CONTRACT_INVALID")
    sys.exit(status)
