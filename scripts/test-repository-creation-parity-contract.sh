#!/usr/bin/env bash
# shellcheck disable=SC2016 # These quoted GitHub expressions are literal contract text.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
api_workflow="$repo_root/.github/workflows/create-repository.yml"
terraform_workflow="$repo_root/.github/workflows/terraform-create-repository.yml"
terraform_main="$repo_root/terraform/main.tf"

fail() {
    echo "repository creation parity contract failure: $1" >&2
    exit 1
}

step_line() {
    local workflow="$1"
    local step="$2"
    local matches
    local line

    matches="$(grep -Fxc -- "$step" "$workflow" || true)"
    [ "$matches" -eq 1 ] ||
        fail "expected exactly one '$step' step in $workflow, found $matches"

    line="$(awk -v step="$step" 'index($0, step) == 1 { print NR; exit }' "$workflow")"
    [ -n "$line" ] || fail "could not locate '$step' step in $workflow"
    printf '%s\n' "$line"
}

grep -Fq 'E2E_FIXTURE_LOGIN: ${{ inputs.app_owner }}' "$api_workflow" ||
    fail "API workflow fixture login binding is missing"
grep -Fq 'E2E_FIXTURE_LOGIN: ${{ inputs.app_owner }}' "$terraform_workflow" ||
    fail "Terraform workflow fixture login binding is not equivalent to the API workflow"

for workflow in "$api_workflow" "$terraform_workflow"; do
    grep -A4 '^      central_ref:$' "$workflow" | grep -Fq 'type: string' ||
        fail "central_ref must be a string input in $workflow"
    grep -Fq 'if [ "$DELIVERY_MODE" = "centralized" ] && ! [[ "$CENTRAL_REPOSITORY" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?/[A-Za-z0-9._-]{1,100}$ ]]; then' "$workflow" ||
        fail "central_repository validation is not aligned with the profile contract in $workflow"
    grep -Fq 'if [ "$DELIVERY_MODE" = "centralized" ] && ! [[ "$CENTRAL_REF" =~ ^(v[0-9]+\.[0-9]+\.[0-9]+|[0-9a-fA-F]{40})$ ]]; then' "$workflow" ||
        fail "central_ref validation is not immutable and semver-only in $workflow"
    grep -A4 '^      team_name:$' "$workflow" | grep -Fq 'default: ""' ||
        fail "team_name must default to the authenticated owner in $workflow"
    grep -Fq 'CODEOWNERS_OWNER: ${{ inputs.app_owner }}' "$workflow" ||
        fail "CODEOWNERS owner fallback is missing in $workflow"
    grep -Fq 'os.environ["TEAM_NAME"] or os.environ["CODEOWNERS_OWNER"]' "$workflow" ||
        fail "CODEOWNERS does not fall back to app_owner in $workflow"
done

api_filter_line="$(step_line "$api_workflow" '      - name: Remove unselected workflows')"
api_codeowners_line="$(step_line "$api_workflow" '      - name: Configure CODEOWNERS')"
terraform_filter_line="$(step_line "$terraform_workflow" '      - name: Remove unselected workflows')"
terraform_codeowners_line="$(step_line "$terraform_workflow" '      - name: Configure CODEOWNERS')"
[ "$api_filter_line" -lt "$api_codeowners_line" ] || fail "API workflow filter order changed"
[ "$terraform_filter_line" -lt "$terraform_codeowners_line" ] ||
    fail "Terraform workflow filters workflows after CODEOWNERS parity point"

grep -Fq 'enable_repo_settings: ${{ inputs.enable_repo_settings }}' "$api_workflow" ||
    fail "API workflow settings toggle is missing"
grep -Fq 'enable_repo_settings: ${{ inputs.enable_repo_settings }}' "$terraform_workflow" ||
    fail "Terraform workflow settings toggle is missing"
if awk '/^      - name: Apply repository settings/,/^      - name: Apply repository labels/' "$terraform_workflow" |
    grep -Eq 'apply_repository_settings:|manage_environments:'; then
    fail "Terraform workflow overrides shared repository settings behavior"
fi

if grep -Eq 'vulnerability_alerts|allow_squash_merge|allow_merge_commit|allow_rebase_merge|allow_auto_merge|allow_update_branch|delete_branch_on_merge' "$terraform_main"; then
    fail "Terraform repository resource owns settings that must remain in the shared API settings action"
fi
if grep -Fq 'protected_branches     = true' "$terraform_main"; then
    fail "Terraform production environment adds policy not present in the API workflow"
fi
if grep -Eq 'enable_branch_protection|github_branch_protection|resource "github_repository_ruleset"' "$terraform_main" "$terraform_workflow"; then
    fail "Terraform main must not own deprecated or duplicate repository protection"
fi

echo "Repository creation parity contract passed."
