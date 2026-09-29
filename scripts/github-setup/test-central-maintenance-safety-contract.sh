#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$repo_root/templates/centralized-actions-workflows/.github/centralized-workflows.json"
workflow="$repo_root/templates/centralized-actions-workflows/.github/workflows/maintenance-safety.yml"
action="$repo_root/templates/centralized-actions-workflows/.github/actions/maintenance-safety/action.yml"

fail() {
    echo "central maintenance-safety contract: $*" >&2
    exit 1
}

for path in "$manifest" "$workflow" "$action"; do
    test -e "$path" || fail "missing central maintenance-safety asset: $path"
done

jq -e '
    .capabilities["maintenance-safety"] == {
        "status": "available",
        "enabled_by_default": false,
        "workflow": ".github/workflows/maintenance-safety.yml",
        "contract_version": 2,
        "required_inputs": ["repository", "head-sha", "pull-request-number"],
        "minimum_permissions": {
            "actions": "read",
            "contents": "read",
            "issues": "write",
            "pull-requests": "write"
        }
    }
' "$manifest" > /dev/null || fail "maintenance-safety manifest contract is not available and opt-in"

grep -Fq 'workflow_call:' "$workflow" || fail "central workflow must be reusable"
grep -Fq 'repository:' "$workflow" || fail "central workflow must require repository"
grep -Fq 'head-sha:' "$workflow" || fail "central workflow must require exact head SHA"
grep -Fq 'pull-request-number:' "$workflow" || fail "central workflow must require pull request number"
if grep -Eq '^  (pull_request|pull_request_target|workflow_run|repository_dispatch):' "$workflow"; then
    fail "central workflow must not own consumer event triggers"
fi
grep -Fq 'actions: read' "$workflow" || fail "central workflow must request actions read"
grep -Fq 'issues: write' "$workflow" || fail "central workflow must request issues write"
grep -Fq 'pull-requests: write' "$workflow" || fail "central workflow must request pull requests write"
grep -Fq 'uses: ./.github/actions/maintenance-safety' "$workflow" ||
    fail "central workflow must delegate to the packaged action"
grep -Fq '.head.sha' "$action" || fail "action must validate the exact PR head"
grep -Fq 'EXPECTED_HEAD_SHA' "$action" || fail "action must compare against the requested head SHA"
grep -Fq 'actions/runs?head_sha=' "$action" || fail "action must inspect checks for the exact head"
grep -Fq 'automation: accepted' "$action" || fail "action must publish accepted lifecycle state"
grep -Fq 'automation: blocked' "$action" || fail "action must publish blocked lifecycle state"
grep -Fq 'GH_TOKEN' "$action" || fail "action must use a short-lived workflow token"

echo "Central maintenance-safety contract checks passed."
