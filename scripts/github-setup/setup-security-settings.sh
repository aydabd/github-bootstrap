#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2218
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/github-setup/gh-common.sh
source "$script_dir/gh-common.sh"

owner=""
repo=""
security_file=".github/config/security-default.json"

usage() {
    cat << 'USAGE'
Usage: scripts/github-setup/setup-security-settings.sh --owner OWNER --repo REPO [options]

Enables selected repository security settings from JSON using local gh auth.

Options:
        --owner OWNER          Target repository owner.
        --repo REPO            Target repository name.
        --security-file PATH   Security settings JSON file.
                        Default: .github/config/security-default.json
        --help                 Show this help.

Config values:
        enabled      Fail if the feature cannot be enabled.
        best-effort  Warn if the feature is unavailable for the repo or plan.
        disabled     Skip the feature.

Examples:
    scripts/github-setup/setup-security-settings.sh --owner my-org --repo my-repo
    scripts/github-setup/setup-security-settings.sh --owner my-org --repo my-repo --security-file .github/config/security-default.json
USAGE
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --security-file)
                require_option_value "$1" "${2:-}"
                security_file="${2:-}"
                shift 2
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                if parse_owner_repo_option "$1" "${2:-}"; then
                    shift 2
                else
                    echo "unknown option: $1" >&2
                    usage >&2
                    exit 1
                fi
                ;;
        esac
    done
}

validate_inputs() {
    require_github_setup_tools
    require_owner_repo
    require_github_owner_repo_names
    require_file "$security_file" "security file"
    if ! jq -e 'all(.[]; . == "enabled" or . == "best-effort" or . == "disabled")' "$security_file" > /dev/null; then
        echo "security file values must be enabled, best-effort, or disabled" >&2
        exit 1
    fi
}

config_value() {
    read_json_key "$security_file" "$1" "disabled"
}

apply_put_feature() {
    local key="$1"
    local endpoint="$2"
    local value
    value="$(config_value "$key")"
    if [ "$value" = "disabled" ]; then
        echo "skipped $key: disabled by config"
        return 0
    fi
    if gh_api_json --method PUT "$endpoint" > /dev/null 2>&1; then
        echo "enabled $key"
        return 0
    fi
    if [ "$value" = "best-effort" ]; then
        echo "warning: $key unsupported or unavailable for this repository" >&2
        return 0
    fi
    echo "failed to enable $key" >&2
    return 1
}

apply_security_and_analysis() {
    local key="$1"
    local api_key="$2"
    local value
    local payload
    value="$(config_value "$key")"
    if [ "$value" = "disabled" ]; then
        echo "skipped $key: disabled by config"
        return 0
    fi

    payload="$(mktemp)"
    jq -n --arg api_key "$api_key" '{security_and_analysis: {($api_key): {status: "enabled"}}}' > "$payload"
    if gh_api_json \
        --method PATCH \
        "$(repo_endpoint)" \
        --input "$payload" > /dev/null 2>&1; then
        rm -f "$payload"
        echo "enabled $key"
        return 0
    fi
    rm -f "$payload"
    if [ "$value" = "best-effort" ]; then
        echo "warning: $key unsupported or unavailable for this repository" >&2
        return 0
    fi
    echo "failed to enable $key" >&2
    return 1
}

apply_security_settings() {
    apply_put_feature "vulnerability_alerts" "$(vulnerability_alerts_endpoint)"
    apply_put_feature "automated_security_fixes" "$(automated_security_fixes_endpoint)"
    apply_security_and_analysis "dependency_graph" "dependency_graph"
    apply_security_and_analysis "secret_scanning" "secret_scanning"
    apply_security_and_analysis "secret_scanning_push_protection" "secret_scanning_push_protection"
    apply_security_and_analysis "private_vulnerability_reporting" "private_vulnerability_reporting"
}

main() {
    parse_args "$@"
    validate_inputs
    apply_security_settings
}

main "$@"
