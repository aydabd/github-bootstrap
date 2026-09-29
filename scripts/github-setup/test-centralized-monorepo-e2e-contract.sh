#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow="$repo_root/.github/workflows/test-repository-creation.yml"
makefile="$repo_root/make/test.mk"
seed_root="$repo_root/templates/centralized-actions-workflows"
seed_script="$repo_root/scripts/github-setup/seed-centralized-e2e-repository.sh"

grep -q '^          - centralized-monorepo$' "$workflow"
grep -q 'PRESET.*centralized-monorepo' "$workflow"
grep -q 'CENTRAL_REPO_NAME' "$workflow"
grep -q 'CENTRAL_REF' "$workflow"
grep -q 'delivery_mode.*centralized' "$workflow"
grep -q 'central_repository' "$workflow"
# A bare "@" (both vars empty) makes gh read the field value as a filename.
grep -q 'central_repository="\${CENTRAL_REPOSITORY:+\${CENTRAL_REPOSITORY}@\${CENTRAL_REF}}"' "$workflow"
grep -q 'LANGUAGES="all"' "$workflow"
grep -q 'workflow_call' "$workflow"
grep -q 'quality.yml' "$workflow"
grep -Eq 'consumer.*quality|quality.*consumer' "$workflow"
grep -q 'gh run view "\$run_id" --repo "\${OWNER}/\${REPO_NAME}" --log-failed' "$workflow"
grep -q 'policy_content=' "$workflow" || {
    echo "E2E must inspect the central PR policy workflow path" >&2
    exit 1
}
grep -q 'aggregate_content=' "$workflow" || {
    echo "E2E must inspect the central aggregate workflow paths" >&2
    exit 1
}
grep -q 'obsolete centralized-pull-request adapter name' "$workflow" || {
    echo "E2E must reject the obsolete consumer adapter path" >&2
    exit 1
}
grep -q 'pull-request / aggregate' "$workflow" || {
    echo "E2E must require the emitted aggregate check context" >&2
    exit 1
}
grep -q 'mergeable_state' "$workflow" || {
    echo "E2E must validate centralized PR mergeability" >&2
    exit 1
}
if ! grep -q 'git/refs' "$workflow" || ! grep -q 'contents' "$workflow" || ! grep -q 'pulls' "$workflow"; then
    echo "centralized E2E must create a disposable pull request for PR workflow validation" >&2
    exit 1
fi
grep -q 'runs?event=pull_request&per_page=20' "$workflow" || {
    echo "centralized E2E must poll the pull-request run it triggered" >&2
    exit 1
}
grep -q 'Signed-off-by: github-actions\[bot\]' "$workflow" || {
    echo "centralized E2E disposable PR commit must satisfy signed-off policy" >&2
    exit 1
}
grep -q 'cleanup_after_test' "$workflow"
grep -q 'app_owner=.*REPO_OWNER' "$workflow"
grep -q 'allowed_repo_owners=.*REPO_OWNER' "$workflow"
grep -q 'provisioner_profile="e2e-provisioner"' "$workflow"
grep -Eq 'central.*repo|repo.*central' "$workflow"
grep -q 'seed-centralized-e2e-repository.sh' "$workflow"
grep -q 'central_repo_name' "$workflow"
grep -q 'central_ref' "$workflow"
grep -q 'central_repository' "$workflow"
test -x "$seed_script"
grep -q 'gh repo create' "$seed_script"
grep -q 'push "https://x-access-token' "$seed_script"
grep -q 'REPOSITORY_OWNER}}' "$seed_script"
grep -q 'REPOSITORY_NAME}}' "$seed_script"

manifest="$seed_root/.github/centralized-workflows.json"
test -f "$manifest"
jq -e '
    .schema_version == 1 and
    .package == "centralized-actions-workflows" and
    (.version | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) and
    .source_repository == "{{REPOSITORY_OWNER}}/{{REPOSITORY_NAME}}" and
    (.reusable_workflows | sort) == [".github/workflows/pr-policy.yml", ".github/workflows/pull-request.yml", ".github/workflows/quality.yml"] and
    ([.capabilities | keys[]] | sort) == ["maintenance-merge", "maintenance-safety", "release-please", "weekly-tooling-updates"] and
    (.capabilities["maintenance-safety"].status == "available" and
        ([.capabilities | to_entries[] |
            select(.key != "maintenance-safety" and .key != "maintenance-merge" and .key != "release-please") | .value.status] |
            all(. == "contract-only")) and
        .capabilities["maintenance-merge"].status == "available" and
        .capabilities["release-please"].status == "available" and
        all(.capabilities[]; .enabled_by_default == false)) and
    .ref_policy.type == "immutable" and
    (.ref_policy.allowed | sort) == ["commit-sha", "semver-release-tag"]
' "$manifest" > /dev/null || {
    echo "centralized workflow package manifest is invalid" >&2
    exit 1
}

grep -q 'test-centralized-monorepo:' "$makefile"
grep -q 'preset=centralized-monorepo' "$makefile"
grep -q 'languages=all' "$makefile"
grep -q 'cleanup_after_test=false' "$makefile"
grep -q 'BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_ID' "$makefile" || {
    echo "centralized E2E Make target must resolve the provisioner client ID" >&2
    exit 1
}
grep -q 'BOOTSTRAP_E2E_APP_OWNER' "$makefile" || {
    echo "centralized E2E Make target must resolve the configured app owner" >&2
    exit 1
}

test -f "$seed_root/.github/workflows/quality.yml"
grep -q '^  workflow_call:' "$seed_root/.github/workflows/quality.yml"
if grep -Eq '^  (push|pull_request|workflow_dispatch):' "$seed_root/.github/workflows/quality.yml"; then
    echo "central seed quality workflow has a repository event trigger" >&2
    exit 1
fi

policy_workflow="$seed_root/.github/workflows/pr-policy.yml"
aggregate_workflow="$seed_root/.github/workflows/pull-request.yml"
grep -Fq 'uses: ./.github/workflows/pr-policy.yml' "$aggregate_workflow"
grep -Fq 'uses: ./.github/workflows/quality.yml' "$aggregate_workflow"
grep -Fq 'path: .central-workflows' "$policy_workflow"
for action in verify-conventional-commits verify-pull-request-title verify-signed-off-by; do
    grep -Fq "uses: ./.central-workflows/.github/actions/$action" "$policy_workflow"
done
if grep -Eq 'uses: \.?/?\.github/central-workflows|path: \.github/central-workflows' \
    "$seed_root"/.github/workflows/*.yml; then
    echo "central package contains a duplicated .github/central-workflows path" >&2
    exit 1
fi

for setup_action in \
    "$seed_root/.github/actions/setup-lint-mise/action.yml" \
    "$seed_root/.github/actions/setup-lint-system/action.yml"; do
    test -f "$setup_action"
done

for seed_workflow in "$seed_root"/.github/workflows/*.yml; do
    grep -q '^  workflow_call:' "$seed_workflow"
    if grep -Eq '^  (push|pull_request|workflow_dispatch):' "$seed_workflow"; then
        echo "central seed workflow has a repository event trigger: $seed_workflow" >&2
        exit 1
    fi
done

echo "centralized monorepo E2E contract checks passed."
