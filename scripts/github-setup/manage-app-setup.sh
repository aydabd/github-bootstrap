#!/usr/bin/env bash
# shellcheck disable=SC2218
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
profile_file="$script_dir/app-credential-profiles.json"

usage() {
    echo "Usage: manage-app-setup.sh check" >&2
    echo "       manage-app-setup.sh install ROLE" >&2
    echo "       manage-app-setup.sh rotate ROLE" >&2
    echo "       manage-app-setup.sh cleanup" >&2
    exit 2
}

repository="${GITHUB_REPOSITORY:-local/repository}"

check_profile() {
    local role="$1"
    local required_keys
    case "$role" in
        production-provisioner | e2e-provisioner)
            required_keys='["client_id_variable","client_secret_secret","environment","private_key_secret","refresh_token_secret"]'
            ;;
        e2e-maintenance-fixture)
            required_keys='["app_slug_variable","client_id_variable","client_secret_secret","environment","private_key_secret","refresh_token_secret"]'
            ;;
        e2e-maintenance-writer | e2e-maintenance-reviewer | production-maintenance-writer | production-maintenance-reviewer)
            required_keys='["app_slug_variable","client_id_variable","environment","private_key_secret"]'
            ;;
        *)
            return 1
            ;;
    esac
    jq -e --arg role "$role" --argjson required "$required_keys" '
        .[$role] as $profile |
        ($profile | type == "object") and
        (($profile | keys) == $required) and
        all($required[]; $profile[.] | type == "string" and length > 0)
    ' "$profile_file" > /dev/null
}

manifest_for_role() {
    case "$1" in
        production-provisioner | e2e-provisioner) echo repository-bootstrap-provisioner ;;
        e2e-maintenance-fixture) echo maintenance-fixture-e2e ;;
        e2e-maintenance-writer) echo repository-maintenance-writer-e2e ;;
        e2e-maintenance-reviewer) echo repository-maintenance-reviewer-e2e ;;
        production-maintenance-writer) echo repository-maintenance-writer ;;
        production-maintenance-reviewer) echo repository-maintenance-reviewer ;;
        *) return 1 ;;
    esac
}

check_manifest() {
    local role="$1" manifest_name
    manifest_name="$(manifest_for_role "$role")" || return 1
    jq -e '.name | type == "string" and length > 0' \
        "$script_dir/../../docs/github-app-manifests/$manifest_name.json" > /dev/null
}

check_command() {
    local expected_roles='["e2e-maintenance-fixture","e2e-maintenance-reviewer","e2e-maintenance-writer","e2e-provisioner","production-maintenance-reviewer","production-maintenance-writer","production-provisioner"]'
    local checks='[]' role result overall="PASS"
    jq -e --argjson expected "$expected_roles" 'keys == $expected' "$profile_file" > /dev/null || overall="FAIL"
    while IFS= read -r role; do
        if check_profile "$role"; then
            result="PASS"
        else
            result="FAIL"
            overall="FAIL"
        fi
        checks="$(jq -c --arg result "$result" --arg role "$role" \
            '. + [{result:$result,role:$role,check:"profile-schema",evidence:"required profile fields validated"}]' <<< "$checks")"
        if check_manifest "$role"; then
            result="PASS"
        else
            result="FAIL"
            overall="FAIL"
        fi
        checks="$(jq -c --arg result "$result" --arg role "$role" \
            '. + [{result:$result,role:$role,check:"manifest",evidence:"role manifest exists and has a name"}]' <<< "$checks")"
    done < <(jq -r 'keys[]' "$profile_file")
    jq -cn --arg result "$overall" --arg repository "$repository" --argjson checks "$checks" \
        '{schema_version:1,result:$result,repository:$repository,checks:$checks,summary:{passed:($checks|map(select(.result=="PASS"))|length),failed:($checks|map(select(.result=="FAIL"))|length),skipped:($checks|map(select(.result=="SKIP"))|length)}}'
    [ "$overall" = PASS ]
}

emit_failure() {
    local role="$1" check="$2" error_code="$3" remediation="$4"
    jq -cn --arg repository "$repository" --arg role "$role" --arg check "$check" \
        --arg error_code "$error_code" --arg remediation "$remediation" \
        '{schema_version:1,result:"FAIL",repository:$repository,checks:[{result:"FAIL",role:$role,check:$check,error_code:$error_code,remediation:$remediation}],summary:{passed:0,failed:1,skipped:0}}'
    return 1
}

install_command() {
    local role="$1"
    check_profile "$role" || emit_failure "$role" profile-schema INVALID_PROFILE "use a supported credential profile"
    if [ ! -d "${APP_CREDENTIAL_DIR:-}" ]; then
        emit_failure "$role" credentials MISSING_CREDENTIALS "provide a protected credential directory"
    fi
    echo "install is not implemented" >&2
    return 1
}

command_name="${1:-}"
case "$command_name" in
    check)
        [ "$#" -eq 1 ] || usage
        check_command
        ;;
    install)
        [ "$#" -eq 2 ] || usage
        install_command "$2"
        ;;
    rotate)
        [ "$#" -eq 2 ] || usage
        echo "rotate is not implemented" >&2
        exit 1
        ;;
    cleanup)
        [ "$#" -eq 1 ] || usage
        echo "cleanup is not implemented" >&2
        exit 1
        ;;
    *)
        usage
        ;;
esac
