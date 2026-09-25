#!/usr/bin/env bash
# shellcheck disable=SC2016 # These quoted GitHub expressions are literal contract text.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
api_workflow="$repo_root/.github/workflows/create-repository.yml"
terraform_workflow="$repo_root/.github/workflows/terraform-create-repository.yml"
terraform_main="$repo_root/terraform/main.tf"
terraform_variables="$repo_root/terraform/variables.tf"

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

grep -A6 '^      portable_config:$' "$api_workflow" | grep -Fq 'type: string' ||
    fail "workflow_dispatch portable_config envelope is missing"
grep -A1 '^      portable_config:$' "$api_workflow" | grep -Fq 'license_holder' ||
    fail "portable_config must document license_holder compatibility"
for input in owner_type app_installation_identity app_permission_profile project_owner project_number token_mode; do
    workflow_call_block="$(sed -n '/^  workflow_call:/,/^    secrets:/p' "$api_workflow")"
    printf '%s\n' "$workflow_call_block" | grep -A4 "^      ${input}:$" | grep -Eq 'type: (string|number)' ||
        fail "workflow_call is missing portable input ${input}"
done

resolve_token_block="$(sed -n '/^      - name: Resolve GitHub token/,/^      - name:/p' "$api_workflow")"
printf '%s\n' "$resolve_token_block" | grep -Fq 'app_owner: ${{ inputs.app_owner }}' ||
    fail "repository token resolution must remain bound to inputs.app_owner"
if printf '%s\n' "$resolve_token_block" | grep -Fq 'app_installation_identity'; then
    fail "app_installation_identity must remain metadata-only in this slice"
fi

for variable in owner_type app_installation_identity app_permission_profile project_owner project_number token_mode; do
    grep -Fq "variable \"${variable}\"" "$terraform_variables" ||
        fail "Terraform variable ${variable} is missing"
done

grep -Fq 'name: Validate portable repository configuration' "$api_workflow" ||
    fail "portable configuration preflight job is missing"
preflight_line="$(grep -n '^  validate-portable-configuration:' "$api_workflow" | cut -d: -f1)"
create_line="$(grep -n '^  create-repository:' "$api_workflow" | cut -d: -f1)"
[ -n "$preflight_line" ] && [ "$preflight_line" -lt "$create_line" ] ||
    fail "portable configuration preflight must run before repository creation"
preflight_block="$(sed -n "${preflight_line},${create_line}p" "$api_workflow")"
if printf '%s\n' "$preflight_block" | grep -Eq 'gh (api|repo)|actions/checkout|resolve-gh-token|configure-provisioner'; then
    fail "portable configuration preflight must not contact GitHub"
fi
grep -Fq 'project_owner and project_number must be supplied together' "$api_workflow" ||
    fail "project owner/number pair validation is missing"
grep -Fq 'central_ref must be a vMAJOR.MINOR.PATCH tag or 40-character commit SHA' "$api_workflow" ||
    fail "immutable central ref validation is missing"
grep -Fq 'INPUT_LICENSE_HOLDER: ${{ inputs.license_holder || needs.validate-portable-configuration.outputs.license_holder }}' "$api_workflow" ||
    fail "license_holder compatibility fallback is missing"

terraform_workflow_call="$(sed -n '/^  workflow_call:/,/^    secrets:/p' "$terraform_workflow")"
grep -A6 '^      portable_config:$' "$terraform_workflow" | grep -Fq 'type: string' ||
    fail "Terraform workflow_dispatch portable_config envelope is missing"
grep -A4 '^      license_holder:$' "$terraform_workflow" | grep -Fq 'type: string' ||
    fail "Terraform workflow_dispatch license_holder input was removed"
for input in owner_type app_installation_identity app_permission_profile project_owner project_number token_mode; do
    printf '%s\n' "$terraform_workflow_call" | grep -A4 "^      ${input}:$" | grep -Eq 'type: (string|number)' ||
        fail "Terraform workflow_call is missing portable input ${input}"
done
grep -Fq 'name: Validate portable repository configuration' "$terraform_workflow" ||
    fail "Terraform portable configuration preflight job is missing"
terraform_preflight_line="$(grep -n '^  validate-portable-configuration:' "$terraform_workflow" | cut -d: -f1)"
terraform_create_line="$(grep -n '^  terraform-create-repository:' "$terraform_workflow" | cut -d: -f1)"
[ -n "$terraform_preflight_line" ] && [ "$terraform_preflight_line" -lt "$terraform_create_line" ] ||
    fail "Terraform portable configuration preflight must run before plan/apply job"
terraform_preflight_block="$(sed -n "${terraform_preflight_line},${terraform_create_line}p" "$terraform_workflow")"
if printf '%s\n' "$terraform_preflight_block" | grep -Eq 'gh (api|repo)|actions/checkout|resolve-gh-token|configure-provisioner'; then
    fail "Terraform portable configuration preflight must not contact GitHub"
fi
for variable in owner_type app_installation_identity app_permission_profile project_owner project_number token_mode delivery_mode central_repository central_ref; do
    grep -Fq "TF_VAR_${variable}:" "$terraform_workflow" ||
        fail "Terraform workflow does not pass TF_VAR_${variable}"
done
grep -Fq 'project_owner and project_number must be supplied together' "$terraform_workflow" ||
    fail "Terraform project owner/number pair validation is missing"
grep -Fq 'central_ref must be a vMAJOR.MINOR.PATCH tag or 40-character commit SHA' "$terraform_workflow" ||
    fail "Terraform immutable central ref validation is missing"

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
