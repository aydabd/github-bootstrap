#!/usr/bin/env bash
# shellcheck disable=SC2016 # GitHub expressions are literal contract text.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
action="$repo_root/.github/actions/resolve-gh-token/action.yml"

fail() {
    echo "token connector contract failure: $1" >&2
    exit 1
}

[ -f "$action" ] || fail "resolve-gh-token action is missing"

for input in app_installation_identity token_mode; do
    grep -Fq "  ${input}:" "$action" || fail "portable input ${input} is missing"
done

grep -Fq 'value: ${{ steps.finalize.outputs.token_mode }}' "$action" ||
    fail "normalized token_mode output is missing"
grep -Fq 'value: ${{ steps.finalize.outputs.connector_metadata }}' "$action" ||
    fail "connector metadata output is missing"
grep -Fq 'APP_INSTALLATION_IDENTITY: ${{ inputs.app_installation_identity }}' "$action" ||
    fail "App installation identity is not passed to validation"
grep -Fq 'TOKEN_MODE: ${{ inputs.token_mode }}' "$action" ||
    fail "token mode is not passed to validation"
grep -Fq 'auto|installation|bootstrap-refresh|user' "$action" ||
    fail "legacy user token mode alias is not accepted"
grep -Fq 'app_installation_identity: ${{ needs.validate-portable-configuration.outputs.app_installation_identity }}' "$repo_root/.github/workflows/create-repository.yml" ||
    fail "API repository creation does not pass the portable App identity"
grep -Fq 'token_mode: ${{ needs.validate-portable-configuration.outputs.token_mode || '\''auto'\'' }}' "$repo_root/.github/workflows/create-repository.yml" ||
    fail "API repository creation does not pass the normalized token mode"
grep -Fq 'app_installation_identity: ${{ needs.validate-portable-configuration.outputs.app_installation_identity }}' "$repo_root/.github/workflows/terraform-create-repository.yml" ||
    fail "Terraform repository creation does not pass the portable App identity"
grep -Fq 'token_mode: ${{ needs.validate-portable-configuration.outputs.token_mode || '\''auto'\'' }}' "$repo_root/.github/workflows/terraform-create-repository.yml" ||
    fail "Terraform repository creation does not pass the normalized token mode"
grep -Fq 'app_installation_identity must be a GitHub-safe identifier' "$action" ||
    fail "App installation identity validation is missing"
grep -Fq 'Cross-owner repository scope is not allowed' "$action" ||
    fail "cross-owner repository scope validation is missing"
grep -Fq 'if [ -n "$REPOSITORIES" ]; then' "$action" ||
    fail "optional repository creation scope is not guarded"
grep -Fq 'bootstrap-refresh is not allowed for runtime profiles' "$action" ||
    fail "runtime refresh-token restriction is missing"
grep -Fq 'NORMALIZED_TOKEN_MODE=installation' "$action" ||
    fail "installation mode normalization is missing"
grep -Fq 'token_mode=' "$action" ||
    fail "normalized token mode is not emitted"
grep -Fq 'connector_metadata=' "$action" ||
    fail "connector metadata is not emitted"
if grep -Fq 'TOKEN_MODE_INPUT' "$action"; then
    fail "stale token mode variable remains in the connector"
fi

if grep -Fq 'echo "token=$APP_USER_TOKEN"' "$action"; then
    fail "raw user token must not be emitted by the connector metadata path"
fi

echo "Token connector contract passed."
