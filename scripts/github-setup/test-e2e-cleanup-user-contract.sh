#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workflow="$script_dir/../../.github/workflows/cleanup-archived-e2e.yml"
user_script="$script_dir/cleanup-e2e-user-repositories.sh"

test -x "$user_script"
grep -Fq "source \"\$script_dir/cleanup-e2e-repositories-common.sh\"" "$user_script"
grep -Fq "cleanup_archived_e2e_repositories \"/users/\$APP_OWNER/repos\"" "$user_script"
grep -Fq 'cleanup-e2e-user-repositories.sh' "$workflow"
grep -Fq 'permission_profile: e2e-lifecycle' "$workflow"
grep -Fq 'BOOTSTRAP_E2E_APP_PRIVATE_KEY' "$workflow"
grep -Fq 'E2E_GH_TOKEN' "$workflow"
grep -Fq 'BOOTSTRAP_E2E_ALLOWED_OWNERS' "$workflow"
grep -Fq 'BOOTSTRAP_E2E_CENTRAL_REPOSITORY' "$workflow"
grep -Fq 'min_age_days:' "$workflow"
grep -Fq "MIN_AGE_DAYS: \${{ inputs.min_age_days || '90' }}" "$workflow"

if grep -Eq 'owner_type=|repos_endpoint=|/orgs/|/users/|gh api --include --method DELETE' "$workflow"; then
    echo "user cleanup workflow contains owner-selection or cleanup implementation" >&2
    exit 1
fi

echo "E2E cleanup user contract passed."
