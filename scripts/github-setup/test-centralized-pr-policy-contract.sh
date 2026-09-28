#!/usr/bin/env bash
# shellcheck disable=SC2016 # These quoted shell fragments are literal contract text.
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

grep -q '^      central-repository:' "$workflow" || fail "central PR policy must accept its package repository"
grep -q '^      central-ref:' "$workflow" || fail "central PR policy must accept its immutable package ref"

for action in verify-conventional-commits verify-pull-request-title verify-signed-off-by; do
    grep -Fq "uses: ./.github/central-workflows/.github/actions/$action" "$workflow" ||
        fail "reusable policy workflow must resolve central $action from its package checkout"
done

grep -Fq 'path: .github/central-workflows' "$workflow" ||
    fail "reusable policy workflow must check out the central package"

if grep -E -n 'uses: \.?/?\.github/actions/(verify|setup)' "$workflow"; then
    fail "central PR policy workflow must not use an invalid action path"
fi

jq -e '
    (.reusable_workflows | index(".github/workflows/pr-policy.yml")) != null and
    (.reusable_actions | sort) == [
        ".github/actions/verify-conventional-commits",
        ".github/actions/verify-pull-request-title",
        ".github/actions/verify-signed-off-by"
    ]
' "$manifest" > /dev/null || fail "central manifest does not register the PR policy package"

consumer="$repo_root/templates/.github/workflows/centralized-pull-request.yml"
if test -e "$repo_root/templates/.github/workflows/centralized-commit-policy.yml"; then
    fail "legacy centralized commit-policy adapter must be removed"
fi
grep -q '^  pull_request:' "$consumer" || fail "consumer PR policy adapter must retain its event trigger"
grep -q '{{CENTRAL_REPOSITORY}}/.github/workflows/pull-request.yml@{{CENTRAL_REF}}' "$consumer" ||
    fail "consumer PR adapter must call the immutable central aggregate workflow"
test -f "$repo_root/templates/.github/workflows/commit-policy.yml" ||
    fail "embedded consumer PR policy workflow is missing"
grep -Eq 'uses: \.\/\.github\/actions\/(verify-conventional-commits|verify-pull-request-title|verify-signed-off-by)' \
    "$repo_root/templates/.github/workflows/commit-policy.yml" ||
    fail "embedded consumer PR policy workflow must retain local policy actions"

for creation_workflow in \
    "$repo_root/.github/workflows/create-repository.yml" \
    "$repo_root/.github/workflows/terraform-create-repository.yml"; do
    grep -q 'centralized-pull-request.yml' "$creation_workflow" ||
        fail "centralized creation path is missing PR policy adapter handling: $creation_workflow"
    grep -q 'steps.validate-inputs.outputs.central_workflow_name' \
        "$creation_workflow" || fail "centralized creation path does not install the PR policy adapter: $creation_workflow"
    grep -q 'verify-conventional-commits' "$creation_workflow" ||
        fail "centralized creation path does not remove embedded PR policy actions: $creation_workflow"
    grep -q "inputs.delivery_mode == 'centralized'" "$creation_workflow" ||
        fail "centralized creation path does not require the aggregate pull-request check"
    grep -q "'pull-request'" "$creation_workflow" ||
        fail "centralized creation path does not pass the aggregate pull-request check to rulesets"
    grep -q 'inputs.delivery_mode' "$creation_workflow" ||
        fail "centralized creation path does not pass delivery mode to workflow selection"
    grep -q 's|{{QUALITY_CAPABILITIES}}|\$PROFILE_CAPABILITIES|g' "$creation_workflow" ||
        fail "centralized creation path does not bind quality capabilities in the consumer adapter"
    grep -q 's|{{ENV_MANAGER}}|.*steps.validate-inputs.outputs.env_manager.*|g' "$creation_workflow" ||
        fail "centralized creation path does not bind the environment manager in the consumer adapter"
    grep -q 'central_workflow_name must be a safe .yml filename' "$creation_workflow" ||
        fail "centralized creation path does not validate the consumer workflow alias"
done
grep -q 'delivery_mode="\${5:-embedded}"' "$repo_root/scripts/select-generated-workflows.sh" ||
    fail "workflow selector does not distinguish centralized delivery"
grep -q 'pull-request.yml' "$repo_root/scripts/select-generated-workflows.sh" ||
    fail "workflow selector does not retain the centralized aggregate adapter"

echo "centralized PR policy contract checks passed."
