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

if ! jq -e --arg profile "$profile" 'has($profile)' "$manifest" > /dev/null; then
    echo "unknown credential profile: $profile" >&2
    exit 1
fi

if ! jq -e --arg profile "$profile" '.[$profile] | type == "object"' "$manifest" > /dev/null; then
    echo "invalid credential profile: $profile" >&2
    exit 1
fi

case "$profile" in
    e2e-maintenance-writer | e2e-maintenance-reviewer)
        required_fields='["app_slug_variable", "client_id_variable", "environment", "private_key_secret"]'
        ;;
    production-maintenance-writer | production-maintenance-reviewer)
        required_fields='["app_slug_variable", "client_id_variable", "environment", "private_key_secret"]'
        ;;
    e2e-maintenance-fixture)
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
if ! jq -e --arg profile "$profile" --arg field "$field" '.[$profile] | has($field)' "$manifest" > /dev/null; then
    echo "unknown credential profile field: $field" >&2
    exit 1
fi

jq -er --arg profile "$profile" --arg field "$field" \
    '.[$profile][$field] | select(type == "string" and length > 0)' "$manifest"
