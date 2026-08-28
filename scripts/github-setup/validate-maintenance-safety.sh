#!/usr/bin/env bash
set -euo pipefail

pr_file="${1:-}"
workflow_runs_file="${2:-}"
e2e_runs_file="${3:-}"
labels_file="${4:-}"
reviews_file="${5:-}"
threads_file="${6:-}"
expected_sha="${7:-}"
copilot_login="${8:-}"

for input_file in "$pr_file" "$workflow_runs_file" "$e2e_runs_file" "$labels_file" "$reviews_file" "$threads_file"; do
    [ -s "$input_file" ] || {
        echo "maintenance safety inputs are incomplete" >&2
        exit 1
    }
done
[ -n "$expected_sha" ] || {
    echo "maintenance safety expected SHA is missing" >&2
    exit 1
}

if ! jq -e 'any(.[]?; .name == "automation: maintenance")' "$labels_file" > /dev/null; then
    exit 0
fi

jq -e --arg expected_sha "$expected_sha" '.head.sha == $expected_sha' "$pr_file" > /dev/null || {
    echo "maintenance safety PR head is stale or mismatched" >&2
    exit 1
}

jq -e '
    any(.[]?; .name == "automation: maintenance") and
    any(.[]?; .name == "automation: validating") and
    all(.[]?; .name != "automation: blocked")
' "$labels_file" > /dev/null || {
    echo "maintenance safety labels are missing or blocked" >&2
    exit 1
}

jq -e '
    . as $runs |
    ["Quality", "Commit policy", "Test Quality Providers", "CodeQL Security Scan"] as $required |
    all($required[]; . as $required_name | any($runs[]?; .name == $required_name and .status == "completed" and .conclusion == "success" and .head_sha == $expected_sha))
' --arg expected_sha "$expected_sha" "$workflow_runs_file" > /dev/null || {
    echo "maintenance workflow approval checks are missing, pending, failed, or stale" >&2
    exit 1
}

if jq -e 'any(.[]?; .name == "automation: breaking")' "$labels_file" > /dev/null; then
    jq -e --arg expected_sha "$expected_sha" 'any(.[]?; .status == "completed" and .conclusion == "success" and .head_sha == $expected_sha)' "$e2e_runs_file" > /dev/null || {
        echo "risk-specific E2E validation is missing, pending, failed, or stale" >&2
        exit 1
    }
fi

copilot_validator="$(dirname "$0")/validate-copilot-review.sh"
"$copilot_validator" "$pr_file" "$reviews_file" "$threads_file" "$copilot_login"
