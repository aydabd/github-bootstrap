#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow="$repo_root/.github/workflows/test-generated-repository-e2e.yml"

if [ ! -f "$workflow" ]; then
    echo "generated repository E2E workflow is missing: $workflow" >&2
    exit 1
fi

generated_repository_job="$(awk '
    /^  generated-repository:/ { in_job = 1 }
    in_job && /^  [A-Za-z0-9_-]+:/ && $0 !~ /^  generated-repository:/ { exit }
    in_job { print }
' "$workflow")"

lifecycle_resolver="$(printf '%s\n' "$generated_repository_job" | awk '
    /- name: Resolve E2E lifecycle token/ { in_block = 1 }
    in_block && /- name:/ && $0 !~ /Resolve E2E lifecycle token/ { exit }
    in_block { print }
')"

printf '%s\n' "$generated_repository_job" | grep -Fq 'max-parallel: 1' || {
    echo "generated repository E2E matrix must serialize personal refresh-token use" >&2
    exit 1
}

printf '%s\n' "$generated_repository_job" | grep -Fq -- '--field provisioner_profile=e2e-provisioner' || {
    echo "generated repository E2E dispatch must select the E2E provisioner profile" >&2
    exit 1
}

if printf '%s\n' "$generated_repository_job" | grep -Fq 'refresh_token_secret_environment:'; then
    echo "generated repository E2E dispatch resolver must not rotate the E2E refresh token" >&2
    exit 1
fi

printf '%s\n' "$generated_repository_job" | grep -Fq 'refresh_token_secret: ""' || {
    echo "generated repository E2E dispatch must use an installation token" >&2
    exit 1
}

printf '%s\n' "$generated_repository_job" | grep -Fq "client_id: \${{ vars.BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_ID }}" || {
    echo "generated repository E2E resolver must use the supplied E2E client ID" >&2
    exit 1
}

if printf '%s\n' "$generated_repository_job" | grep -Fq 'BOOTSTRAP_PRODUCTION_PROVISIONER_APP_'; then
    echo "generated repository E2E must not use legacy shared provisioner credentials" >&2
    exit 1
fi

if printf '%s\n' "$lifecycle_resolver" | grep -Eq 'refresh_token_secret: +"?BOOTSTRAP_'; then
    echo "generated repository E2E lifecycle resolver must not receive a provisioner refresh-secret name" >&2
    exit 1
fi

echo "Generated repository E2E concurrency contract passed."
