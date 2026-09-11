#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/install-app-secrets.sh"
documentation_files=(
    README.md
    docs/maintenance-operations.md
    docs/github-app-trust-boundaries.md
    examples/launcher-actions.yml
    examples/launcher-terraform.yml
    terraform/README.md
)
audit_paths=(README.md docs examples terraform scripts .github)

for documentation_file in "${documentation_files[@]}"; do
    [ -f "$documentation_file" ] || {
        echo "missing documentation file: $documentation_file" >&2
        exit 1
    }
done

grep -Fq 'production-provisioner' "${documentation_files[@]}"
grep -Fq 'e2e-provisioner' "${documentation_files[@]}"
grep -Fq 'production-provisioning' "${documentation_files[@]}"
grep -Fq 'e2e-testing' "${documentation_files[@]}"
grep -Fq 'BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_ID' "${documentation_files[@]}"
grep -Fq 'BOOTSTRAP_PRODUCTION_PROVISIONER_APP_PRIVATE_KEY' "${documentation_files[@]}"
grep -Fq 'BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_SECRET' "${documentation_files[@]}"
grep -Fq 'BOOTSTRAP_PRODUCTION_PROVISIONER_APP_USER_REFRESH_TOKEN' "${documentation_files[@]}"
grep -Fq 'BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_ID' "${documentation_files[@]}"
grep -Fq 'BOOTSTRAP_E2E_PROVISIONER_APP_PRIVATE_KEY' "${documentation_files[@]}"
grep -Fq 'BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_SECRET' "${documentation_files[@]}"
grep -Fq 'BOOTSTRAP_E2E_PROVISIONER_APP_USER_REFRESH_TOKEN' "${documentation_files[@]}"
grep -Fq 'install-app-secrets.sh OWNER/github-bootstrap production-provisioner' README.md
grep -Fq 'install-app-secrets.sh OWNER/github-bootstrap e2e-provisioner' README.md
if grep -Fq "credential_dir=\"\$HOME/.local/state/github-bootstrap\"" README.md; then
    echo "E2E credential commands must use the e2e-provisioner credential directory" >&2
    exit 1
fi
if grep -Eq '^      client_id:' examples/launcher-actions.yml examples/launcher-terraform.yml; then
    echo "launcher examples must not pass undeclared client_id inputs" >&2
    exit 1
fi
grep -Fq "of no-op: \`BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_ID\` unset in the \`e2e-testing\`" docs/maintenance-operations.md
grep -Fq "with \`head_sha=<PR head>\` and \`app_owner=<owner>\`." docs/maintenance-operations.md
if grep -Fq "\`client_id=<Provisioner client ID>\`" docs/maintenance-operations.md; then
    echo "manual E2E dispatch must not document the removed client_id input" >&2
    exit 1
fi
if grep -Fq "\`head_sha\`, \`client_id\` (Provisioner), and \`app_owner\`" docs/maintenance-operations.md; then
    echo "generated E2E dispatch must not document the removed client_id input" >&2
    exit 1
fi
legacy_prefix='BOOTSTRAP_'
legacy_profile='PROVISIONER_APP_'
if rg -n "${legacy_prefix}${legacy_profile}(CLIENT_ID|PRIVATE_KEY|CLIENT_SECRET|USER_REFRESH_TOKEN)" \
    "${audit_paths[@]}"; then
    echo "operational files must not use shared provisioner credential names" >&2
    exit 1
fi

