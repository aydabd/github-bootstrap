#!/usr/bin/env bash
set -euo pipefail

config_file=""
expected_owner=""
expected_repository=""
expected_ref=""

usage() {
    cat << 'USAGE'
Usage: validate-portable-config.sh --config-file PATH [--owner OWNER]
[--repository OWNER/REPOSITORY] [--ref IMMUTABLE_REF]
USAGE
}

emit() {
    local result="$1" checks="$2"
    jq -cn --arg result "$result" --argjson checks "$checks" \
        '{schema_version:1,result:$result,checks:$checks,summary:{passed:($checks | map(select(.result == "PASS")) | length),failed:($checks | map(select(.result == "FAIL")) | length),skipped:($checks | map(select(.result == "SKIP")) | length)}}'
}

require_option_value() {
    if [ "$#" -lt 2 ] || [ -z "${2:-}" ] || [[ "${2:-}" == --* ]]; then
        echo "$1 requires a value" >&2
        usage >&2
        exit 2
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --config-file)
            require_option_value "$@"
            config_file="$2"
            shift 2
            ;;
        --owner)
            require_option_value "$@"
            expected_owner="$2"
            shift 2
            ;;
        --repository)
            require_option_value "$@"
            expected_repository="$2"
            shift 2
            ;;
        --ref)
            require_option_value "$@"
            expected_ref="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if ! command -v jq > /dev/null 2>&1; then
    printf '{"schema_version":1,"result":"FAIL","error_code":"JQ_UNAVAILABLE"}\n'
    exit 1
fi

if [ -z "$config_file" ] || [ ! -f "$config_file" ]; then
    printf '{"schema_version":1,"result":"FAIL","error_code":"MISSING_CONFIGURATION"}\n'
    exit 1
fi

if ! jq -e . "$config_file" > /dev/null 2>&1; then
    printf '{"schema_version":1,"result":"FAIL","error_code":"INVALID_JSON"}\n'
    exit 1
fi

checks='[]'
add_check() {
    local result="$1" name="$2" code="$3" evidence="$4"
    checks="$(jq -cn --argjson checks "$checks" --arg result "$result" \
        --arg name "$name" --arg code "$code" --arg evidence "$evidence" \
        '$checks + [({result:$result,check:$name,evidence:$evidence} + (if ($code | length) > 0 then {error_code:$code} else {} end))]')"
}

if jq -e 'type == "object" and (keys | sort) == [
    "app_installation_identity", "app_permission_profile", "central_ref",
    "central_repository", "license_holder", "owner_type", "project_number",
    "project_owner", "schema_version", "token_mode"
]' "$config_file" > /dev/null || jq -e 'type == "object" and (keys | sort) == [
    "app_installation_identity", "app_permission_profile", "central_ref",
    "central_repository", "owner_type", "project_number", "project_owner",
    "schema_version", "token_mode"
]' "$config_file" > /dev/null; then
    add_check PASS config-shape "" "exact version-1 fields are present"
else
    add_check FAIL config-shape INVALID_CONFIGURATION "configuration must contain only the version-1 contract fields"
fi

if jq -e '((has("license_holder") | not) or (.license_holder | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]{0,38}(/[A-Za-z0-9][A-Za-z0-9._-]{0,100})?$")))' "$config_file" > /dev/null; then
    if jq -e '(has("license_holder") | not)' "$config_file" > /dev/null; then
        add_check PASS license-holder "" "optional license_holder is absent"
    else
        add_check PASS license-holder "" "optional license_holder is a GitHub-safe login or OWNER/NAME"
    fi
else
    add_check FAIL license-holder INVALID_LICENSE_HOLDER "license_holder must be a GitHub-safe login or OWNER/NAME"
fi

if jq -e '.schema_version == 1' "$config_file" > /dev/null; then
    add_check PASS schema-version "" "schema_version=1"
else
    add_check FAIL schema-version UNSUPPORTED_SCHEMA_VERSION "schema_version must be 1"
fi

if jq -e '.owner_type == "user" or .owner_type == "organization"' "$config_file" > /dev/null; then
    add_check PASS owner-type "" "owner_type is user or organization"
else
    add_check FAIL owner-type INVALID_OWNER_TYPE "owner_type must be user or organization"
fi

if jq -e '.app_installation_identity | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9-]{0,99}$")' "$config_file" > /dev/null; then
    add_check PASS app-installation-identity "" "installation identity is a GitHub-safe identifier"
else
    add_check FAIL app-installation-identity INVALID_APP_IDENTITY "app_installation_identity must be a non-secret GitHub-safe identifier"
