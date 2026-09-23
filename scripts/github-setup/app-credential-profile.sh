#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manifest="$script_dir/app-credential-profiles.json"

usage() {
    echo "Usage: app-credential-profile.sh PROFILE [FIELD]" >&2
    exit 2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

profile="$1"

repository_owner="${BOOTSTRAP_APP_OWNER:-${GITHUB_REPOSITORY_OWNER:-}}"
if [ -z "$repository_owner" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
    repository_owner="${GITHUB_REPOSITORY%%/*}"
fi
owner_pattern='^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$'
if [ -z "$repository_owner" ] || [[ ! "$repository_owner" =~ $owner_pattern ]]; then
    echo "invalid or missing repository owner; set BOOTSTRAP_APP_OWNER or GITHUB_REPOSITORY_OWNER" >&2
    exit 1
fi

if ! jq -e --arg profile "$profile" '.role_order | index($profile) != null' "$manifest" > /dev/null; then
    echo "unknown credential profile: $profile" >&2
    exit 1
fi

if ! jq -e --arg profile "$profile" '.[$profile] | type == "object"' "$manifest" > /dev/null; then
    echo "invalid credential profile: $profile" >&2
    exit 1
fi

case "$profile" in
    e2e-admin)
        required_fields='["client_id_variable", "environment", "private_key_secret"]'
        ;;
    e2e-writer | e2e-reviewer)
        required_fields='["app_slug_variable", "client_id_variable", "environment", "private_key_secret"]'
        ;;
    production-writer | production-reviewer)
        required_fields='["app_slug_variable", "client_id_variable", "environment", "private_key_secret"]'
        ;;
    e2e-fixture)
        required_fields='["app_slug_variable", "client_id_variable", "client_secret_secret", "environment", "private_key_secret", "refresh_token_secret"]'
        ;;
    e2e-provisioner | production-provisioner)
        required_fields='["client_id_variable", "client_secret_secret", "environment", "private_key_secret", "refresh_token_secret"]'
        ;;
    *)
        echo "invalid credential profile: $profile" >&2
        exit 1
        ;;
esac

jq -e --arg profile "$profile" --argjson fields "$required_fields" '
    (.[$profile]) as $profile_data |
    ($profile_data | keys) == $fields and
    all($fields[]; . as $field |
        $profile_data[$field] | type == "string" and length > 0)
' "$manifest" > /dev/null || {
    echo "invalid credential profile fields: $profile" >&2
    exit 1
}

if [ "$#" -eq 1 ]; then
    jq -e --arg profile "$profile" '.[$profile]' "$manifest"
    exit 0
fi

field="$2"
if ! jq -e --arg profile "$profile" --arg field "$field" \
    '($field == "owner" or (.[$profile] | has($field)) or (.profile_metadata[$profile] | has($field)))' \
    "$manifest" > /dev/null; then
    echo "unknown credential profile field: $field" >&2
    exit 1
fi

jq -er --arg profile "$profile" --arg field "$field" --arg owner "$repository_owner" \
    'if .[$profile] | has($field) then .[$profile][$field]
        elif $field == "owner" then $owner
        elif .profile_metadata[$profile] | has($field) then .profile_metadata[$profile][$field]
        else empty end' "$manifest"
