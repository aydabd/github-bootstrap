#!/usr/bin/env bash
set -euo pipefail

run_file="${1:-}"
pr_file="${2:-}"
changed_files="${3:-}"
owner="${OWNER:-}"
repository="${REPOSITORY:-}"
writer_app_slug="${WRITER_APP_SLUG:-}"

if ! [ -s "$run_file" ] || ! [ -s "$pr_file" ] || ! [ -f "$changed_files" ]; then
    echo "workflow approval validation inputs are incomplete" >&2
    exit 1
fi
if [ -z "$owner" ] || [ -z "$repository" ] || [ -z "$writer_app_slug" ]; then
    echo "workflow approval validation identity is incomplete" >&2
    exit 1
fi

full_repository="$owner/$repository"
jq -e --arg full_repository "$full_repository" '.status == "completed" and .conclusion == "action_required" and .event == "pull_request" and ((.path == ".github/workflows/quality.yml" and .name == "Quality") or (.path == ".github/workflows/commit-policy.yml" and .name == "Commit policy") or (.path == ".github/workflows/test-quality-providers.yml" and .name == "Test Quality Providers") or (.path == ".github/workflows/codeql.yml" and .name == "CodeQL Security Scan")) and .repository.full_name == $full_repository and .head_repository.full_name == $full_repository and (.pull_requests | type == "array" and length == 1)' "$run_file" > /dev/null || {
    echo "workflow run is not eligible for approval" >&2
    exit 1
}

jq -e --arg full_repository "$full_repository" --arg writer_app_slug "$writer_app_slug" --slurpfile run "$run_file" '.state == "open" and .base.repo.full_name == $full_repository and .head.repo.full_name == $full_repository and .head.sha == $run[0].head_sha and .number == $run[0].pull_requests[0].number and (.user.login == "dependabot[bot]" or .user.login == ($writer_app_slug + "[bot]") or ((.user.login == "release-please[bot]" or .user.login == "github-actions[bot]") and any(.labels[]?; .name == "autorelease: pending")))' "$pr_file" > /dev/null || {
    echo "pull request is not eligible for workflow approval" >&2
    exit 1
}

while IFS= read -r path; do
    case "$path" in
        .github/workflows/* | .github/actions/*)
            echo "workflow approval rejected for workflow change: $path" >&2
            exit 1
            ;;
    esac
done < "$changed_files"
