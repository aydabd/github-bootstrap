#!/usr/bin/env bash
set -euo pipefail

pr_file="${1:-}"
checks_file="${2:-}"
reviews_file="${3:-}"
labels_file="${4:-}"
full_repository="${5:-}"
expected_sha="${6:-}"
writer_app_slug="${7:-}"
reviewer_app_slug="${8:-}"
require_reviewer_approval="${9:-false}"
identity_mode="${MAINTENANCE_IDENTITY_MODE:-production}"
fixture_login="${MAINTENANCE_FIXTURE_LOGIN:-}"
copilot_login="${MAINTENANCE_COPILOT_REVIEWER_LOGIN:-}"

for input_file in "$pr_file" "$checks_file" "$reviews_file" "$labels_file"; do
    [ -s "$input_file" ] || {
        echo "maintenance merge inputs are incomplete" >&2
        exit 1
    }
done

if [ -z "$full_repository" ] || [ -z "$expected_sha" ] ||
    [ -z "$writer_app_slug" ] || [ -z "$reviewer_app_slug" ]; then
    echo "maintenance merge identity is incomplete" >&2
    exit 1
fi
if [ "$writer_app_slug" = "$reviewer_app_slug" ]; then
    echo "Writer and Reviewer App identities must be distinct" >&2
    exit 1
fi
case "$identity_mode" in
    production) fixture_login="" ;;
    e2e-disposable)
        if [ -z "$fixture_login" ] || [ -z "$copilot_login" ]; then
            echo "E2E maintenance identity and Copilot configuration are incomplete" >&2
            exit 1
        fi
        ;;
    *)
        echo "unsupported maintenance identity mode '$identity_mode'" >&2
        exit 1
        ;;
esac

jq -e --arg repository "$full_repository" --arg expected_sha "$expected_sha" \
    --arg writer_app_slug "$writer_app_slug" --arg reviewer_app_slug "$reviewer_app_slug" \
    --arg identity_mode "$identity_mode" --arg fixture_login "$fixture_login" '
    .state == "open" and .draft == false and .base.ref == "main" and
    .base.repo.full_name == $repository and
    .head.repo.full_name == $repository and
    .head.sha == $expected_sha and
    (($identity_mode == "e2e-disposable" and .user.login == $fixture_login) or .user.login == "dependabot[bot]" or .user.login == ($writer_app_slug + "[bot]") or (.user.login == "release-please[bot]" and any(.labels[]?; .name == "autorelease: pending"))) and
    .user.login != ($reviewer_app_slug + "[bot]")
' "$pr_file" > /dev/null || {
    echo "pull request is not eligible for maintenance merge" >&2
    exit 1
}

if [ "$identity_mode" = e2e-disposable ]; then
    jq -e --arg copilot_login "$copilot_login" --arg expected_sha "$expected_sha" \
        'any(.[]?; .user.login == $copilot_login and .state == "COMMENTED" and .commit_id == $expected_sha)' \
        "$reviews_file" > /dev/null || {
        echo "E2E fixture Copilot review evidence is missing for the current head" >&2
        exit 1
    }
fi

jq -e '
    type == "array" and length > 0 and
    all(.[]; .state == "SUCCESS")
' "$checks_file" > /dev/null || {
    echo "required checks are pending, failed, stale, or missing" >&2
    exit 1
}

jq -e '
    any(.[]?; .name == "automation: maintenance") and
    any(.[]?; .name == "automation: validating") and
    all(.[]?; .name != "automation: blocked")
' "$labels_file" > /dev/null || {
    echo "maintenance merge labels are missing or blocked" >&2
    exit 1
}

jq -e 'all(.[]?; .state != "CHANGES_REQUESTED")' "$reviews_file" > /dev/null || {
    echo "pull request has a requested change" >&2
    exit 1
}

if [ "$require_reviewer_approval" = "true" ]; then
    jq -e --arg reviewer_login "${reviewer_app_slug}[bot]" --arg expected_sha "$expected_sha" \
        'any(.[]?; .user.login == $reviewer_login and .state == "APPROVED" and .commit_id == $expected_sha)' \
        "$reviews_file" > /dev/null || {
        echo "Reviewer App approval is missing for the current head" >&2
        exit 1
    }
fi

echo "Maintenance merge inputs are valid."
