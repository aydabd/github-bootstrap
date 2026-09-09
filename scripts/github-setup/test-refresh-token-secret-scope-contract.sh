#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
action="$repo_root/.github/actions/resolve-gh-token/action.yml"
workflow="$repo_root/.github/workflows/test-generated-repository-e2e.yml"

grep -Fq 'refresh_token_secret_environment:' "$action" || {
    echo "resolve-gh-token must expose the refresh-token secret environment input" >&2
    exit 1
}
grep -Fq 'refresh_token_secret:' "$action" || {
    echo "resolve-gh-token must expose the refresh-token secret-name input" >&2
    exit 1
}
refresh_token_secret_block="$(awk '
    /^  refresh_token_secret:$/ { in_block=1 }
    in_block { print }
    in_block && /^  refresh_token_secret_environment:$/ { exit }
' "$action")"
grep -Fq '    required: true' <<< "$refresh_token_secret_block" || {
    echo "resolve-gh-token refresh-token secret-name input must be required" >&2
    exit 1
}
grep -Fq "REFRESH_TOKEN_SECRET: \${{ inputs.refresh_token_secret }}" "$action" || {
    echo "resolve-gh-token must read the generic refresh-token secret-name input" >&2
    exit 1
}
grep -Fq 'REFRESH_TOKEN_SECRET_ENVIRONMENT:' "$action" || {
    echo "resolve-gh-token must read the refresh-token secret environment input" >&2
    exit 1
}
grep -Fq "if [ -z \"\$REFRESH_TOKEN_SECRET_ENVIRONMENT\" ]; then" "$action" || {
    echo "resolve-gh-token must reject refresh without an explicit environment" >&2
    exit 1
}
grep -Fq "gh secret set \"\$REFRESH_TOKEN_SECRET\" --repo \"\$GITHUB_REPOSITORY\" --env \"\$REFRESH_TOKEN_SECRET_ENVIRONMENT\"" "$action" || {
    echo "resolve-gh-token must rotate the configured refresh token in its environment" >&2
    exit 1
}
legacy_prefix='BOOTSTRAP_PROVISIONER_APP_'
for profile_secret in \
    "${legacy_prefix}USER_REFRESH_TOKEN" \
    BOOTSTRAP_E2E_PROVISIONER_APP_USER_REFRESH_TOKEN; do
    if grep -Fq "$profile_secret" "$action"; then
        echo "resolve-gh-token must not hardcode profile-specific secret name $profile_secret" >&2
        exit 1
    fi
done
grep -Fq 'app_user_refresh_token:' "$action" || {
    echo "resolve-gh-token must retain the generic refresh-token credential input" >&2
    exit 1
}
grep -Fq "refresh_token_secret: \${{ env.PROVISIONER_REFRESH_TOKEN_NAME }}" "$repo_root/.github/workflows/create-repository.yml" || {
    echo "generated repository creation must use its selected refresh-token secret" >&2
    exit 1
}
grep -Fq 'environment: e2e-testing' "$workflow" || {
    echo "generated repository E2E must run in the e2e-testing environment" >&2
    exit 1
}

echo "Refresh-token secret scope contract passed."
