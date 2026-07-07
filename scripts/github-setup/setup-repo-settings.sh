#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2218
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/github-setup/gh-common.sh
source "$script_dir/gh-common.sh"

owner=""
repo=""
settings_file=".github/config/repo-settings.json"

usage() {
    cat << 'USAGE'
Usage: scripts/github-setup/setup-repo-settings.sh --owner OWNER --repo REPO [options]

Applies repository PATCH settings from JSON using local gh authentication.

Options:
        --owner OWNER           Target repository owner.
        --repo REPO             Target repository name.
        --settings-file PATH    Repository settings JSON file.
                            Default: .github/config/repo-settings.json
        --help                  Show this help.

Examples:
    scripts/github-setup/setup-repo-settings.sh --owner my-org --repo my-repo
    scripts/github-setup/setup-repo-settings.sh --owner my-org --repo my-repo --settings-file .github/config/repo-settings.json
USAGE
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --settings-file)
                require_option_value "$1" "${2:-}"
                settings_file="${2:-}"
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
    require_file "$settings_file" "settings file"
}

apply_repo_settings() {
    gh_api_json \
        --method PATCH \
        "$(repo_endpoint)" \
        --input "$settings_file"
}

main() {
    parse_args "$@"
    validate_inputs
    apply_repo_settings
    echo "Repository settings applied to $owner/$repo from $settings_file."
}

main "$@"
