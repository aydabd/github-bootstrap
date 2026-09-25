#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
validator="$script_dir/validate-portable-config.sh"
config="$repo_root/templates/.github/config/portable-app-project.json"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_json_result() {
    local expected_result="$1" expected_code="$2" output="$3"
    printf '%s\n' "$output" | jq -e --arg result "$expected_result" --arg code "$expected_code" '
        .schema_version == 1 and .result == $result and
        ([.checks[] | select(.result == "FAIL" and .error_code == $code)] | length) == 1
    ' > /dev/null || fail "expected $expected_result/$expected_code, got: $output"
}

[ -x "$validator" ] || fail "portable config validator is not executable"
[ -f "$config" ] || fail "portable app/project config is missing"

configured_owner="$(jq -r '.project_owner' "$config")"
configured_repository="$(jq -r '.central_repository' "$config")"
configured_ref="$(jq -r '.central_ref' "$config")"
valid_output="$($validator --config-file "$config" --owner "$configured_owner" --repository "$configured_repository" --ref "$configured_ref")"
printf '%s\n' "$valid_output" | jq -e '
    .schema_version == 1 and .result == "PASS" and
    .summary.failed == 0 and .summary.skipped == 0 and
    ([.checks[] | select(.result == "PASS")] | length) >= 7
' > /dev/null || fail "valid config did not produce deterministic PASS output"

temp_root="$(mktemp -d)"
trap 'rm -rf "$temp_root"' EXIT

jq '. + {private_key: "-----BEGIN PRIVATE KEY-----"}' "$config" > "$temp_root/secret.json"
secret_output="$($validator --config-file "$temp_root/secret.json" --owner "$configured_owner" --repository "$configured_repository" --ref "$configured_ref" || true)"
assert_json_result FAIL SECRET_EXPOSURE "$secret_output"

jq '.central_ref = "main"' "$config" > "$temp_root/mutable-ref.json"
mutable_output="$($validator --config-file "$temp_root/mutable-ref.json" --owner "$configured_owner" --repository "$configured_repository" --ref "$configured_ref" || true)"
assert_json_result FAIL IMMUTABLE_REF_REQUIRED "$mutable_output"

jq '.project_owner = "other-user"' "$config" > "$temp_root/wrong-owner.json"
owner_output="$($validator --config-file "$temp_root/wrong-owner.json" --owner "$configured_owner" --repository "$configured_repository" --ref "$configured_ref" || true)"
assert_json_result FAIL PROJECT_OWNER_MISMATCH "$owner_output"

jq '.central_repository = "other-org/governance"' "$config" > "$temp_root/wrong-repository.json"
repository_output="$($validator --config-file "$temp_root/wrong-repository.json" --owner "$configured_owner" --repository "$configured_repository" --ref "$configured_ref" || true)"
assert_json_result FAIL CENTRAL_REPOSITORY_MISMATCH "$repository_output"

invalid_ref_output="$($validator --config-file "$config" --owner "$configured_owner" --repository "$configured_repository" --ref main || true)"
assert_json_result FAIL IMMUTABLE_REF_REQUIRED "$invalid_ref_output"

jq '. + {license_holder: "leniva-ab/license-holder"}' "$config" > "$temp_root/license-holder.json"
license_holder_output="$($validator --config-file "$temp_root/license-holder.json" --owner "$configured_owner" --repository "$configured_repository" --ref "$configured_ref")"
printf '%s\n' "$license_holder_output" | jq -e '
    .result == "PASS" and
    ([.checks[] | select(.check == "license-holder" and .result == "PASS")] | length) == 1
' > /dev/null || fail "safe optional license_holder was not accepted: $license_holder_output"

jq '. + {license_holder: "leniva-ab;rm -rf"}' "$config" > "$temp_root/unsafe-license-holder.json"
unsafe_license_holder_output="$($validator --config-file "$temp_root/unsafe-license-holder.json" --owner "$configured_owner" --repository "$configured_repository" --ref "$configured_ref" || true)"
assert_json_result FAIL INVALID_LICENSE_HOLDER "$unsafe_license_holder_output"

echo "Portable App/Project configuration contract checks passed."
