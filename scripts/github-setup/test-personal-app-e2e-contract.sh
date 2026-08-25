#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow="$repo_root/.github/workflows/test-personal-app-e2e.yml"

grep -Fq 'BOOTSTRAP_APP_CLIENT_ID' "$workflow"
grep -Fq 'BOOTSTRAP_APP_PRIVATE_KEY' "$workflow"
grep -Fq 'BOOTSTRAP_APP_USER_TOKEN' "$workflow"
grep -Fq 'create-repository.yml' "$workflow"
grep -Fq 'visibility: public' "$workflow"
grep -Fq 'visibility: private' "$workflow"
grep -Fq 'gh api --method DELETE' "$workflow"
grep -Fq 'PERSONAL_OWNER' "$workflow"
grep -Fq 'allowed_repo_owners' "$workflow"
grep -Fq 'Invalid personal owner' "$workflow"
grep -Fq 'gh api /user --jq' "$workflow"
grep -Fq "gh api \"/users/\$PERSONAL_OWNER\" --jq" "$workflow"
grep -Fq 'App user token identity does not match personal owner' "$workflow"
grep -Fq 'GitHub owner is not a personal user' "$workflow"
if [ "$(grep -Fc 'workflows: none' "$workflow")" -ne 2 ]; then
    echo "personal E2E must avoid workflow files because the least-privilege App has no Workflows permission" >&2
    exit 1
fi
create_workflow="$repo_root/.github/workflows/create-repository.yml"
grep -Fq "printf 'x-access-token:%s' \"\$GH_TOKEN\" | base64" "$create_workflow"
grep -Fq "http.extraheader=\"AUTHORIZATION: basic \$GIT_AUTH_HEADER\"" "$create_workflow"
grep -Fq "git remote set-url origin \"https://\${GH_HOST}/\${OWNER}/\${REPO_NAME}.git\"" "$create_workflow"
if grep -Fq "http.extraheader=\"AUTHORIZATION: bearer \$GH_TOKEN\"" "$create_workflow"; then
    echo "repository Git operations must not use bearer authentication" >&2
    exit 1
fi
dispatch_block="$(sed -n '/^  workflow_dispatch:/,/^permissions:/p' "$workflow")"
if printf '%s\n' "$dispatch_block" | grep -Eq '^[[:space:]]{6}[A-Za-z0-9_-]*(token|secret|pat|private)'; then
    echo "personal E2E must not accept PATs, credential inputs, or organization permissions" >&2
    exit 1
fi
if grep -Eq 'gh_token:|GH_PAT|organization-administration' "$workflow"; then
    echo "personal E2E must not accept PATs or organization permissions" >&2
    exit 1
fi

echo "Personal App E2E contract checks passed."
