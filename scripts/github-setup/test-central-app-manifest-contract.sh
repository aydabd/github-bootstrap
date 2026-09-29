#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manifest_dir="$script_dir/../../docs/github-app-manifests"
profiles="$script_dir/app-credential-profiles.json"
helper="$script_dir/github-app-manifest.sh"

fail() {
    echo "central App manifest contract: $*" >&2
    exit 1
}

test -x "$helper" || fail "manifest helper is not executable"
test -f "$profiles" || fail "credential profile manifest is missing"

expected_roles=(
    central-e2e-governance
    central-e2e-reviewer
    central-e2e-writer
    central-production-governance
    central-production-reviewer
    central-production-writer
)

for role in "${expected_roles[@]}"; do
    manifest="$manifest_dir/$role.json"
    test -f "$manifest" || fail "missing manifest: $role"
    jq -e --arg role "$role" '
        .name == ("Central " + (if ($role | startswith("central-e2e-")) then "E2E " else "Production " end) +
            (if ($role | endswith("governance")) then "Governance" elif ($role | endswith("reviewer")) then "Reviewer" else "Writer" end)) and
        (.default_events | type == "array") and
        (.default_permissions | type == "object") and
        (.default_permissions.metadata == "read") and
        (.default_permissions | keys | all(.[]; test("^(actions|checks|contents|metadata|pull_requests|statuses)$"))) and
        (has("bypass_actors") | not) and
        (.public | type == "boolean")
    ' "$manifest" > /dev/null || fail "invalid manifest contract: $role"

    if "$helper" url "$role" https://example.test/callback > /dev/null 2>&1; then
        :
    else
        fail "manifest helper does not support: $role"
    fi
done

jq -e --argjson roles "$(printf '%s\n' "${expected_roles[@]}" | jq -R . | jq -s .)" '
    . as $manifest |
    $manifest.role_order as $order |
    ($roles | sort) == ([$order[] | select(startswith("central-"))] | sort) and
    all($roles[]; . as $role |
        $manifest[$role] | keys == ["app_slug_variable", "client_id_variable", "environment", "private_key_secret"] and
        (.environment == (if ($role | startswith("central-e2e-")) then "e2e" else "production" end)) and
        (.client_id_variable | startswith("CENTRAL_")) and
        (.app_slug_variable | startswith("CENTRAL_")) and
        (.private_key_secret | startswith("CENTRAL_"))
    )
' "$profiles" > /dev/null || fail "central profile registry is not six-way and environment-separated"

for role in "${expected_roles[@]}"; do
    profile_json="$(BOOTSTRAP_APP_OWNER=example-owner "$script_dir/app-credential-profile.sh" "$role")"
    expected_environment=production
    case "$role" in
        central-e2e-*) expected_environment=e2e ;;
    esac
    jq -e --arg expected_environment "$expected_environment" '
        .environment == $expected_environment and
        (.client_id_variable | startswith("CENTRAL_")) and
        (.app_slug_variable | startswith("CENTRAL_")) and
        (.private_key_secret | startswith("CENTRAL_"))
    ' <<< "$profile_json" > /dev/null || fail "invalid central profile output: $role"
done

echo "Central App manifest contract checks passed."
