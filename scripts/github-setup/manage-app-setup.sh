#!/usr/bin/env bash
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
    done < <(jq -r 'keys[]' "$profile_file")
    jq -cn --arg result "$overall" --arg repository "$repository" --argjson checks "$checks" \
        '{schema_version:1,result:$result,repository:$repository,checks:$checks,summary:{passed:($checks|map(select(.result=="PASS"))|length),failed:($checks|map(select(.result=="FAIL"))|length),skipped:($checks|map(select(.result=="SKIP"))|length)}}'
    [ "$overall" = PASS ]
}

command_name="${1:-}"
case "$command_name" in
    check)
        [ "$#" -eq 1 ] || usage
        check_command
        ;;
    install | rotate)
        [ "$#" -eq 2 ] || usage
        echo "${command_name} is not implemented" >&2
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
