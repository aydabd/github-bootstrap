#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$root/templates/centralized-actions-workflows/.github/centralized-workflows.json"
workflow="$root/templates/centralized-actions-workflows/.github/workflows/weekly-tooling-updates.yml"
action="$root/templates/centralized-actions-workflows/.github/actions/weekly-tooling-updates/action.yml"
fail() {
    echo "central weekly tooling contract: $*" >&2
    exit 1
}
for f in "$manifest" "$workflow" "$action"; do test -e "$f" || fail "missing asset: $f"; done
jq -e '.capabilities["weekly-tooling-updates"].status == "available" and .capabilities["weekly-tooling-updates"].enabled_by_default == false and .capabilities["weekly-tooling-updates"].contract_version == 2' "$manifest" > /dev/null || fail "manifest capability is invalid"
grep -Fq 'workflow_call:' "$workflow" || fail "workflow must be reusable"
grep -Fq 'explicit-breaking:' "$workflow" || fail "workflow must accept explicit breaking input"
grep -Fq 'writer-token:' "$workflow" || fail "workflow must require Writer installation token"
grep -Fq 'uses: ./.github/actions/weekly-tooling-updates' "$workflow" || fail "workflow must use packaged action"
if grep -Eq '^  (schedule|push|pull_request|workflow_dispatch):' "$workflow"; then fail "central workflow must not own scheduling or consumer triggers"; fi
grep -Fq 'installation/repositories' "$action" || fail "action must verify installation scope"
grep -Fq 'TOOLING_UPDATE_EXPLICIT_BREAKING' "$action" || fail "action must preserve breaking-change input"
if grep -Eiq 'refresh.?token|secrets\.GITHUB_TOKEN' "$workflow" "$action"; then fail "workflow must not use refresh or default credentials"; fi
echo "Central weekly tooling contract checks passed."
