#!/usr/bin/env bash
# The assertions below are literal workflow substrings, not shell to expand.
# shellcheck disable=SC2016
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workflow="$script_dir/../../.github/workflows/dispatch-maintenance-e2e.yml"

[ -f "$workflow" ] || {
    echo "dispatch-maintenance-e2e workflow is missing: $workflow" >&2
    exit 1
}

assert_contains() {
    grep -Fq -- "$1" "$workflow" || {
        echo "dispatch-maintenance-e2e workflow is missing expected substring: $1" >&2
        exit 1
    }
}

assert_absent() {
    if grep -Fq -- "$1" "$workflow"; then
        echo "dispatch-maintenance-e2e workflow must not contain: $1" >&2
        exit 1
    fi
}

# Trigger: a maintenance PR gaining the breaking label, or its head moving while
# the label is present.
assert_contains "pull_request_target:"
assert_contains "types: [labeled, synchronize]"

# Fail-closed gate: both labels required, and the head must live in this repo so
# a fork PR can never drive a credentialed dispatch.
assert_contains "contains(github.event.pull_request.labels.*.name, 'automation: maintenance')"
assert_contains "contains(github.event.pull_request.labels.*.name, 'automation: breaking')"
assert_contains "github.event.pull_request.head.repo.full_name == github.repository"
assert_contains "github.event.pull_request.base.ref == 'main'"

# The dispatch endpoint needs actions:write, which only the Reviewer App's
# workflow-approval profile carries; the default token stays read-only.
assert_contains "environment: production-maintenance"
assert_contains "permission_profile: workflow-approval"
assert_contains "BOOTSTRAP_REVIEWER_APP_PRIVATE_KEY"
assert_contains "BOOTSTRAP_MAINTENANCE_REVIEWER_APP_SLUG"
assert_contains "Resolved App is not the configured maintenance Reviewer"
assert_absent "actions: write"

# Dispatch Test Generated Repository E2E against the PR head branch so the run's
# own head_sha is the PR head, and pin the internal creation dispatch with
# head_sha. client_id/app_owner come from configuration, never literals.
assert_contains "gh workflow run test-generated-repository-e2e.yml"
assert_contains '--ref "$head_ref"'
assert_contains '-f head_sha="$head_sha"'
assert_contains '-f client_id="$PROVISIONER_APP_CLIENT_ID"'
assert_contains '-f app_owner="$E2E_APP_OWNER"'
assert_contains "vars.BOOTSTRAP_PROVISIONER_APP_CLIENT_ID"
assert_contains '[[ "$head_sha" =~ ^[0-9a-fA-F]{40}$ ]]'

# A re-label or repeated synchronize must not stack duplicate E2E runs: a
# per-PR concurrency group serializes attempts, and the run-count check is the
# second guard.
assert_contains "concurrency:"
assert_contains "group: dispatch-maintenance-e2e-\${{ github.event.pull_request.number }}"
assert_contains 'runs?head_sha=$head_sha&per_page=1'
assert_contains ".total_count"
assert_contains 'already dispatched for $head_sha; nothing to do.'

echo "Dispatch maintenance E2E contract passed."
