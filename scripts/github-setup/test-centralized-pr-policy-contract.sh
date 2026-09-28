#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
seed_root="$repo_root/templates/centralized-actions-workflows"
workflow="$seed_root/.github/workflows/pr-policy.yml"
manifest="$seed_root/.github/centralized-workflows.json"

fail() {
    echo "centralized PR policy contract: $*" >&2
    exit 1
}

test -f "$workflow" || fail "central PR policy workflow is missing"
grep -q '^  workflow_call:' "$workflow" || fail "central PR policy workflow must be reusable"
if grep -Eq '^  (push|pull_request|workflow_dispatch):' "$workflow"; then
    fail "central PR policy workflow must not define consumer event triggers"
fi

for action in verify-conventional-commits verify-pull-request-title verify-signed-off-by; do
    action_file="$seed_root/.github/actions/$action/action.yml"
    test -f "$action_file" || fail "central policy action is missing: $action"
    grep -q '^runs:' "$action_file" || fail "central policy action is not executable: $action"
done

grep -Fq 'uses: $/.github/actions/verify-conventional-commits' "$workflow" ||
    fail "reusable policy workflow must resolve central conventional-commit action"
grep -Fq 'uses: $/.github/actions/verify-pull-request-title' "$workflow" ||
    fail "reusable policy workflow must resolve central PR-title action"
grep -Fq 'uses: $/.github/actions/verify-signed-off-by' "$workflow" ||
    fail "reusable policy workflow must resolve central signed-off-by action"

if grep -RFn './.github/actions' "$workflow"; then
    fail "central PR policy workflow must not resolve actions through the consumer workspace"
fi

jq -e '
    (.reusable_workflows | index(".github/workflows/pr-policy.yml")) != null and
    (.reusable_actions | sort) == [
        ".github/actions/verify-conventional-commits",
        ".github/actions/verify-pull-request-title",
        ".github/actions/verify-signed-off-by"
    ]
' "$manifest" > /dev/null || fail "central manifest does not register the PR policy package"

consumer="$repo_root/templates/.github/workflows/centralized-commit-policy.yml"
grep -q '^  pull_request:' "$consumer" || fail "consumer PR policy adapter must retain its event trigger"
grep -q '{{CENTRAL_REPOSITORY}}/.github/workflows/pr-policy.yml@{{CENTRAL_REF}}' "$consumer" ||
    fail "consumer PR policy adapter must call the immutable central workflow"
test -f "$repo_root/templates/.github/workflows/commit-policy.yml" ||
    fail "embedded consumer PR policy workflow is missing"
grep -Eq 'uses: \.\/\.github\/actions\/(verify-conventional-commits|verify-pull-request-title|verify-signed-off-by)' \
    "$repo_root/templates/.github/workflows/commit-policy.yml" ||
    fail "embedded consumer PR policy workflow must retain local policy actions"

for creation_workflow in \
    "$repo_root/.github/workflows/create-repository.yml" \
    "$repo_root/.github/workflows/terraform-create-repository.yml"; do
    grep -q 'centralized-commit-policy.yml' "$creation_workflow" ||
        fail "centralized creation path is missing PR policy adapter handling: $creation_workflow"
    grep -q 'mv .github/workflows/centralized-commit-policy.yml .github/workflows/commit-policy.yml' \
        "$creation_workflow" || fail "centralized creation path does not install the PR policy adapter: $creation_workflow"
    grep -q 'verify-conventional-commits' "$creation_workflow" ||
        fail "centralized creation path does not remove embedded PR policy actions: $creation_workflow"
done

echo "centralized PR policy contract checks passed."
