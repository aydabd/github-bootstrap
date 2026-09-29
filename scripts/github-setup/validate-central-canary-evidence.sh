#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "usage: $0 EVIDENCE_JSON" >&2
    exit 2
}

[[ $# -eq 1 ]] || usage
evidence_file="$1"

if [[ ! -f "$evidence_file" ]]; then
    jq -n --arg file "$evidence_file" '{
        schema_version: 1,
        result: "FAIL",
        evidence_file: $file,
        checks: [{result: "FAIL", check: "input", error_code: "MISSING_EVIDENCE_FILE"}],
        summary: {passed: 0, failed: 1, skipped: 0}
    }'
    exit 1
fi

if ! evidence="$(< "$evidence_file")" || ! jq -e . > /dev/null 2>&1 <<< "$evidence"; then
    jq -n --arg file "$evidence_file" '{
        schema_version: 1,
        result: "FAIL",
        evidence_file: $file,
        checks: [{result: "FAIL", check: "input", error_code: "INVALID_JSON"}],
        summary: {passed: 0, failed: 1, skipped: 0}
    }'
    exit 1
fi

checks='[]'
add_check() {
    local result="$1" check="$2" error_code="" evidence=""
    if [[ $# -ge 3 ]]; then error_code="$3"; fi
    if [[ $# -ge 4 ]]; then evidence="$4"; fi
    checks="$(jq -c \
        --arg result "$result" \
        --arg check "$check" \
        --arg error_code "$error_code" \
        --arg evidence "$evidence" \
        '. + [{result: $result, check: $check} + (if $error_code == "" then {} else {error_code: $error_code} end) + (if $evidence == "" then {} else {evidence: $evidence} end)]' \
        <<< "$checks")"
}

if jq -e '
    type == "object" and
    .schema_version == 1 and
    (.issue == 368) and
    (.repository | type == "string" and test("^[^/[:space:]]+/[^/[:space:]]+$")) and
    (.owner_type == "user" or .owner_type == "organization") and
    (.runtime == "centralized" or .runtime == "bootstrap") and
    (.head_sha | type == "string" and test("^[0-9a-f]{40}$")) and
    (.flows | type == "object") and
    (.safety | type == "object")
' <<< "$evidence" > /dev/null; then
    add_check PASS "shape"
else
    add_check FAIL "shape" "INVALID_EVIDENCE_SHAPE"
fi

required_flows='["aggregate_checks","reviewer_approval","writer_merge","ruleset_enforcement","installation_token_scope","cleanup","human","generated","dependabot","renovate","release_please","rollback_bootstrap","restore_centralized"]'
missing_flows="$(jq -r --argjson required "$required_flows" '
    [$required[] as $flow | select(.flows[$flow]? == null) | $flow] | join(",")
' <<< "$evidence")"
if [[ -z "$missing_flows" ]]; then
    add_check PASS "required-flows"
else
    add_check FAIL "required-flows" "MISSING_REQUIRED_FLOW" "$missing_flows"
fi

failed_flows="$(jq -r --argjson required "$required_flows" '
    [$required[] as $flow | select(.flows[$flow].result? != "PASS") | $flow] | join(",")
' <<< "$evidence")"
if [[ -z "$failed_flows" ]]; then
    add_check PASS "flow-results"
else
    add_check FAIL "flow-results" "FLOW_NOT_PASS" "$failed_flows"
fi

if jq -e '.safety.secrets_exposed == false and .safety.token_values_recorded == false' <<< "$evidence" > /dev/null; then
    add_check PASS "secret-safety"
else
    add_check FAIL "secret-safety" "UNSAFE_EVIDENCE"
fi

secret_keys="$(jq -r '
    [paths(scalars) as $path
    | ($path[-1] | strings)
    | select(test("(^|_)(private_key|client_secret|refresh_token|access_token|token_value|password|credential_value)$"; "i"))]
    | unique | join(",")
' <<< "$evidence")"
secret_values="$(jq -r '
    [.. | strings
    | select(test("gh[pousr]_|github_pat_|-----BEGIN [A-Z ]*PRIVATE KEY-----"; "i"))]
    | length
' <<< "$evidence")"
if [[ -z "$secret_keys" && "$secret_values" -eq 0 ]]; then
    add_check PASS "secret-safety-fields"
else
    if [[ -n "$secret_keys" ]]; then
        add_check FAIL "secret-safety" "SECRET_NAMED_FIELD" "$secret_keys"
    else
        add_check FAIL "secret-safety" "SECRET_VALUE_PATTERN"
    fi
fi

result="$(jq -r 'if any(.[]; .result == "FAIL") then "FAIL" else "PASS" end' <<< "$checks")"
jq -n \
    --arg result "$result" \
    --arg file "$evidence_file" \
    --argjson checks "$checks" \
    '{
        schema_version: 1,
        result: $result,
        evidence_file: $file,
        checks: $checks,
        summary: {
            passed: ($checks | map(select(.result == "PASS")) | length),
            failed: ($checks | map(select(.result == "FAIL")) | length),
            skipped: ($checks | map(select(.result == "SKIP")) | length)
        }
    }'

[[ "$result" == "PASS" ]]
