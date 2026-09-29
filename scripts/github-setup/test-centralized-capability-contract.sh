#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$repo_root/templates/centralized-actions-workflows/.github/centralized-workflows.json"

fail() {
    echo "centralized capability contract: $*" >&2
    exit 1
}

test -f "$manifest" || fail "centralized workflow package manifest is missing"

jq -e '
    (.capabilities | type == "object") and
    ([.capabilities | keys[]] | sort) == [
        "maintenance-merge",
        "maintenance-safety",
        "release-please",
        "weekly-tooling-updates"
    ] and
    all(.capabilities[];
        (.status == "available" or .status == "contract-only") and
        .enabled_by_default == false and
        (.contract_version | type == "number" and . > 0 and floor == .) and
        (.workflow | type == "string" and test("^\\.github/workflows/[A-Za-z0-9._-]+\\.yml$")) and
        (.required_inputs | type == "array" and length > 0 and all(.[]; type == "string" and length > 0)) and
        (.minimum_permissions | type == "object" and
            all(to_entries[]; .key | test("^(actions|contents|issues|pull-requests|checks)$")) and
            all(to_entries[]; .value | . == "read" or . == "write"))
    )
' "$manifest" > /dev/null || fail "optional centralized capability inventory is invalid"

jq -e '
    .capabilities["maintenance-safety"].status == "available" and
    ([.capabilities | to_entries[] |
        select(.key != "maintenance-safety" and .key != "maintenance-merge") | .value.status] |
        all(. == "contract-only")) and
    .capabilities["maintenance-merge"].status == "available"
' "$manifest" > /dev/null || fail "maintenance-safety availability boundary is invalid"

jq -e '
    .capabilities["maintenance-safety"].workflow == ".github/workflows/maintenance-safety.yml" and
    .capabilities["maintenance-safety"].required_inputs == ["repository", "head-sha", "pull-request-number", "central-repository", "central-ref"] and
    .capabilities["maintenance-safety"].minimum_permissions == {
        "actions": "read",
        "contents": "read",
        "issues": "write",
        "pull-requests": "write"
    } and
    .capabilities["maintenance-merge"].workflow == ".github/workflows/maintenance-merge.yml" and
    .capabilities["maintenance-merge"].required_inputs == ["repository", "head-sha", "pull-request-number", "central-repository", "central-ref"] and
    .capabilities["maintenance-merge"].minimum_permissions == {
        "actions": "read",
        "contents": "read",
        "pull-requests": "write"
    } and
    .capabilities["release-please"].workflow == ".github/workflows/release-please.yml" and
    .capabilities["release-please"].required_inputs == ["repository", "release-config", "manifest-file"] and
    .capabilities["release-please"].minimum_permissions == {
        "contents": "read",
        "pull-requests": "read"
    } and
    .capabilities["weekly-tooling-updates"].workflow == ".github/workflows/weekly-tooling-updates.yml" and
    .capabilities["weekly-tooling-updates"].required_inputs == ["repository", "explicit-breaking"] and
    .capabilities["weekly-tooling-updates"].minimum_permissions == {
        "contents": "write",
        "issues": "read",
        "pull-requests": "write"
    }
' "$manifest" > /dev/null || fail "capability details do not match the approved contract"

baseline="$repo_root/templates/.github/config/bootstrap-profile.json"
jq -e '
    ([.profiles[].capabilities[]] | index("maintenance-safety")) == null and
    ([.profiles[].capabilities[]] | index("maintenance-merge")) == null and
    ([.profiles[].capabilities[]] | index("release-please")) == null and
    ([.profiles[].capabilities[]] | index("weekly-tooling-updates")) == null
' "$baseline" > /dev/null || fail "optional centralized capabilities were added to the baseline profile"

echo "Centralized capability contract checks passed."
