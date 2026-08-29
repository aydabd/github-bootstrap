#!/usr/bin/env bash
set -euo pipefail

command -v jq > /dev/null 2>&1 || {
    echo "jq is required to validate bootstrap JSON payloads" >&2
    exit 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

require_file() {
    [ -f "$1" ] || {
        echo "missing payload: $1" >&2
        exit 1
    }
}

settings="$repo_root/.github/config/repo-settings.json"
ruleset="$repo_root/.github/config/ruleset-default.json"
security="$repo_root/.github/config/security-default.json"
require_file "$settings"
require_file "$ruleset"
require_file "$security"

jq -e '
    type == "object" and .default_branch == "main" and .has_wiki == false and
    .has_issues == true and .has_projects == true and .allow_auto_merge == false and
    .allow_squash_merge == true and .allow_merge_commit == false and
    .allow_rebase_merge == false and .allow_update_branch == true and
    .delete_branch_on_merge == true and .squash_merge_commit_title == "PR_TITLE" and
    .squash_merge_commit_message == "COMMIT_MESSAGES"
' "$settings" > /dev/null

jq -e '
    .target == "branch" and .source_type == "Repository" and .enforcement == "active" and
    .conditions.ref_name.include == ["refs/heads/main"] and .conditions.ref_name.exclude == [] and
    .bypass_actors == [] and any(.rules[]; .type == "deletion") and
    any(.rules[]; .type == "non_fast_forward") and
    any(.rules[]; .type == "required_linear_history") and
    any(.rules[]; .type == "required_signatures") and
    any(.rules[]; .type == "required_status_checks" and
        .parameters.strict_required_status_checks_policy == true and
        ([.parameters.required_status_checks[]?.context] | sort) == ["Maintenance safety", "Signed-off-by trailers", "quality"]) and
    any(.rules[]; .type == "pull_request" and .parameters.required_approving_review_count == 1 and
        .parameters.dismiss_stale_reviews_on_push == true and .parameters.require_last_push_approval == true and
        .parameters.required_review_thread_resolution == true and .parameters.allowed_merge_methods == ["squash"])
' "$ruleset" > /dev/null

jq -e '
    type == "object" and
    ((keys_unsorted | sort) == [
        "automated_security_fixes", "dependency_graph", "private_vulnerability_reporting",
        "secret_scanning", "secret_scanning_push_protection", "vulnerability_alerts"
    ]) and
    all(to_entries[]; .value == "enabled" or .value == "disabled" or
        (.key == "private_vulnerability_reporting" and .value == "best-effort"))
' "$security" > /dev/null
echo "repository settings, strict ruleset, and security payloads validated"
