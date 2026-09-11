#!/usr/bin/env bash
set -euo pipefail

releases_file="${1:-}"
tags_file="${2:-}"
merged_sha="${3:-}"
release_started_at="${4:-}"

if [ ! -s "$releases_file" ] || [ ! -s "$tags_file" ] || [ -z "$merged_sha" ] ||
    [ -z "$release_started_at" ]; then
    echo "maintenance release inputs are incomplete" >&2
    exit 1
fi

jq -e --arg sha "$merged_sha" --arg since "$release_started_at" \
    --slurpfile tags "$tags_file" '
    any(.[]?; (.tag_name // "") as $tag |
        ($tag | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) and
        .created_at >= $since and any($tags[][]?; .name == $tag and .commit.sha == $sha))
' "$releases_file" > /dev/null || {
    echo "release tag does not point to the resulting merge head" >&2
    exit 1
}

echo "Maintenance release points to the target merge."
