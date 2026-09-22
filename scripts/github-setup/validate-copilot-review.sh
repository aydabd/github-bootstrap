#!/usr/bin/env bash
set -euo pipefail

pr_file="${1:-}"
reviews_file="${2:-}"
threads_file="${3:-}"
configured_login="${4:-}"
require_copilot_review="${REQUIRE_COPILOT_REVIEW:-false}"
review_mode="${COPILOT_REVIEW_MODE:-current_head}"

if ! [ -s "$pr_file" ] || ! [ -s "$reviews_file" ] || ! [ -s "$threads_file" ]; then
    echo "Copilot review validation inputs are incomplete" >&2
    exit 1
fi
if [ "$require_copilot_review" != false ] && [ "$require_copilot_review" != true ]; then
    echo "REQUIRE_COPILOT_REVIEW must be true or false" >&2
    exit 1
fi

case "$review_mode" in
    disabled | once | current_head) ;;
    *)
        echo "COPILOT_REVIEW_MODE must be disabled, once, or current_head" >&2
        exit 1
        ;;
esac

# GitHub Copilot code review does not review pull requests opened by a GitHub
# App or bot, so a Copilot review can never appear on a trusted-automation
# maintenance PR. Skip the gate for those; required checks, risk-specific E2E
# validation, and the separate maintenance Reviewer App approval still apply.
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
    if [ "$review_mode" != disabled ] && [ "$require_copilot_review" = true ]; then
        echo "Copilot review identity is missing while review is required" >&2
        exit 1
    fi
    exit 0
fi

head_sha="$(jq -r '.head.sha // empty' "$pr_file")"
[ -n "$head_sha" ] || {
    echo "pull request head SHA is missing" >&2
    exit 1
}

if [ "$review_mode" != disabled ]; then
    case "$review_mode" in
        once)
            # shellcheck disable=SC2016 # jq variables are expanded by jq.
            review_jq='any(.[]; (.user.login // "") == $copilot_login and .state == "COMMENTED")'
            ;;
        current_head)
            # shellcheck disable=SC2016 # jq variables are expanded by jq.
            review_jq='any(.[]; (.user.login // "") == $copilot_login and .state == "COMMENTED" and .commit_id == $head_sha)'
            ;;
    esac
    if ! jq -e --arg copilot_login "$copilot_login" --arg head_sha "$head_sha" \
        "$review_jq" "$reviews_file" > /dev/null; then
        if [ -n "$requested_login" ]; then
            echo "Copilot review is still pending for the current pull request" >&2
        elif [ "$review_mode" = once ]; then
            echo "Copilot review is missing from the pull request history" >&2
        else
            echo "Copilot review is missing for the current pull request head" >&2
        fi
        exit 1
    fi
fi

jq -e \
    --arg copilot_login "$copilot_login" \
    'all(.[]; (.author_login // "") != $copilot_login or .isResolved == true)' \
    "$threads_file" > /dev/null || {
    echo "Copilot review has unresolved threads" >&2
    exit 1
}
