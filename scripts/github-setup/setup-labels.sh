#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2218
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/github-setup/gh-common.sh
source "$script_dir/gh-common.sh"

owner=""
repo=""
label_file=".github/config/labels-default.json"
label_policy="create-and-update"
created_count=0
updated_count=0
unchanged_count=0

usage() {
    cat << 'USAGE'
Usage: scripts/github-setup/setup-labels.sh --owner OWNER --repo REPO [options]

Creates or updates repository labels from JSON using local gh authentication.

Options:
        --owner OWNER          Target repository owner.
        --repo REPO            Target repository name.
        --label-file PATH      Labels JSON file.
                        Default: .github/config/labels-default.json
        --label-policy POLICY  create-missing or create-and-update.
                        Default: create-and-update
        --help                 Show this help.

Examples:
    scripts/github-setup/setup-labels.sh --owner my-org --repo my-repo
    scripts/github-setup/setup-labels.sh --owner my-org --repo my-repo --label-policy create-missing
USAGE
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --label-file)
                require_option_value "$1" "${2:-}"
                label_file="${2:-}"
                shift 2
                ;;
            --label-policy)
                require_option_value "$1" "${2:-}"
                label_policy="${2:-}"
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
    if [ "$label_policy" != "create-missing" ] && [ "$label_policy" != "create-and-update" ]; then
        echo "invalid label policy: $label_policy" >&2
        echo "allowed values: create-missing, create-and-update" >&2
        exit 1
    fi
    require_file "$label_file" "label file"
}

validate_label_file() {
    if ! jq -e '
        .labels | type == "array"
        and all(.[];
            ((.name // "") | test("^[^\\t\\r\\n]+$"))
            and ((.color // "") | test("^[A-Fa-f0-9]{6}$"))
            and ((.description // "") | test("^[^\\t\\r\\n]*$")))
    ' "$label_file" > /dev/null; then
        echo "label file must contain labels with non-empty names, 6-digit hex colors, and no tab/newline characters" >&2
        exit 1
    fi
}

find_existing_label() {
    local name="$1"
    gh_api_json "$(label_endpoint "$name")" 2> /dev/null || true
}

write_label_payload() {
    local name="$1"
    local color="$2"
    local description="$3"
    local payload="$4"
    jq -n --arg name "$name" --arg color "$color" --arg description "$description" \
        '{name: $name, color: $color, description: $description}' > "$payload"
}

create_label() {
    local payload="$1"
    local response
    local exit_code
    response="$(gh_api_json \
        --method POST \
        "$(labels_endpoint)" \
        --input "$payload" 2>&1)" || {
        exit_code=$?
        echo "$response" >&2
        if printf '%s' "$response" | grep -q "HTTP 404"; then
            echo "failed to create label. Verify the target repository has Issues enabled and the token has label/Issues write access." >&2
        fi
        return "$exit_code"
    }
}

update_label() {
    local name="$1"
    local payload="$2"
    local response
    local exit_code
    response="$(gh_api_json \
        --method PATCH \
        "$(label_endpoint "$name")" \
        --input "$payload" 2>&1)" || {
        exit_code=$?
        echo "$response" >&2
        if printf '%s' "$response" | grep -q "HTTP 404"; then
            echo "failed to update label '$name'. Verify the target repository has Issues enabled and the token has label/Issues write access." >&2
        fi
        return "$exit_code"
    }
}

apply_label() {
    local name="$1"
    local color="$2"
    local description="$3"
    local existing_label
    local existing_color
    local existing_description
    local payload

    existing_label="$(find_existing_label "$name")"
    payload="$(mktemp)"
    write_label_payload "$name" "$color" "$description" "$payload"

    if [ -z "$existing_label" ]; then
        create_label "$payload"
        created_count=$((created_count + 1))
        echo "created label: $name"
        rm -f "$payload"
        return 0
    fi

    existing_color="$(jq -r '.color // ""' <<< "$existing_label")"
    existing_description="$(jq -r '.description // ""' <<< "$existing_label")"
    if [ "$existing_color" = "$color" ] && [ "$existing_description" = "$description" ]; then
        unchanged_count=$((unchanged_count + 1))
        rm -f "$payload"
        return 0
    fi

    if [ "$label_policy" = "create-and-update" ]; then
        update_label "$name" "$payload"
        updated_count=$((updated_count + 1))
        echo "updated label: $name"
    else
        unchanged_count=$((unchanged_count + 1))
        echo "label exists and update disabled: $name"
    fi
    rm -f "$payload"
}

apply_labels() {
    while IFS=$'\t' read -r name color description; do
        apply_label "$name" "$color" "$description"
    done < <(jq -r '.labels[] | [.name, .color, (.description // "")] | @tsv' "$label_file")
}

main() {
    parse_args "$@"
    validate_inputs
    validate_label_file
    apply_labels
    echo "Labels summary: created=$created_count, updated=$updated_count, unchanged=$unchanged_count"
}

main "$@"
