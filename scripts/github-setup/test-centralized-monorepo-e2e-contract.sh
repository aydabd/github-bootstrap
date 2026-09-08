#!/usr/bin/env bash
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
grep -q 'LANGUAGES="all"' "$workflow"
grep -q 'workflow_call' "$workflow"
grep -q 'quality.yml' "$workflow"
grep -Eq 'consumer.*quality|quality.*consumer' "$workflow"
grep -q 'cleanup_after_test' "$workflow"
grep -Eq 'central.*repo|repo.*central' "$workflow"
grep -q 'seed-centralized-e2e-repository.sh' "$workflow"
grep -q 'central_repo_name' "$workflow"
grep -q 'central_ref' "$workflow"
grep -q 'central_repository' "$workflow"
test -x "$seed_script"
grep -q 'gh repo create' "$seed_script"
grep -q 'push "https://x-access-token' "$seed_script"

grep -q 'test-centralized-monorepo:' "$makefile"
grep -q 'preset=centralized-monorepo' "$makefile"
grep -q 'languages=all' "$makefile"
grep -q 'cleanup_after_test=false' "$makefile"

test -f "$seed_root/.github/workflows/quality.yml"
grep -q '^  workflow_call:' "$seed_root/.github/workflows/quality.yml"
if grep -Eq '^  (push|pull_request|workflow_dispatch):' "$seed_root/.github/workflows/quality.yml"; then
    echo "central seed quality workflow has a repository event trigger" >&2
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
