#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
validator="$script_dir/validate-maintenance-merge.sh"
workflow="$repo_root/.github/workflows/merge-maintenance-pr.yml"
resolver="$repo_root/.github/actions/resolve-gh-token/action.yml"
manifest="$repo_root/docs/github-app-manifests/bootstrap-reviewer.json"

assert_contains() {
    local needle="$1"
    local file="$2"
    grep -Fq -- "$needle" "$file" || {
        echo "expected '$needle' in $file" >&2
        exit 1
    }
}

assert_not_contains() {
    local needle="$1"
    local file="$2"
    if grep -Fq -- "$needle" "$file"; then
        echo "unexpected '$needle' in $file" >&2
        exit 1
    fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/pr.json" << 'EOF'
{"number":42,"state":"open","draft":false,"head":{"sha":"current-sha","repo":{"full_name":"aydabd/github-bootstrap"}},"base":{"ref":"main","repo":{"full_name":"aydabd/github-bootstrap"}},"user":{"login":"maintenance-writer[bot]"}}
EOF
cat > "$tmp_dir/checks.json" << 'EOF'
[{"name":"Quality","state":"SUCCESS"},{"name":"Maintenance safety","state":"SUCCESS"}]
EOF
cat > "$tmp_dir/reviews.json" << 'EOF'
[{"user":{"login":"maintenance-writer[bot]"},"state":"COMMENTED"}]
EOF
cat > "$tmp_dir/labels.json" << 'EOF'
[{"name":"automation: maintenance"},{"name":"automation: validating"}]
EOF

bash "$validator" "$tmp_dir/pr.json" "$tmp_dir/checks.json" "$tmp_dir/reviews.json" \
    "$tmp_dir/labels.json" "aydabd/github-bootstrap" "current-sha" "maintenance-writer" "maintenance-reviewer"

sed 's/maintenance-writer\[bot\]/release-please[bot]/; s/"user":/"labels":[{"name":"autorelease: pending"}],"user":/' \
    "$tmp_dir/pr.json" > "$tmp_dir/release-pr.json"
sed 's/"automation: maintenance"/"automation: maintenance"}, {"name":"autorelease: pending"/' \
    "$tmp_dir/labels.json" > "$tmp_dir/release-labels.json"
bash "$validator" "$tmp_dir/release-pr.json" "$tmp_dir/checks.json" "$tmp_dir/reviews.json" \
    "$tmp_dir/release-labels.json" "aydabd/github-bootstrap" "current-sha" "maintenance-writer" "maintenance-reviewer"

sed 's/current-sha/stale-sha/' "$tmp_dir/pr.json" > "$tmp_dir/stale-pr.json"
if bash "$validator" "$tmp_dir/stale-pr.json" "$tmp_dir/checks.json" "$tmp_dir/reviews.json" \
    "$tmp_dir/labels.json" "aydabd/github-bootstrap" "current-sha" "maintenance-writer" "maintenance-reviewer"; then
    echo "stale PR head was accepted" >&2
    exit 1
fi

sed 's/"ref":"main"/"ref":"develop"/' "$tmp_dir/pr.json" > "$tmp_dir/non-main-pr.json"
if bash "$validator" "$tmp_dir/non-main-pr.json" "$tmp_dir/checks.json" "$tmp_dir/reviews.json" \
    "$tmp_dir/labels.json" "aydabd/github-bootstrap" "current-sha" "maintenance-writer" "maintenance-reviewer"; then
    echo "non-main PR base was accepted" >&2
    exit 1
fi

sed 's/maintenance-writer\[bot\]/dependabot[bot]/' "$tmp_dir/pr.json" > "$tmp_dir/dependabot-pr.json"
MAINTENANCE_IDENTITY_MODE=e2e-disposable MAINTENANCE_FIXTURE_LOGIN=e2e-user \
    MAINTENANCE_COPILOT_REVIEWER_LOGIN='copilot-pull-request-reviewer[bot]' \
    bash "$validator" "$tmp_dir/dependabot-pr.json" "$tmp_dir/checks.json" "$tmp_dir/reviews.json" \
    "$tmp_dir/labels.json" "aydabd/github-bootstrap" "current-sha" "maintenance-writer" "maintenance-reviewer"

sed 's/maintenance-writer\[bot\]/e2e-user/' "$tmp_dir/pr.json" > "$tmp_dir/fixture-pr.json"
if MAINTENANCE_IDENTITY_MODE=e2e-disposable MAINTENANCE_FIXTURE_LOGIN=e2e-user \
    MAINTENANCE_COPILOT_REVIEWER_LOGIN='copilot-pull-request-reviewer[bot]' \
    bash "$validator" "$tmp_dir/fixture-pr.json" "$tmp_dir/checks.json" "$tmp_dir/reviews.json" \
    "$tmp_dir/labels.json" "aydabd/github-bootstrap" "current-sha" "maintenance-writer" "maintenance-reviewer"; then
    echo "fixture PR merged without Copilot fixture review evidence" >&2
    exit 1
fi

sed 's/"SUCCESS"/"PENDING"/' "$tmp_dir/checks.json" > "$tmp_dir/pending-checks.json"
if bash "$validator" "$tmp_dir/pr.json" "$tmp_dir/pending-checks.json" "$tmp_dir/reviews.json" \
    "$tmp_dir/labels.json" "aydabd/github-bootstrap" "current-sha" "maintenance-writer" "maintenance-reviewer"; then
    echo "pending required check was accepted" >&2
    exit 1
fi

sed 's/maintenance-writer\[bot\]/maintenance-reviewer[bot]/' "$tmp_dir/pr.json" > "$tmp_dir/self-pr.json"
if bash "$validator" "$tmp_dir/self-pr.json" "$tmp_dir/checks.json" "$tmp_dir/reviews.json" \
    "$tmp_dir/labels.json" "aydabd/github-bootstrap" "current-sha" "maintenance-writer" "maintenance-reviewer"; then
    echo "Reviewer App PR identity was accepted" >&2
    exit 1
fi

if bash "$validator" "$tmp_dir/pr.json" "$tmp_dir/checks.json" "$tmp_dir/reviews.json" \
    "$tmp_dir/labels.json" "aydabd/github-bootstrap" "current-sha" "maintenance-writer" "maintenance-reviewer" true; then
    echo "missing Reviewer App approval was accepted" >&2
    exit 1
fi

cat > "$tmp_dir/stale-approval.json" << 'EOF'
[{"user":{"login":"maintenance-reviewer[bot]"},"state":"APPROVED","commit_id":"old-sha"}]
EOF
if bash "$validator" "$tmp_dir/pr.json" "$tmp_dir/checks.json" "$tmp_dir/stale-approval.json" \
    "$tmp_dir/labels.json" "aydabd/github-bootstrap" "current-sha" "maintenance-writer" "maintenance-reviewer" true; then
    echo "stale Reviewer App approval was accepted" >&2
    exit 1
fi

cat > "$tmp_dir/head-approval.json" << 'EOF'
[{"user":{"login":"maintenance-reviewer[bot]"},"state":"APPROVED","commit_id":"current-sha"}]
EOF
bash "$validator" "$tmp_dir/pr.json" "$tmp_dir/checks.json" "$tmp_dir/head-approval.json" \
    "$tmp_dir/labels.json" "aydabd/github-bootstrap" "current-sha" "maintenance-writer" "maintenance-reviewer" true

assert_contains "workflow_run:" "$workflow"
assert_contains "workflows:" "$workflow"
assert_contains "Maintenance safety" "$workflow"
assert_contains "Verify Conda Lockfiles" "$workflow"
assert_contains "TRIGGER_WORKFLOW" "$workflow"
assert_contains "TRIGGER_PR_NUMBER" "$workflow"
assert_contains "TRIGGER_HEAD_SHA" "$workflow"
assert_contains "wait_until_safety_check()" "$workflow"
assert_contains "maintenance_safety_state" "$workflow"
assert_contains "could not re-read pull request head; deferring" "$workflow"
assert_contains "maintenance trigger has no head branch" "$workflow"
# shellcheck disable=SC2016  # literal workflow substrings, not shell to expand
assert_contains 'commit_id="$HEAD_SHA"' "$workflow"
assert_contains 'current_head_sha' "$workflow"
# shellcheck disable=SC2016  # literal workflow substring, not shell to expand
assert_contains 'current_head_sha" != "$HEAD_SHA"' "$workflow"
assert_contains "BOOTSTRAP_PRODUCTION_REVIEWER_APP_PRIVATE_KEY" "$workflow"
assert_contains "permission_profile: maintenance-review" "$workflow"
assert_contains "inputs.permission_profile == 'maintenance-review'" "$resolver"
assert_contains "maintenance-review" "$resolver"
assert_contains '"pull_requests": "write"' "$manifest"
assert_contains "permission_profile: maintenance-merge" "$workflow"
assert_contains "permission_profile == 'maintenance-merge') && 'write'" "$resolver"
assert_contains "gh api --method POST \"/repos/\$REPOSITORY/pulls/\$PR_NUMBER/reviews\"" "$workflow"
assert_contains 'validate_state true' "$workflow"
assert_contains 'attempt_merge()' "$workflow"
assert_contains 'mergeable_state' "$workflow"
# shellcheck disable=SC2016  # literal workflow substring, not shell to expand
assert_contains 'if ! mergeable_state="$(gh api "/repos/$REPOSITORY/pulls/$PR_NUMBER" --jq '\''.mergeable_state // "unknown"'\'')"; then' "$workflow"
assert_contains 'could not read mergeable state; deferring' "$workflow"
assert_contains 'clean)' "$workflow"
assert_contains 'behind)' "$workflow"
assert_contains 'dirty)' "$workflow"
# shellcheck disable=SC2016  # literal workflow substring, not shell to expand
assert_contains '"/repos/$REPOSITORY/pulls/$PR_NUMBER/update-branch"' "$workflow"
# shellcheck disable=SC2016  # literal workflow substring, not shell to expand
assert_contains '-f expected_head_sha="$HEAD_SHA"' "$workflow"
assert_contains 'sleep 5' "$workflow"
assert_contains 'deferring to the next trigger' "$workflow"
assert_not_contains 'enablePullRequestAutoMerge' "$workflow"
assert_not_contains 'wait_until_mergeable' "$workflow"
assert_not_contains 'merge_with_retry' "$workflow"
assert_not_contains 'mergeability_timeout' "$workflow"
assert_not_contains 'wait_for_required_checks()' "$workflow"
assert_not_contains 'seq 1 45' "$workflow"
assert_not_contains 'sleep 20' "$workflow"
assert_contains "-f head=\"\${REPOSITORY%%/*}:\$HEAD_BRANCH\" -f base=main -f state=open" "$workflow"
assert_contains "[ \"\$TRIGGER_HEAD_SHA\" = \"\$HEAD_SHA\" ]" "$workflow"
assert_contains "if length == 1 then .[0].number else empty end" "$workflow"
assert_not_contains "[ \"\$SAFETY_SHA\" = \"\$HEAD_SHA\" ]" "$workflow"
assert_contains 'github.event.workflow_run.pull_requests[0].number' "$workflow"
assert_not_contains 'gh pr merge' "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_not_contains "bypass_actors" "$manifest"

echo "Maintenance merge contract passed."
