#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2218
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/github-setup/gh-common.sh
source "$script_dir/gh-common.sh"

owner=""
repo=""
ruleset_profile="default"
ruleset_file=""

usage() {
    cat << 'USAGE'
Usage: scripts/github-setup/setup-ruleset.sh --owner OWNER --repo REPO [options]

Upserts a repository ruleset using local gh authentication.

Options:
        --owner OWNER             Target repository owner.
        --repo REPO               Target repository name.
        --ruleset-profile PROFILE default, minimal, or coderabbit.
                            Default: default
        --ruleset-file PATH       Custom ruleset JSON file. Overrides --ruleset-profile.
        --help                    Show this help.

Examples:
    scripts/github-setup/setup-ruleset.sh --owner my-org --repo my-repo --ruleset-profile minimal
    scripts/github-setup/setup-ruleset.sh --owner my-org --repo my-repo --ruleset-file .github/config/ruleset-coderabbit.json
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
            --ruleset-file)
                require_option_value "$1" "${2:-}"
                ruleset_file="${2:-}"
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

resolve_ruleset_file() {
    if [ -n "$ruleset_file" ]; then
        return 0
    fi
    if [ "$ruleset_profile" = "default" ]; then
        ruleset_file=".github/config/ruleset-default.json"
    elif [ "$ruleset_profile" = "minimal" ]; then
        ruleset_file=".github/config/ruleset-minimal.json"
    elif [ "$ruleset_profile" = "coderabbit" ]; then
        ruleset_file=".github/config/ruleset-coderabbit.json"
    else
        echo "invalid ruleset profile: $ruleset_profile" >&2
        echo "allowed values: default, minimal, coderabbit" >&2
        exit 1
    fi
}

validate_inputs() {
    require_github_setup_tools
    require_owner_repo
    require_github_owner_repo_names
    resolve_ruleset_file
    require_file "$ruleset_file" "ruleset file"
}

read_ruleset_name() {
    read_json_key "$ruleset_file" "name" "default"
}

find_existing_ruleset_id() {
    local ruleset_name="$1"
    local rulesets_file
    rulesets_file="$(mktemp)"
    gh_api_json --paginate "$(rulesets_endpoint)" > "$rulesets_file" 2> /dev/null || true
    jq -r --arg ruleset_name "$ruleset_name" '.[]? | select(.name == $ruleset_name) | .id // ""' "$rulesets_file" | head -n 1
    rm -f "$rulesets_file"
}

upsert_ruleset() {
    local ruleset_name="$1"
    local existing_ruleset_id
    local method
    local endpoint
    local action
    local response
    local exit_code

    existing_ruleset_id="$(find_existing_ruleset_id "$ruleset_name")"
    if [ -n "$existing_ruleset_id" ]; then
        method="PATCH"
        endpoint="$(ruleset_endpoint "$existing_ruleset_id")"
        action="updated"
    else
        method="POST"
        endpoint="$(rulesets_endpoint)"
        action="created"
    fi

    response="$(gh_api_json \
        --method "$method" \
        "$endpoint" \
        --input "$ruleset_file" 2>&1)" || {
        exit_code=$?
        if printf '%s' "$response" | is_plan_or_feature_limitation; then
            echo "warning: ruleset setup skipped due to repository plan or feature limitations" >&2
            echo "$response" >&2
            exit 0
        fi
        echo "$response" >&2
        exit "$exit_code"
    }

    echo "Ruleset '$ruleset_name' $action for $owner/$repo."
}

main() {
    local ruleset_name
    parse_args "$@"
    validate_inputs
    ruleset_name="$(read_ruleset_name)"
    upsert_ruleset "$ruleset_name"
}

main "$@"
