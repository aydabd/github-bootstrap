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

if [ "$#" -eq 1 ]; then
    jq -e --arg profile "$profile" '.[$profile]' "$manifest"
    exit 0
fi

field="$2"
if ! jq -e --arg profile "$profile" --arg field "$field" '.[$profile] | has($field)' "$manifest" > /dev/null; then
    echo "unknown credential profile field: $field" >&2
    exit 1
fi

jq -er --arg profile "$profile" --arg field "$field" '.[$profile][$field]' "$manifest"
