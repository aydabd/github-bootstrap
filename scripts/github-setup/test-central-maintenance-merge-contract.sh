#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$repo_root/templates/centralized-actions-workflows/.github/centralized-workflows.json"
workflow="$repo_root/templates/centralized-actions-workflows/.github/workflows/maintenance-merge.yml"
action="$repo_root/templates/centralized-actions-workflows/.github/actions/maintenance-merge/action.yml"

fail() {
    echo "central maintenance-merge contract: $*" >&2
    exit 1
}

for path in "$manifest" "$workflow" "$action"; do
    test -e "$path" || fail "missing central maintenance-merge asset: $path"
done

jq -e '
    .capabilities["maintenance-merge"] == {
        "status": "available",
        "enabled_by_default": false,
        "workflow": ".github/workflows/maintenance-merge.yml",
        "contract_version": 2,
        "required_inputs": ["repository", "head-sha", "pull-request-number"],
        "minimum_permissions": {
            "actions": "read",
            "contents": "read",
            "pull-requests": "write"
        }
    }
' "$manifest" >/dev/null || fail "maintenance-merge manifest contract is not available and least privilege"

grep -Fq 'workflow_call:' "$workflow" || fail "central workflow must be reusable"
grep -Fq 'repository:' "$workflow" || fail "central workflow must require repository"
grep -Fq 'head-sha:' "$workflow" || fail "central workflow must require exact head SHA"
grep -Fq 'pull-request-number:' "$workflow" || fail "central workflow must require pull request number"
grep -Fq 'reviewer-token:' "$workflow" || fail "central workflow must require Reviewer installation token"
grep -Fq 'writer-token:' "$workflow" || fail "central workflow must require Writer installation token"
if grep -Eq '^  (pull_request|pull_request_target|workflow_run|repository_dispatch|schedule):' "$workflow"; then
    fail "central workflow must not own consumer event triggers"
fi
grep -Fq 'uses: ./.github/actions/maintenance-merge' "$workflow" ||
    fail "central workflow must delegate to the packaged action"
grep -Fq 'Reviewer' "$action" || fail "action must require Reviewer approval"
grep -Fq 'Writer' "$action" || fail "action must use a separate Writer token"
grep -Fq 'head.sha' "$action" || fail "action must validate the exact PR head"
grep -Fq 'check-runs' "$action" || fail "action must inspect exact-head checks"
grep -Fq 'reviews' "$action" || fail "action must inspect Reviewer approval"
grep -Fq 'final' "$action" || fail "action must perform a final state re-read"
grep -Fq 'merge_method' "$action" || fail "action must request squash merge"
if grep -Eiq 'refresh.?token' "$action" "$workflow"; then
    fail "maintenance merge must not use refresh-token runtime credentials"
fi

echo "Central maintenance-merge contract checks passed."
