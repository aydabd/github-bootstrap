#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
seed_root="$repo_root/templates/centralized-actions-workflows"
workflow="$seed_root/.github/workflows/quality.yml"
run_quality="$seed_root/.github/actions/quality/run-quality/action.yml"
run_capability="$seed_root/.github/actions/quality/run-capability/action.yml"
validate_quality="$seed_root/.github/actions/quality/action.yml"
versions="$seed_root/examples/consumer-quality-versions.yml"

fail() {
    echo "centralized quality interface contract: $*" >&2
    exit 1
}

for action in "$validate_quality" "$run_capability" "$run_quality"; do
    grep -q '^runs:' "$action" || fail "missing runs declaration in $action"
    grep -q '^  using: composite$' "$action" || fail "action is not composite: $action"
done

grep -q '^  capabilities:' "$validate_quality" || fail "validator must expose capabilities"
grep -q '^  capabilities:' "$run_quality" || fail "runner must expose capabilities"
grep -q '^  capability:' "$run_capability" || fail "single-capability wrapper must expose capability"
grep -q '^  environment-manager:' "$run_quality" || fail "runner must expose environment-manager"
grep -q '^  environment-manager:' "$run_capability" || fail "single-capability wrapper must expose environment-manager"

grep -q '^  workflow_call:' "$workflow" || fail "reusable workflow must expose workflow_call"
grep -q '^      capabilities:' "$workflow" || fail "workflow must expose capabilities input"
grep -q '^      environment-manager:' "$workflow" || fail "workflow must expose environment-manager input"
grep -Fq 'uses: $/.github/actions/setup-lint-mise' "$workflow" || fail "workflow must resolve mise setup from central package"
grep -Fq 'uses: $/.github/actions/setup-lint-system' "$workflow" || fail "workflow must resolve system setup from central package"
grep -Fq 'uses: $/.github/actions/quality/run-quality' "$workflow" || fail "workflow must resolve quality runner from central package"

if grep -RFn './.github/actions' "$seed_root/.github"; then
    fail "central package must not resolve an action through the consumer workspace"
fi

test -f "$versions" || fail "two-version consumer fixture is missing"
refs="$(grep -Eo '@(v[0-9]+\.[0-9]+\.[0-9]+|[0-9a-fA-F]{40})' "$versions" | sort -u)"
ref_count="$(printf '%s\n' "$refs" | sed '/^$/d' | wc -l | tr -d ' ')"
[ "$ref_count" -eq 2 ] || fail "expected two distinct immutable consumer refs"
grep -Fq 'uses: "{{REPOSITORY_OWNER}}/{{REPOSITORY_NAME}}/.github/workflows/quality.yml@' "$versions" ||
    fail "consumer fixture must use the full repository placeholders"

echo "centralized quality interface contract checks passed."