fi

if jq -e '.app_permission_profile | type == "string" and test("^[a-z][a-z0-9-]{0,63}$")' "$config_file" > /dev/null; then
    add_check PASS app-permission-profile "" "permission profile is a portable identifier"
else
    add_check FAIL app-permission-profile INVALID_PERMISSION_PROFILE "app_permission_profile must be a lowercase identifier"
fi

if jq -e '.project_owner | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9-]{0,38}$")' "$config_file" > /dev/null; then
    add_check PASS project-owner "" "project owner is a GitHub login"
else
    add_check FAIL project-owner INVALID_PROJECT_OWNER "project_owner must be a GitHub login"
fi

if jq -e '.project_number | type == "number" and (floor == .) and . > 0' "$config_file" > /dev/null; then
    add_check PASS project-number "" "project number is a positive integer"
else
    add_check FAIL project-number INVALID_PROJECT_NUMBER "project_number must be a positive integer"
fi

if jq -e '.token_mode == "installation" or .token_mode == "bootstrap-refresh"' "$config_file" > /dev/null; then
    add_check PASS token-mode "" "token mode is an allowed non-secret mode"
else
    add_check FAIL token-mode INVALID_TOKEN_MODE "token_mode must be installation or bootstrap-refresh"
fi

if jq -e '.central_repository | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9._-]{1,100}$")' "$config_file" > /dev/null; then
    add_check PASS central-repository "" "central repository is OWNER/REPOSITORY"
else
    add_check FAIL central-repository INVALID_REPOSITORY "central_repository must be OWNER/REPOSITORY"
fi

if jq -e '.central_ref | type == "string" and test("^(v[0-9]+\\.[0-9]+\\.[0-9]+|[0-9a-fA-F]{40})$")' "$config_file" > /dev/null; then
    add_check PASS central-ref "" "central ref is an immutable semver tag or commit SHA"
else
    add_check FAIL central-ref IMMUTABLE_REF_REQUIRED "central_ref must be a semver tag or 40-character commit SHA"
fi

if jq -e '
    [paths(scalars) as $path |
        ($path[-1] | tostring) as $key |
        select($key != "token_mode") |
        select($key | test("(?i)(secret|credential|private.?key|password|refresh.?token|access.?token|client.?secret)"))] |
    length == 0
' "$config_file" > /dev/null &&
    jq -e 'all(.. | scalars; (type != "string") or (test("-----BEGIN|gh[pousr]_|github_pat_|AKIA[0-9A-Z]{16}"; "i") | not))' "$config_file" > /dev/null; then
    add_check PASS secret-free "" "no credential-like fields or values are present"
else
    add_check FAIL secret-free SECRET_EXPOSURE "remove secrets and credential-like fields from portable configuration"
fi

if [ -n "$expected_owner" ] && jq -e --arg expected "$expected_owner" '.project_owner == $expected' "$config_file" > /dev/null; then
    add_check PASS owner-match "" "project owner matches requested owner"
elif [ -n "$expected_owner" ]; then
    add_check FAIL owner-match PROJECT_OWNER_MISMATCH "project_owner does not match --owner"
fi

if [ -n "$expected_repository" ] && jq -e --arg expected "$expected_repository" '.central_repository == $expected' "$config_file" > /dev/null; then
    add_check PASS repository-match "" "central repository matches requested repository"
elif [ -n "$expected_repository" ]; then
    add_check FAIL repository-match CENTRAL_REPOSITORY_MISMATCH "central_repository does not match --repository"
fi

if [ -n "$expected_ref" ] && jq -e --arg expected "$expected_ref" '.central_ref == $expected' "$config_file" > /dev/null; then
    add_check PASS ref-match "" "central ref matches requested ref"
elif [ -n "$expected_ref" ]; then
    add_check FAIL ref-match CENTRAL_REF_MISMATCH "central_ref does not match --ref"
fi

if [ -n "$expected_ref" ] && ! printf '%s\n' "$expected_ref" | grep -Eq '^(v[0-9]+\.[0-9]+\.[0-9]+|[0-9a-fA-F]{40})$'; then
    add_check FAIL requested-ref IMMUTABLE_REF_REQUIRED "--ref must be a semver tag or 40-character commit SHA"
fi

failed="$(printf '%s\n' "$checks" | jq '[.[] | select(.result == "FAIL")] | length')"
if [ "$failed" -eq 0 ]; then
    emit PASS "$checks"
else
    emit FAIL "$checks"
fi
[ "$failed" -eq 0 ]
