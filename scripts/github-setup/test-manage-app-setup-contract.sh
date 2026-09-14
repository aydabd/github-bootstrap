#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
orchestrator="$script_dir/manage-app-setup.sh"

[ -x "$orchestrator" ] || {
    echo "manage-app-setup.sh must be executable" >&2
    exit 1
}

output="$(GITHUB_REPOSITORY=aydabd/github-bootstrap "$orchestrator" check)"
printf '%s' "$output" | jq -e '
    .schema_version == 1 and
    .result == "PASS" and
    .repository == "aydabd/github-bootstrap" and
    (.checks | length) > 0 and
    ([.checks[] | select(.check == "manifest") ] | length) == 7 and
    (all(.checks[] | select(.check == "manifest"); .result == "PASS")) and
    ([.checks[] | select(.check == "production-e2e-isolation") ] | length) == 1 and
    (all(.checks[] | select(.check == "production-e2e-isolation"); .result == "PASS")) and
    (.summary.passed == (.checks | map(select(.result == "PASS")) | length)) and
    (.summary.failed == 0) and
    (.summary.skipped == 0)
' > /dev/null

if printf '%s' "$output" | grep -Eiq 'gho_|ghr_|BEGIN .*PRIVATE KEY|client[_-]?secret|client[_-]?id'; then
    echo "orchestrator output contains credential-like material" >&2
    exit 1
fi

set +e
install_output="$(GITHUB_REPOSITORY=aydabd/github-bootstrap \
    APP_CREDENTIAL_DIR=/private/tmp \
    "$orchestrator" install e2e-provisioner 2> /dev/null)"
install_status="$?"
set -e
[ "$install_status" -eq 1 ] || {
    echo "install must fail with status 1 when credentials are missing" >&2
    exit 1
}
printf '%s' "$install_output" | jq -e '
    .schema_version == 1 and .result == "FAIL" and
    .repository == "aydabd/github-bootstrap" and
    (.checks | length) == 1 and .checks[0].error_code == "MISSING_CREDENTIALS" and
    .summary == {passed: 0, failed: 1, skipped: 0}
' > /dev/null

set +e
invalid_output="$(GITHUB_REPOSITORY=aydabd/github-bootstrap \
    APP_CREDENTIAL_DIR=/private/tmp "$orchestrator" install invalid-role 2> /dev/null)"
invalid_status="$?"
set -e
[ "$invalid_status" -eq 1 ] || {
    echo "invalid roles must fail with status 1" >&2
    exit 1
}
[ "$(printf '%s\n' "$invalid_output" | wc -l | tr -d ' ')" -eq 1 ] || {
    echo "invalid roles must emit exactly one JSON result" >&2
    exit 1
}
printf '%s' "$invalid_output" | jq -e '
    .result == "FAIL" and .checks[0].error_code == "INVALID_PROFILE" and
    .summary == {passed: 0, failed: 1, skipped: 0}
' > /dev/null

echo "GitHub App setup orchestrator contract checks passed."

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT
fake_bin="$fixture_root/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/gh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${FAKE_GH_LOG:?}"
if [ "${1:-}" = api ]; then
    printf '%s\n' 'aydabd'
fi
EOF
chmod 700 "$fake_bin/gh"
cat > "$fake_bin/curl" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '{"access_token":"ghu_fixture_access","refresh_token":"ghr_fixture_replacement"}'
EOF
chmod 700 "$fake_bin/curl"

credentials="$fixture_root/github-bootstrap/e2e-writer"
mkdir -p "$credentials"
chmod 700 "$credentials"
printf '123456\n' > "$credentials/app-client-id"
printf 'bootstrap-e2e-writer\n' > "$credentials/app-slug"
printf '%s\n' '-----BEGIN PRIVATE KEY-----' 'fixture-key' '-----END PRIVATE KEY-----' > \
    "$credentials/app-private-key.pem"
chmod 600 "$credentials"/*

export FAKE_GH_LOG="$fixture_root/gh.log"
PATH="$fake_bin:$PATH" GH_TOKEN=fixture-token GITHUB_REPOSITORY=aydabd/github-bootstrap \
    APP_CREDENTIAL_DIR="$credentials" "$orchestrator" install e2e-writer \
    > "$fixture_root/install.json"
jq -e '
    .result == "PASS" and
    .checks[0].check == "install" and
    .summary == {passed: 1, failed: 0, skipped: 0}
' "$fixture_root/install.json" > /dev/null
grep -Fq 'variable set BOOTSTRAP_E2E_WRITER_APP_CLIENT_ID --repo aydabd/github-bootstrap --env e2e --body 123456' "$FAKE_GH_LOG"
grep -Fq 'variable set BOOTSTRAP_E2E_WRITER_APP_SLUG --repo aydabd/github-bootstrap --env e2e --body bootstrap-e2e-writer' "$FAKE_GH_LOG"
grep -Fq 'secret set BOOTSTRAP_E2E_WRITER_APP_PRIVATE_KEY --repo aydabd/github-bootstrap --env e2e' "$FAKE_GH_LOG"
if grep -Eiq 'fixture-token|BEGIN PRIVATE KEY|123456|bootstrap-e2e-writer' "$fixture_root/install.json"; then
    echo "install output leaked credential-like material" >&2
    exit 1
fi

PATH="$fake_bin:$PATH" GITHUB_REPOSITORY=aydabd/github-bootstrap \
    APP_CREDENTIAL_ROLE=e2e-writer APP_CREDENTIAL_DIR="$credentials" \
    "$orchestrator" cleanup > "$fixture_root/cleanup.json"
jq -e '.result == "PASS" and .checks[0].check == "cleanup"' "$fixture_root/cleanup.json" > /dev/null
[ ! -e "$credentials" ]

rotation_credentials="$fixture_root/github-bootstrap/e2e-provisioner"
mkdir -p "$rotation_credentials"
chmod 700 "$rotation_credentials"
printf '123456\n' > "$rotation_credentials/app-client-id"
printf 'client-secret\n' > "$rotation_credentials/app-client-secret"
printf 'ghr_fixture_original\n' > "$rotation_credentials/app-refresh-token"
chmod 600 "$rotation_credentials"/*
PATH="$fake_bin:$PATH" GITHUB_REPOSITORY=aydabd/github-bootstrap \
    APP_CREDENTIAL_DIR="$rotation_credentials" "$orchestrator" rotate e2e-provisioner \
    > "$fixture_root/rotate.json"
jq -e '.result == "PASS" and .checks[0].check == "rotate"' "$fixture_root/rotate.json" > /dev/null
[ "$(cat "$rotation_credentials/app-refresh-token")" = ghr_fixture_replacement ]
[ ! -e "$rotation_credentials/app-refresh-token.next" ]
[ ! -e "$rotation_credentials/app-access-token" ]
if grep -Eiq 'gh[ur]_fixture|client-secret|123456' "$fixture_root/rotate.json"; then
    echo "rotation output leaked credential-like material" >&2
    exit 1
fi
