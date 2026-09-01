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

# GitHub Copilot code review does not review pull requests opened by a GitHub
# App or bot, so a Copilot review can never appear on a trusted-automation
# maintenance PR (Dependabot, or release-please running under the Writer App).
# Skip the gate for those; the required checks, the breaking-change E2E gate,
# and the separate Reviewer App approval still apply.
pr_author="$(jq -r '.user.login // ""' "$pr_file")"
case "$pr_author" in
    *"[bot]")
        echo "pull request author $pr_author is a bot; Copilot review is not applicable"
        exit 0
        ;;
esac

requested_login="$(jq -r '
    [.requested_reviewers[]?.login // empty | select(test("copilot"; "i"))] | first // empty
    ' "$pr_file")"
copilot_login="$configured_login"
if [ -z "$copilot_login" ]; then
    copilot_login="$requested_login"
fi

if [ -z "$copilot_login" ]; then
    exit 0
fi

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
