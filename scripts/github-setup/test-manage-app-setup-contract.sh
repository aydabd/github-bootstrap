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

echo "GitHub App setup orchestrator contract checks passed."
