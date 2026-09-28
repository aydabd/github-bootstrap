#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
seed_script="$repo_root/scripts/github-setup/seed-centralized-e2e-repository.sh"
settings_file="$repo_root/.github/config/repo-settings.json"
ruleset_file="$repo_root/.github/config/ruleset-default.json"
settings_script="$repo_root/scripts/github-setup/setup-repo-settings.sh"

fail() {
    echo "centralized repository settings contract: $*" >&2
    exit 1
}

test -f "$settings_file" || fail "canonical repository settings are missing"
test -f "$ruleset_file" || fail "canonical ruleset is missing"
jq -e '.default_branch == "main" and .allow_squash_merge == true and .allow_merge_commit == false' \
    "$settings_file" > /dev/null || fail "canonical repository settings are not strict and merge-safe"
jq -e '.name == "strict-main" and (.rules | any(.type == "pull_request"))' \
    "$ruleset_file" > /dev/null || fail "canonical ruleset does not protect the main branch"

grep -Fq 'setup-repo-settings.sh' "$seed_script" ||
    fail "central seed does not use the shared repository settings implementation"
grep -Fq 'setup-ruleset.sh' "$seed_script" ||
    fail "central seed does not use the shared ruleset implementation"
grep -Fq 'ruleset-default.json' "$seed_script" ||
    fail "central seed does not use the canonical ruleset payload"
grep -Fq -- "--required-status-checks 'pull-request / aggregate'" "$seed_script" ||
    fail "central seed does not bind the aggregate status check through the shared ruleset implementation"
for endpoint in '/actions/permissions' '/actions/permissions/workflow' '/actions/permissions/access'; do
    grep -Fq "$endpoint" "$seed_script" || fail "seed script does not reconcile $endpoint"
done
if grep -Fq '"/rulesets"' "$seed_script"; then
    fail "central seed must not duplicate shared ruleset API calls"
fi
for endpoint in \
    '/actions/permissions' \
    '/actions/permissions/workflow' \
    '/actions/permissions/access'; do
    grep -Fq "$endpoint" "$repo_root/.github/actions/apply-repo-settings/action.yml" ||
        fail "generated repository settings action does not reconcile $endpoint"
done
grep -Fq 'sha_pinning_required' "$seed_script" ||
    fail "seed script does not require SHA-pinned actions"
grep -Fq 'visibility' "$seed_script" ||
    fail "seed script does not guard the private/internal-only access policy endpoint"
grep -Fq 'default_workflow_permissions' "$seed_script" ||
    fail "seed script does not set default workflow permissions"
grep -Fq 'can_approve_pull_request_reviews' "$seed_script" ||
    fail "seed script does not disable workflow approval by default"
grep -Fq 'visibility' "$repo_root/.github/actions/apply-repo-settings/action.yml" ||
    fail "generated repository settings action does not guard the private/internal-only access policy endpoint"
if grep -Eq '^[[:space:]]*trap .*RETURN' "$settings_script"; then
    fail "repository settings cleanup must not leak function-local variables through a RETURN trap"
fi
grep -Fq "rm -f \"\$response_file\" \"\$fallback_settings_file\"" "$settings_script" ||
    fail "repository settings cleanup is missing explicit temporary-file cleanup"

echo "centralized repository settings contract checks passed."
