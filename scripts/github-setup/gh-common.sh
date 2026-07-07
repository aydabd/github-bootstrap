#!/usr/bin/env bash
# shellcheck disable=SC2218

GH_API_ACCEPT_HEADER="Accept: application/vnd.github+json"

gh_api_json() {
    gh api -H "$GH_API_ACCEPT_HEADER" "$@"
}

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" > /dev/null 2>&1; then
        echo "required command not found: $command_name" >&2
        exit 1
    fi
}

require_github_setup_tools() {
    require_command gh
    require_command jq
}

common_script_dir() {
    cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

require_option_value() {
    local option_name="$1"
    local option_value="${2:-}"
    if [ -z "$option_value" ] || [ "${option_value#--}" != "$option_value" ]; then
        echo "$option_name requires a value" >&2
        exit 1
    fi
}

parse_owner_repo_option() {
    local option_name="$1"
    local option_value="${2:-}"
    case "$option_name" in
        --owner)
            require_option_value "$option_name" "$option_value"
            owner="$option_value"
            return 0
            ;;
        --repo)
            require_option_value "$option_name" "$option_value"
            repo="$option_value"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

require_owner_repo() {
    if [ -z "${owner:-}" ] || [ -z "${repo:-}" ]; then
        echo "--owner and --repo are required" >&2
        usage >&2
        exit 1
    fi
}

require_github_owner_repo_names() {
    if ! [[ "$owner" =~ ^[A-Za-z0-9]([A-Za-z0-9_-]{0,37}[A-Za-z0-9])?$ ]]; then
        echo "invalid --owner '$owner': expected a GitHub user or organization name" >&2
        exit 1
    fi
    if ! [[ "$repo" =~ ^[A-Za-z0-9._-]+$ ]]; then
        echo "invalid --repo '$repo': expected a GitHub repository name" >&2
        exit 1
    fi
}

require_file() {
    local path="$1"
    local label="$2"
    if [ ! -f "$path" ]; then
        echo "$label not found: $path" >&2
        exit 1
    fi
}

read_json_key() {
    local file="$1"
    local key="$2"
    local default_value="$3"
    jq -r --arg key "$key" --arg default_value "$default_value" '.[$key] // $default_value' "$file"
}

url_encode() {
    printf '%s' "$1" | jq -sRr @uri
}

is_plan_or_feature_limitation() {
    grep -Eiq "Upgrade to GitHub Pro|public repositories with GitHub Free|rulesets are available|GitHub Advanced Security must be enabled|Copilot is not enabled|Copilot Business|Copilot Enterprise"
}

repo_endpoint() {
    printf '/repos/%s/%s' "$owner" "$repo"
}

labels_endpoint() {
    printf '%s/labels' "$(repo_endpoint)"
}

label_endpoint() {
    local label_name="$1"
    printf '%s/labels/%s' "$(repo_endpoint)" "$(url_encode "$label_name")"
}

rulesets_endpoint() {
    printf '%s/rulesets' "$(repo_endpoint)"
}

ruleset_endpoint() {
    local ruleset_id="$1"
    printf '%s/rulesets/%s' "$(repo_endpoint)" "$ruleset_id"
}

vulnerability_alerts_endpoint() {
    printf '%s/vulnerability-alerts' "$(repo_endpoint)"
}

automated_security_fixes_endpoint() {
    printf '%s/automated-security-fixes' "$(repo_endpoint)"
}
