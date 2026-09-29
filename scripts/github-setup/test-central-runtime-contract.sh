#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$repo_root/templates/centralized-actions-workflows/.github/centralized-workflows.json"
readme="$repo_root/templates/centralized-actions-workflows/README.md"
trust_boundaries="$repo_root/docs/github-app-trust-boundaries.md"

fail() {
    echo "central runtime contract: $*" >&2
    exit 1
}

test -f "$manifest" || fail "centralized workflow package manifest is missing"

jq -e '
    .runtime | type == "object" and
    .service_layout == {
        "repository": "{{REPOSITORY_OWNER}}/{{REPOSITORY_NAME}}",
        "release_ref": "immutable-package-ref",
        "consumer_adapter": "thin-repository-workflow"
    } and
    .release_policy == {
        "type": "immutable",
        "allowed": ["semver-release-tag", "commit-sha"],
        "contract_versioning": "increment-and-release"
    } and
    (.registration_owner | type == "string" and . == "{{APP_REGISTRATION_OWNER}}") and
    (.installation_owner | type == "string" and . == "{{INSTALLATION_OWNER}}") and
    (.roles | type == "object") and
    ([.roles | keys[]] | sort) == ["governance", "reviewer", "writer"]
' "$manifest" > /dev/null || fail "portable runtime service layout or role inventory is invalid"

jq -e '
    all(.runtime.roles[];
        .identity | type == "string" and length > 0
    ) and
    all(.runtime.roles[];
        .installation_scope == "selected-repositories" and
        .token_mode == "installation" and
        .ruleset_bypass == false and
        .secret_custody == "operator-only" and
        (.events | type == "array") and
        (.permissions | type == "object") and
        all(.permissions | to_entries[]; .key | test("^(actions|checks|contents|metadata|pull-requests|statuses)$")) and
        all(.permissions | to_entries[]; .value == "read" or .value == "write") and
        (keys | all(.[]; test("^(identity|events|permissions|installation_scope|token_mode|ruleset_bypass|secret_custody)$")))
    )
' "$manifest" > /dev/null || fail "runtime roles are not installation-token, selected-scope, operator-custodied contracts"

jq -e '
    .runtime.roles.governance.events == ["pull_request", "check_run", "workflow_run", "branch_protection_rule"] and
    .runtime.roles.governance.permissions == {
        "actions": "read",
        "checks": "write",
        "contents": "read",
        "metadata": "read",
        "pull-requests": "read",
        "statuses": "write"
    } and
    .runtime.roles.reviewer.events == ["workflow_run"] and
    .runtime.roles.reviewer.permissions == {
        "actions": "write",
        "metadata": "read",
        "pull-requests": "write"
    } and
    .runtime.roles.writer.events == [] and
    .runtime.roles.writer.permissions == {
        "actions": "read",
        "contents": "write",
        "metadata": "read",
        "pull-requests": "write"
    }
' "$manifest" > /dev/null || fail "runtime role permissions or event subscriptions do not match the contract"

if jq -e '
    .. | objects | keys[] |
    test("(private.key|client.secret|refresh.token|access.token|credential.value)"; "i")
' "$manifest" > /dev/null; then
    fail "runtime manifest contains secret-like fields"
fi

if jq -e '.runtime.roles[] | .token_mode == "bootstrap-refresh" or .ruleset_bypass == true' "$manifest" > /dev/null; then
    fail "runtime roles permit refresh-token mode or ruleset bypass"
fi

grep -Fq 'Runtime jobs use' "$readme" ||
    fail "central package README does not define installation-token runtime auth"
grep -Fq 'independent short-lived installation tokens' "$readme" ||
    fail "central package README does not define installation-token runtime auth"
grep -Fq 'Consumer-owned triggers, secrets, environments, variables, repository' "$readme" ||
    fail "central package README does not define the thin adapter boundary"
grep -Fq 'settings, rulesets, and policy remain local.' "$readme" ||
    fail "central package README does not define the thin adapter boundary"
grep -Fq 'Shared' "$trust_boundaries" ||
    fail "trust-boundary documentation does not define shared credential custody"
grep -Fq 'runtime credentials remain operator-only' "$trust_boundaries" ||
    fail "trust-boundary documentation does not define shared credential custody"
grep -Fq 'Runtime Apps have no ruleset-bypass authority' "$trust_boundaries" ||
    fail "trust-boundary documentation does not prohibit runtime ruleset bypass"
grep -Fq 'selected-repository installation scope' "$trust_boundaries" ||
    fail "trust-boundary documentation does not define selected-repository scope"

echo "Central runtime contract checks passed."
