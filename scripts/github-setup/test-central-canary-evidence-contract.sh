#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
validator="$repo_root/scripts/github-setup/validate-central-canary-evidence.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
    echo "central canary evidence contract failure: $1" >&2
    exit 1
}

if [[ ! -x "$validator" ]]; then
    fail "central canary evidence validator is not executable"
fi

required_flows='aggregate_checks reviewer_approval writer_merge ruleset_enforcement installation_token_scope cleanup human generated dependabot renovate release_please rollback_bootstrap restore_centralized'

flows='{}'
for flow in $required_flows; do
    flows="$(jq --arg flow "$flow" '. + {($flow): {result: "PASS", run_id: "123", head_sha: "0123456789012345678901234567890123456789", actor: "test-actor"}}' <<< "$flows")"
done

jq -n --argjson flows "$flows" '{
    schema_version: 1,
    issue: 368,
    repository: "example/canary",
    owner_type: "organization",
    runtime: "centralized",
    head_sha: "0123456789012345678901234567890123456789",
    flows: $flows,
    safety: {secrets_exposed: false, token_values_recorded: false}
}' > "$tmp_dir/valid.json"

valid_output="$("$validator" "$tmp_dir/valid.json")"
printf '%s\n' "$valid_output" | jq -e '.schema_version == 1 and .result == "PASS" and .summary.failed == 0 and .summary.skipped == 0' > /dev/null ||
    fail "valid parity evidence was rejected"

jq 'del(.flows.renovate)' "$tmp_dir/valid.json" > "$tmp_dir/missing-flow.json"
missing_output="$("$validator" "$tmp_dir/missing-flow.json" || true)"
printf '%s\n' "$missing_output" | jq -e '.result == "FAIL" and any(.checks[]; .check == "required-flows" and .error_code == "MISSING_REQUIRED_FLOW")' > /dev/null ||
    fail "missing required flow was not rejected deterministically"

jq '.flows.writer_merge.result = "FAIL"' "$tmp_dir/valid.json" > "$tmp_dir/failed-flow.json"
failed_output="$("$validator" "$tmp_dir/failed-flow.json" || true)"
printf '%s\n' "$failed_output" | jq -e '.result == "FAIL" and any(.checks[]; .check == "flow-results" and .error_code == "FLOW_NOT_PASS")' > /dev/null ||
    fail "failed flow was not rejected deterministically"

jq '.safety = {secrets_exposed: true, token_values_recorded: false}' "$tmp_dir/valid.json" > "$tmp_dir/unsafe.json"
unsafe_output="$("$validator" "$tmp_dir/unsafe.json" || true)"
printf '%s\n' "$unsafe_output" | jq -e '.result == "FAIL" and any(.checks[]; .check == "secret-safety" and .error_code == "UNSAFE_EVIDENCE")' > /dev/null ||
    fail "unsafe evidence was not rejected"

jq '.flows.human.private_key = "should-never-be-recorded"' "$tmp_dir/valid.json" > "$tmp_dir/secret-key.json"
secret_key_output="$("$validator" "$tmp_dir/secret-key.json" || true)"
printf '%s\n' "$secret_key_output" | jq -e '.result == "FAIL" and any(.checks[]; .check == "secret-safety" and .error_code == "SECRET_NAMED_FIELD")' > /dev/null ||
    fail "secret-named evidence field was not rejected"

if GH_TOKEN='ghs_should_not_be_printed' "$validator" "$tmp_dir/valid.json" | grep -Fq 'ghs_should_not_be_printed'; then
    fail "validator leaked an environment token"
fi

echo "Central canary evidence contract passed."
