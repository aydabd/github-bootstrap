#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
seed_root="$repo_root/templates/centralized-actions-workflows"
workflow="$seed_root/.github/workflows/quality.yml"
run_quality="$seed_root/.github/actions/quality/run-quality/action.yml"
run_capability="$seed_root/.github/actions/quality/run-capability/action.yml"
validate_quality="$seed_root/.github/actions/quality/action.yml"
versions="$seed_root/examples/consumer-quality-versions.yml"
caller="$repo_root/templates/.github/workflows/centralized-pull-request.yml"
yaml_lint="$seed_root/scripts/lint-yaml.sh"
yaml_config="$seed_root/.github/actions/quality/run-quality/config/.yaml-lint.yml"
yaml_ignore="$seed_root/.github/actions/quality/run-quality/config/.yaml-lint-ignore"

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
grep -q '^      central-repository:' "$workflow" || fail "workflow must expose central-repository input"
grep -q '^      central-ref:' "$workflow" || fail "workflow must expose central-ref input"
grep -Fq 'path: .central-workflows' "$workflow" || fail "workflow must checkout central package into dedicated path"
grep -Fq 'persist-credentials: false' "$workflow" || fail "central package checkout must not persist credentials"
grep -Fq 'uses: ./.central-workflows/.github/actions/setup-lint-mise' "$workflow" || fail "workflow must resolve mise setup from central checkout"
grep -Fq 'uses: ./.central-workflows/.github/actions/setup-lint-system' "$workflow" || fail "workflow must resolve system setup from central checkout"
grep -Fq 'uses: ./.central-workflows/.github/actions/quality/run-quality' "$workflow" || fail "workflow must resolve quality runner from central checkout"
grep -Fq "inputs['central-repository']" "$workflow" || fail "workflow must use bracket notation for central-repository input"
grep -Fq "inputs['central-ref']" "$workflow" || fail "workflow must use bracket notation for central-ref input"
if grep -Eq 'inputs\.central-(repository|ref)' "$workflow"; then
    fail "workflow must not use dot notation for hyphenated central inputs"
fi

grep -q '^      central-repository: "{{CENTRAL_REPOSITORY}}"$' "$caller" || fail "caller must pass central repository"
grep -q '^      central-ref: "{{CENTRAL_REF}}"$' "$caller" || fail "caller must pass central ref"

if grep -E -q 'uses: /?\./\.github/actions/(setup-lint|quality/run-quality)' "$workflow"; then
    fail "central workflow must not resolve centralized actions from consumer root"
fi

if grep -RF -n '$/.github/actions' "$seed_root/.github"; then
    fail "central package must not use an invalid action path"
fi

centralized_delivery_branch="$({
    awk '
        /- name: Configure quality profile delivery/ { in_step = 1 }
        in_step && /if \[ "\$DELIVERY_MODE" = "centralized" \]; then/ { in_branch = 1 }
        in_branch { print }
        in_branch && /^          else$/ { exit }
    ' "$repo_root/.github/workflows/create-repository.yml"
})"
if grep -Fq '.github/linters' <<< "$centralized_delivery_branch"; then
    fail "centralized delivery must retain consumer linter configuration for pre-commit"
fi

test -f "$versions" || fail "two-version consumer fixture is missing"
refs="$(grep -Eo '@(v[0-9]+\.[0-9]+\.[0-9]+|[0-9a-fA-F]{40})' "$versions" | sort -u)"
ref_count="$(printf '%s\n' "$refs" | sed '/^$/d' | wc -l | tr -d ' ')"
[ "$ref_count" -eq 2 ] || fail "expected two distinct immutable consumer refs"
grep -Fq 'uses: "{{REPOSITORY_OWNER}}/{{REPOSITORY_NAME}}/.github/workflows/quality.yml@' "$versions" ||
    fail "consumer fixture must use the full repository placeholders"

"$yaml_lint" "$repo_root/templates/.github" "$yaml_config" "$yaml_ignore" ||
    fail "generated consumer GitHub YAML must pass the centralized YAML lint contract"

echo "centralized quality interface contract checks passed."
