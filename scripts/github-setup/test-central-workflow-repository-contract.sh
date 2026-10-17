#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow="$repo_root/.github/workflows/create-central-workflow-repository.yml"
seed_root="$repo_root/templates/centralized-actions-workflows"

fail() {
    echo "central workflow repository contract: $*" >&2
    exit 1
}

[ -f "$workflow" ] || fail "dedicated central repository workflow is missing"
[ -d "$seed_root" ] || fail "central workflow seed directory is missing"

grep -q '^name: Create Central Workflow Repository$' "$workflow" ||
    fail "workflow name is not explicit"
grep -q '^  workflow_dispatch:$' "$workflow" ||
    fail "workflow must be manually gated"
grep -q 'repo_owner:' "$workflow" || fail "workflow must accept repository owner"
grep -q 'repo_name:' "$workflow" || fail "workflow must accept repository name"
grep -q 'release_reviewer:' "$workflow" ||
    fail "workflow must require a release-environment reviewer"
grep -q 'templates/centralized-actions-workflows' "$workflow" ||
    fail "workflow must seed the centralized workflow package"
grep -q 'apply-repo-settings' "$workflow" ||
    fail "workflow must apply repository settings"
grep -q 'sha_pinning_required' "$workflow" ||
    fail "workflow must require SHA-pinned Actions"
grep -q 'ruleset-central-tags.json' "$workflow" ||
    fail "workflow must apply the central release-tag ruleset"
grep -R -q 'release-please' "$seed_root/.github/workflows" ||
    fail "central seed must include semantic release automation"

pull_request_workflow="$seed_root/.github/workflows/central-pull-request.yml"
release_workflow="$seed_root/.github/workflows/publish-release.yml"
grep -q '^name: pull-request$' "$pull_request_workflow" ||
    fail "central repository must publish the pull-request workflow check name"
grep -q '^  pull_request:' "$pull_request_workflow" ||
    fail "central repository must trigger its own pull-request check"
grep -q '^  aggregate:' "$pull_request_workflow" ||
    fail "central pull-request workflow must expose an aggregate job"
grep -q 'environment: production' "$release_workflow" ||
    fail "central release publisher must use the protected production environment"
grep -q 'manage_environments: "false"' "$workflow" ||
    fail "central provisioning must create its explicit development/production environments"
grep -q 'environments/development' "$workflow" ||
    fail "central provisioning must create and verify the development environment"
grep -q 'environments/production' "$workflow" ||
    fail "central provisioning must create and verify the production environment"
grep -q 'config-file:' "$release_workflow" ||
    fail "central release publisher must use release-please config"
grep -q 'manifest-file:' "$release_workflow" ||
    fail "central release publisher must use release-please manifest"
if grep -qE '^          (package-name|bump-minor-pre-major):' "$release_workflow"; then
    fail "central release publisher must not pass unsupported v5 action inputs"
fi
release_sha="$(grep -oE 'googleapis/release-please-action@[0-9a-f]+' "$release_workflow" | cut -d@ -f2)"
[[ "$release_sha" =~ ^[0-9a-f]{40}$ ]] ||
    fail "central release publisher must pin a 40-character action SHA"

for workflow_file in "$seed_root"/.github/workflows/*.yml; do
    case "$(basename "$workflow_file")" in
        central-pull-request.yml | publish-release.yml)
            grep -q '^  push:' "$workflow_file" ||
                grep -q '^  pull_request:' "$workflow_file" ||
                fail "central repository event workflow has no supported trigger: $workflow_file"
            continue
            ;;
    esac
    grep -q '^  workflow_call:' "$workflow_file" ||
        fail "central seed workflow is not reusable: $workflow_file"
    if grep -Eq '^  (push|pull_request|workflow_dispatch):' "$workflow_file"; then
        fail "central seed workflow has a repository event trigger: $workflow_file"
    fi
done

echo "central workflow repository contract checks passed."
