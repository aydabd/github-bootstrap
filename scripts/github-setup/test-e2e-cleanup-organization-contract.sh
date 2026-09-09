#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
organization_script="$script_dir/cleanup-e2e-organization-repositories.sh"

test -x "$organization_script"
grep -Fq "source \"\$script_dir/cleanup-e2e-repositories-common.sh\"" "$organization_script"
grep -Fq "cleanup_archived_e2e_repositories \"/orgs/\$APP_OWNER/repos\"" "$organization_script"

echo "E2E cleanup organization contract passed."
