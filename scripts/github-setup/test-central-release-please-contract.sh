#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$repo_root/templates/centralized-actions-workflows/.github/centralized-workflows.json"
workflow="$repo_root/templates/centralized-actions-workflows/.github/workflows/release-please.yml"

fail() {
    echo "central release-please contract: $*" >&2
    exit 1
}
test -f "$manifest" || fail "central manifest is missing"
test -f "$workflow" || fail "central release-please workflow is missing"
jq -e '
    .capabilities["release-please"] == {
        "status": "available",
        "enabled_by_default": false,
        "workflow": ".github/workflows/release-please.yml",
        "contract_version": 2,
        "required_inputs": ["repository", "release-config", "manifest-file"],
        "minimum_permissions": {"contents": "read", "pull-requests": "write"}
    }
' "$manifest" > /dev/null || fail "release-please capability manifest is invalid"
grep -Fq 'workflow_call:' "$workflow" || fail "workflow must be reusable"
grep -Fq 'release-config:' "$workflow" || fail "workflow must accept release config path"
grep -Fq 'manifest-file:' "$workflow" || fail "workflow must accept manifest path"
grep -Fq 'writer-token:' "$workflow" || fail "workflow must require Writer installation token"
grep -Fq '45996ed1f6d02564a971a2fa1b5860e934307cf7' "$workflow" || fail "release-please action must be immutable"
grep -Fq 'release-please-action@' "$workflow" || fail "workflow must run release-please"
grep -Fq 'path traversal' "$workflow" || fail "workflow must validate safe configuration paths"
grep -Fq 'contents: read' "$workflow" || fail "workflow must declare least-privilege contents access"
grep -Fq 'pull-requests: write' "$workflow" || fail "workflow must declare PR write access"
if grep -Eq '^  (push|pull_request|pull_request_target|schedule|repository_dispatch):' "$workflow"; then
    fail "central workflow must not own consumer event triggers"
fi
if grep -Eiq 'refresh.?token|GITHUB_TOKEN.*release' "$workflow"; then
    fail "release workflow must not use refresh-token or default token runtime"
fi
echo "Central release-please contract checks passed."
