#!/usr/bin/env bash
set -euo pipefail

pr_file="${1:-}"
reviews_file="${2:-}"
expected_sha="${3:-}"
writer_slug="${4:-}"
reviewer_slug="${5:-}"

if [ ! -s "$pr_file" ] || [ ! -s "$reviews_file" ] || [ -z "$expected_sha" ] ||
    [ -z "$writer_slug" ] || [ -z "$reviewer_slug" ]; then
    echo "maintenance merge-state inputs are incomplete" >&2
    exit 1
fi

jq -e --arg sha "$expected_sha" --arg writer "${writer_slug}[bot]" '
    .head.sha == $sha and .auto_merge != null and
    .auto_merge.merge_method == "SQUASH" and
    .auto_merge.enabled_by.login == $writer
' "$pr_file" > /dev/null || {
    echo "Writer App auto-merge state or actor is missing for the current head" >&2
    exit 1
}

jq -e --arg sha "$expected_sha" --arg reviewer "${reviewer_slug}[bot]" '
    any(.[]?; .user.login == $reviewer and .state == "APPROVED" and
        .commit_id == $sha)
' "$reviews_file" > /dev/null || {
    echo "configured Reviewer App approval is missing for the current head" >&2
    exit 1
}

echo "Maintenance merge authority is valid."
