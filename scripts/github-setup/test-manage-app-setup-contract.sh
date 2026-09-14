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
    APP_CREDENTIAL_DIR=/private/tmp/github-bootstrap-missing-credentials \
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

echo "GitHub App setup orchestrator contract checks passed."
