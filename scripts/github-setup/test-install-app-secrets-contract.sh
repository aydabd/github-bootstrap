#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/install-app-secrets.sh"

[ -x "$helper" ] || {
    echo "secret installer is not executable" >&2
    exit 1
}
grep -Fq "source \"\$script_dir/gh-common.sh\"" "$helper"
grep -Fq 'BOOTSTRAP_PROVISIONER_APP_PRIVATE_KEY' "$helper"
grep -Fq 'BOOTSTRAP_PROVISIONER_APP_USER_REFRESH_TOKEN' "$helper"
grep -Fq 'BOOTSTRAP_PROVISIONER_APP_CLIENT_SECRET' "$helper"
grep -Fq 'BOOTSTRAP_PROVISIONER_APP_CLIENT_ID' "$helper"
grep -Fq 'gh secret set' "$helper"
grep -Fq 'gh variable set' "$helper"
grep -Fq 'require_command gh' "$helper"
grep -Fq 'owner_pattern=' "$helper"
grep -Fq 'pem_first_line=' "$helper"
grep -Fq 'pem_last_line=' "$helper"
grep -Fq 'BASH_REMATCH' "$helper"
grep -Fq "sanitized_token_file=\"\$(mktemp)\"" "$helper"
grep -Fq "sanitized_private_key_file=\"\$(mktemp)\"" "$helper"
grep -Fq "gh secret set BOOTSTRAP_PROVISIONER_APP_PRIVATE_KEY --repo \"\$repo\" < \"\$sanitized_private_key_file\"" "$helper"
grep -Fq "gh secret set BOOTSTRAP_PROVISIONER_APP_USER_REFRESH_TOKEN --repo \"\$repo\" < \"\$sanitized_token_file\"" "$helper"
grep -Fq "gh secret set BOOTSTRAP_PROVISIONER_APP_CLIENT_SECRET --repo \"\$repo\" < \"\$sanitized_client_secret_file\"" "$helper"
grep -Fq 'ghr_' "$helper"
grep -Fq 'umask 077' "$helper"
if grep -Eq 'GH_PAT|gh_token|workflow run|workflow_dispatch' "$helper"; then
    echo "secret installer must not implement PAT or workflow credential delivery" >&2
    exit 1
fi
if grep -Fq "echo \"\$token\"" "$helper" || grep -Fq "echo \"\$private_key_file\"" "$helper" || grep -Fq "echo \"\$client_id\"" "$helper"; then
    echo "secret installer must not print credential values" >&2
    exit 1
fi

echo "App secret installer contract checks passed."