[ -x "$helper" ] || {
    echo "secret installer is not executable" >&2
    exit 1
}
grep -Fq "source \"\$script_dir/gh-common.sh\"" "$helper"
grep -Fq 'Usage: install-app-secrets.sh REPOSITORY PROFILE CLIENT_ID_FILE PRIVATE_KEY_FILE CLIENT_SECRET_FILE REFRESH_TOKEN_FILE' "$helper"
grep -Fq 'environment variable' "$helper"
grep -Fq 'environment secrets' "$helper"
grep -Fq 'app-credential-profile.sh' "$helper"
grep -Fq 'client_id_variable' "$helper"
grep -Fq 'private_key_secret' "$helper"
grep -Fq 'client_secret_secret' "$helper"
grep -Fq 'refresh_token_secret' "$helper"
grep -Fq 'environment' "$helper"
grep -Fq 'gh secret set' "$helper"
grep -Fq 'gh variable set' "$helper"
grep -Fq 'require_command gh' "$helper"
grep -Fq 'owner_pattern=' "$helper"
grep -Fq 'pem_first_line=' "$helper"
grep -Fq 'pem_last_line=' "$helper"
grep -Fq 'BASH_REMATCH' "$helper"
grep -Fq "sanitized_token_file=\"\$(mktemp)\"" "$helper"
grep -Fq "sanitized_private_key_file=\"\$(mktemp)\"" "$helper"
grep -Fq "GH_TOKEN=\"\$GH_TOKEN\" gh variable set \"\$client_id_variable\" --repo \"\$repo\" --env \"\$environment\"" "$helper"
grep -Fq "GH_TOKEN=\"\$GH_TOKEN\" gh secret set \"\$private_key_secret\" --repo \"\$repo\" --env \"\$environment\"" "$helper"
grep -Fq "GH_TOKEN=\"\$GH_TOKEN\" gh secret set \"\$client_secret_secret\" --repo \"\$repo\" --env \"\$environment\"" "$helper"
grep -Fq "GH_TOKEN=\"\$GH_TOKEN\" gh secret set \"\$refresh_token_secret\" --repo \"\$repo\" --env \"\$environment\"" "$helper"
grep -Fq "GH_TOKEN=\"\$GH_TOKEN\" gh variable set \"\$app_slug_variable\"" "$helper"
grep -Fq "< \"\$sanitized_private_key_file\"" "$helper"
grep -Fq "< \"\$sanitized_client_secret_file\"" "$helper"
grep -Fq "< \"\$sanitized_token_file\"" "$helper"
grep -Fq 'ghr_' "$helper"
grep -Fq 'umask 077' "$helper"
grep -Fq "if [ -z \"\${GH_TOKEN:-}\" ]; then" "$helper"
if grep -Eq "${legacy_prefix}${legacy_profile}" "$helper"; then
    echo "secret installer must not hardcode legacy provisioner credential names" >&2
    exit 1
fi
if grep -Eq 'GH_PAT|gh_token|workflow run|workflow_dispatch' "$helper"; then
    echo "secret installer must not implement PAT or workflow credential delivery" >&2
    exit 1
fi
if grep -Fq "echo \"\$token\"" "$helper" || grep -Fq "echo \"\$private_key_file\"" "$helper" || grep -Fq "echo \"\$client_id\"" "$helper"; then
    echo "secret installer must not print credential values" >&2
    exit 1
fi

test_tmp_dir="$(mktemp -d)"
trap 'rm -rf "$test_tmp_dir"' EXIT
mkdir "$test_tmp_dir/bin"
gh_calls="$test_tmp_dir/gh-calls"
: > "$gh_calls"
cat > "$test_tmp_dir/bin/gh" << EOF
#!/usr/bin/env bash
printf '%s\\n' "\$*" >> "$gh_calls"
exit 99
EOF
chmod +x "$test_tmp_dir/bin/gh"
printf '123456789\\n' > "$test_tmp_dir/client-id"
printf '%s\\n' '-----BEGIN PRIVATE KEY-----' 'key' '-----END PRIVATE KEY-----' > "$test_tmp_dir/private-key"
printf 'client-secret\\n' > "$test_tmp_dir/client-secret"
printf 'ghr_test-token\\n' > "$test_tmp_dir/refresh-token"
if GH_TOKEN=contract-test-token PATH="$test_tmp_dir/bin:$PATH" "$helper" \
    octo/repo unknown-profile "$test_tmp_dir/client-id" "$test_tmp_dir/private-key" \
    "$test_tmp_dir/client-secret" "$test_tmp_dir/refresh-token" \
    2> "$test_tmp_dir/installer-error"; then
    echo "unknown credential profile must be rejected" >&2
    exit 1
fi
grep -Fq 'unknown credential profile: unknown-profile' "$test_tmp_dir/installer-error"
if [ -s "$gh_calls" ]; then
    echo "unknown credential profile must be rejected before GitHub mutation" >&2
    exit 1
fi

echo "App secret installer contract checks passed."
