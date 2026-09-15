#!/usr/bin/env bash
# The assertions below are literal workflow substrings, not shell to expand.
# shellcheck disable=SC2016
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workflow="$script_dir/../../.github/workflows/dispatch-e2e.yml"

[ -f "$workflow" ] || {
    echo "dispatch-e2e workflow is missing: $workflow" >&2
    exit 1
}

assert_contains() {
    grep -Fq -- "$1" "$workflow" || {
        echo "dispatch-e2e workflow is missing expected substring: $1" >&2
        exit 1
    }
}

assert_absent() {
    if grep -Fq -- "$1" "$workflow"; then
        echo "dispatch-e2e workflow must not contain: $1" >&2
        exit 1
    fi
}

# Trigger: a maintenance PR gaining the breaking label, or its head moving while
# the label is present.
assert_contains "pull_request_target:"
assert_contains "types: [labeled, synchronize]"

# Fail-closed gate: at least one explicit e2e label is required, and the head
# must live in this repo so a fork PR can never drive a credentialed dispatch.
assert_contains "contains(github.event.pull_request.labels.*.name, 'e2e: generated-repository')"
assert_contains "contains(github.event.pull_request.labels.*.name, 'e2e: centralized-monorepo')"
assert_contains "github.event.pull_request.head.repo.full_name == github.repository"
assert_contains "github.event.pull_request.base.ref == 'main'"

# The dispatch endpoint needs actions:write, which only the Reviewer App's
# workflow-approval profile carries; the default token stays read-only.
assert_contains "name: Dispatch E2E"
assert_contains "environment: e2e"
assert_contains "permission_profile: workflow-approval"
assert_contains "BOOTSTRAP_E2E_REVIEWER_APP_PRIVATE_KEY"
assert_contains "BOOTSTRAP_E2E_REVIEWER_APP_SLUG"
assert_contains "Resolved App is not the configured E2E Reviewer"
assert_absent "environment: production"
assert_absent "BOOTSTRAP_PRODUCTION_REVIEWER_APP_"
assert_absent "actions: write"

# Dispatch Test Generated Repository E2E against the PR head branch so the run's
# own head_sha is the PR head, and pin the internal creation dispatch with
# head_sha. client_id/app_owner come from configuration, never literals.
assert_contains "gh workflow run test-generated-repository-e2e.yml"
assert_contains '--ref "$head_ref"'
assert_contains '-f head_sha="$head_sha"'
assert_contains '-f client_id="$PROVISIONER_APP_CLIENT_ID"' # repository-creation dispatch still accepts the provisioner client ID
assert_contains '-f app_owner="$E2E_APP_OWNER"'
assert_contains '-f delivery=embedded'
assert_contains 'gh workflow run test-repository-creation.yml'
assert_contains '-f preset=centralized-monorepo'
assert_contains '-f languages=all'
assert_contains '-f cleanup_after_test=true'
assert_contains 'isolated_existing'
assert_contains "vars.BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_ID"
assert_contains '[[ "$head_sha" =~ ^[0-9a-fA-F]{40}$ ]]'

# Both dispatches share the single-use e2e-provisioner refresh token, so the
# generated-repository E2E run must fully complete before the centralized
# monorepo run is dispatched, not race it.
wait_line="$(grep -n 'wait_for_workflow_run test-generated-repository-e2e.yml' "$workflow" | head -n1 | cut -d: -f1)"
dispatch_line="$(grep -n 'gh workflow run test-repository-creation.yml' "$workflow" | head -n1 | cut -d: -f1)"
if [ -z "$wait_line" ] || [ -z "$dispatch_line" ] || [ "$wait_line" -ge "$dispatch_line" ]; then
    echo "test-repository-creation.yml must be dispatched only after test-generated-repository-e2e.yml completes" >&2
    exit 1
fi

# A re-label or repeated synchronize must not stack duplicate E2E runs: a
# per-PR concurrency group serializes attempts, and the run-count check is the
# second guard.
assert_contains "concurrency:"
assert_contains "group: dispatch-e2e-\${{ github.event.pull_request.number }}"
assert_contains 'runs?head_sha=$head_sha&per_page=1'
assert_contains ".total_count"
assert_contains 'wait_for_workflow_run()'
assert_contains 'label failed'
assert_contains '[ "$status" = completed ]'
assert_contains '--arg expected_sha "$expected_sha" \
                --jq'
assert_absent '--jq --arg expected_sha'

assert_contains "RUN_GENERATED_REPOSITORY: \"\${{ contains(github.event.pull_request.labels.*.name, 'e2e: generated-repository') }}\""
assert_contains "RUN_CENTRALIZED_MONOREPO: \"\${{ contains(github.event.pull_request.labels.*.name, 'e2e: centralized-monorepo') }}\""
assert_contains 'if [ "$RUN_GENERATED_REPOSITORY" = "true" ]; then'
assert_contains 'if [ "$RUN_CENTRALIZED_MONOREPO" = "true" ]; then'

labels_file="$script_dir/../../.github/config/labels-default.json"
jq -e '.labels[] | select(.name == "e2e: generated-repository")' "$labels_file" > /dev/null || {
    echo "labels-default.json is missing e2e: generated-repository" >&2
    exit 1
}
jq -e '.labels[] | select(.name == "e2e: centralized-monorepo")' "$labels_file" > /dev/null || {
    echo "labels-default.json is missing e2e: centralized-monorepo" >&2
    exit 1
}

classify_workflow="$script_dir/../../.github/workflows/classify-maintenance-pr.yml"
grep -Fq '"automation: breaking" "e2e: generated-repository"' "$classify_workflow" || {
    echo "classify-maintenance-pr.yml must add e2e: generated-repository alongside automation: breaking so the safety gate's required E2E run still gets dispatched" >&2
    exit 1
}

echo "Dispatch E2E contract passed."
