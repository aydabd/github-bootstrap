#!/usr/bin/env bash
set -euo pipefail

pr_file="${1:-}"
reviews_file="${2:-}"
threads_file="${3:-}"
configured_login="${4:-}"

if ! [ -s "$pr_file" ] || ! [ -s "$reviews_file" ] || ! [ -s "$threads_file" ]; then
    echo "Copilot review validation inputs are incomplete" >&2
    exit 1
fi

if [ -z "$configured_login" ]; then
    echo "Configured Copilot review identity is missing" >&2
    exit 1
fi

copilot_login="$configured_login"

head_sha="$(jq -r '.head.sha // empty' "$pr_file")"
[ -n "$head_sha" ] || {
    echo "pull request head SHA is missing" >&2
    exit 1
}

jq -e \
    --arg copilot_login "$copilot_login" \
    --arg head_sha "$head_sha" \
    'any(.[]; (.user.login // "") == $copilot_login and .state == "COMMENTED" and .commit_id == $head_sha)' \
    "$reviews_file" > /dev/null || {
    echo "Copilot review is missing for the current pull request head" >&2
    exit 1
}

jq -e \
    --arg copilot_login "$copilot_login" \
    'all(.[]; (.author_login // "") != $copilot_login or .isResolved == true)' \
    "$threads_file" > /dev/null || {
    echo "Copilot review has unresolved threads" >&2
    exit 1
}
