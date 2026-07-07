#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2218
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/github-setup/gh-common.sh
source "$script_dir/gh-common.sh"

owner=""
repo=""
ruleset_profile="minimal"

usage() {
    cat << 'USAGE'
Usage: scripts/github-setup/test-local-setup-scripts.sh --owner OWNER --repo REPO [options]

Runs live E2E checks for local setup scripts against an existing test repository.
This script is test-only and expects the caller to create and clean up the repo.

Options:
        --owner OWNER              Target test repository owner.
        --repo REPO                Target test repository name.
        --ruleset-profile PROFILE  default, minimal, or coderabbit.
                            Default: minimal
        --help                     Show this help.

Examples:
    scripts/github-setup/test-local-setup-scripts.sh --owner my-org --repo test-repo
    scripts/github-setup/test-local-setup-scripts.sh --owner my-org --repo test-repo --ruleset-profile coderabbit
USAGE
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --ruleset-profile)
                require_option_value "$1" "${2:-}"
                ruleset_profile="${2:-}"
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
    case "$ruleset_profile" in
        default | minimal | coderabbit) ;;
        *)
            echo "invalid ruleset profile: $ruleset_profile" >&2
            echo "allowed values: default, minimal, coderabbit" >&2
            exit 1
            ;;
    esac
}

ruleset_file_for_profile() {
    case "$ruleset_profile" in
        default) printf '.github/config/ruleset-default.json' ;;
        minimal) printf '.github/config/ruleset-minimal.json' ;;
        coderabbit) printf '.github/config/ruleset-coderabbit.json' ;;
    esac
}

wait_for_repo_api() {
    local attempt
    for ((attempt = 1; attempt <= 30; attempt++)); do
        if gh_api_json "$(repo_endpoint)" > /dev/null 2>&1; then
            break
        fi
        sleep 2
    done
    if [ "$attempt" -gt 30 ]; then
        echo "repository API did not become ready for $owner/$repo" >&2
        exit 1
    fi

    for ((attempt = 1; attempt <= 30; attempt++)); do
        if gh_api_json --paginate "$(labels_endpoint)?per_page=100" > /dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    echo "repository labels API did not become ready for $owner/$repo" >&2
    exit 1
}

run_setup_scripts() {
    echo "running setup-labels.sh"
    "$script_dir/setup-labels.sh" --owner "$owner" --repo "$repo"
    echo "running setup-labels.sh again for idempotency"
    "$script_dir/setup-labels.sh" --owner "$owner" --repo "$repo"
    echo "running setup-repo-settings.sh"
    "$script_dir/setup-repo-settings.sh" --owner "$owner" --repo "$repo"
    echo "running setup-security-settings.sh"
    "$script_dir/setup-security-settings.sh" --owner "$owner" --repo "$repo"
    echo "running setup-ruleset.sh"
    "$script_dir/setup-ruleset.sh" --owner "$owner" --repo "$repo" --ruleset-profile "$ruleset_profile"
    echo "running setup-ruleset.sh again for idempotency"
    "$script_dir/setup-ruleset.sh" --owner "$owner" --repo "$repo" --ruleset-profile "$ruleset_profile"
}

assert_labels() {
    local labels_json
    labels_json="$(gh_api_json --paginate "$(labels_endpoint)?per_page=100")"
    jq -e --argjson actual "$labels_json" '
        .labels as $expected
        | ($actual | map({key: .name, value: .}) | from_entries) as $actual_by_name
        | all($expected[]; . as $label
            | ($actual_by_name[$label.name] != null)
            and (($actual_by_name[$label.name].color | ascii_downcase) == ($label.color | ascii_downcase))
            and (($actual_by_name[$label.name].description // "") == ($label.description // "")))
    ' .github/config/labels-default.json > /dev/null
    echo "labels match expected config"
}

assert_repo_settings() {
    local repo_json
    repo_json="$(gh_api_json "$(repo_endpoint)")"
    jq -e --argjson actual "$repo_json" 'to_entries | all(.[]; $actual[.key] == .value)' .github/config/repo-settings.json > /dev/null
    echo "repository settings match expected config"
}

assert_ruleset() {
    local ruleset_file
    local expected_name
    local rulesets_json
    local ruleset_id
    local ruleset_json
    ruleset_file="$(ruleset_file_for_profile)"
    expected_name="$(read_json_key "$ruleset_file" "name" "default")"
    rulesets_json="$(gh_api_json --paginate "$(rulesets_endpoint)" 2> /dev/null || true)"
    ruleset_id="$(jq -r --arg expected_name "$expected_name" '.[]? | select(.name == $expected_name) | .id // ""' <<< "$rulesets_json" | head -n 1)"

    if [ -z "$ruleset_id" ]; then
        echo "missing ruleset '$expected_name'. If this is a plan-gated repository, use a token/owner that supports repository rulesets." >&2
        exit 1
    fi

    ruleset_json="$(gh_api_json "$(ruleset_endpoint "$ruleset_id")")"
    jq -e --argjson actual "$ruleset_json" '
        (.name == $actual.name)
        and (.target == $actual.target)
        and (.enforcement == $actual.enforcement)
        and (([.rules[]?.type] | sort) == ([$actual.rules[]?.type] | sort))
    ' "$ruleset_file" > /dev/null
    echo "ruleset matches expected profile"
}

assert_security_settings() {
    local repo_json
    if gh_api_json "$(vulnerability_alerts_endpoint)" > /dev/null 2>&1; then
        echo "vulnerability alerts enabled"
    else
        echo "vulnerability alerts are not enabled" >&2
        exit 1
    fi

    if gh_api_json "$(automated_security_fixes_endpoint)" > /dev/null 2>&1; then
        echo "automated security fixes enabled"
    else
        echo "automated security fixes are not enabled" >&2
        exit 1
    fi

    repo_json="$(gh_api_json "$(repo_endpoint)")"
    jq -e '.security_and_analysis.dependency_graph.status == "enabled"' <<< "$repo_json" > /dev/null
    echo "dependency graph enabled"
}

main() {
    parse_args "$@"
    validate_inputs
    wait_for_repo_api
    run_setup_scripts
    assert_labels
    assert_repo_settings
    assert_ruleset
    assert_security_settings
}

main "$@"
