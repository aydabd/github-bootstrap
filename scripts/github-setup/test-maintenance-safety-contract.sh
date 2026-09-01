#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
validator="$script_dir/validate-maintenance-safety.sh"
workflow="$script_dir/../../.github/workflows/maintenance-safety.yml"
ruleset="$script_dir/../../.github/config/ruleset-default.json"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/pr.json" << 'EOF'
{"number":7,"head":{"sha":"current-sha"},"requested_reviewers":[{"login":"copilot-pull-request-reviewer[bot]"}]}
EOF
cat > "$tmp_dir/runs.json" << 'EOF'
[{"name":"Quality","status":"completed","conclusion":"success","head_sha":"current-sha"},{"name":"Commit policy","status":"completed","conclusion":"success","head_sha":"current-sha"},{"name":"Test Quality Providers","status":"completed","conclusion":"success","head_sha":"current-sha"},{"name":"CodeQL Security Scan","status":"completed","conclusion":"success","head_sha":"current-sha"}]
EOF
cat > "$tmp_dir/e2e.json" << 'EOF'
[{"status":"completed","conclusion":"success","head_sha":"current-sha"}]
EOF
cat > "$tmp_dir/labels.json" << 'EOF'
[{"name":"automation: maintenance"},{"name":"automation: validating"},{"name":"automation: breaking"}]
EOF
cat > "$tmp_dir/reviews.json" << 'EOF'
[{"user":{"login":"copilot-pull-request-reviewer[bot]"},"state":"COMMENTED","commit_id":"current-sha"}]
EOF
cat > "$tmp_dir/threads.json" << 'EOF'
[{"isResolved":true,"author_login":"copilot-pull-request-reviewer[bot]"}]
EOF
for empty_file in empty-runs empty-e2e empty-labels empty-reviews empty-threads; do
    printf '%s\n' '[]' > "$tmp_dir/$empty_file.json"
done

"$validator" "$tmp_dir/pr.json" "$tmp_dir/runs.json" "$tmp_dir/e2e.json" "$tmp_dir/labels.json" "$tmp_dir/reviews.json" "$tmp_dir/threads.json" "current-sha" "copilot-pull-request-reviewer[bot]"

cat > "$tmp_dir/non-maintenance.json" << 'EOF'
{"number":8,"head":{"sha":"other-sha"},"requested_reviewers":[]}
EOF
"$validator" "$tmp_dir/non-maintenance.json" "$tmp_dir/empty-runs.json" "$tmp_dir/empty-e2e.json" "$tmp_dir/empty-labels.json" "$tmp_dir/empty-reviews.json" "$tmp_dir/empty-threads.json" "other-sha" ""

for mutation in missing pending stale failed unknown; do
    cp "$tmp_dir/runs.json" "$tmp_dir/mutated-runs.json"
    cp "$tmp_dir/e2e.json" "$tmp_dir/mutated-e2e.json"
    cp "$tmp_dir/labels.json" "$tmp_dir/mutated-labels.json"
    case "$mutation" in
        missing) printf '%s\n' '[]' > "$tmp_dir/mutated-runs.json" ;;
        pending) sed 's/"status":"completed"/"status":"in_progress"/' "$tmp_dir/runs.json" > "$tmp_dir/mutated-runs.json" ;;
        stale) sed 's/current-sha/stale-sha/g' "$tmp_dir/runs.json" > "$tmp_dir/mutated-runs.json" ;;
        failed) sed 's/"conclusion":"success"/"conclusion":"failure"/' "$tmp_dir/runs.json" > "$tmp_dir/mutated-runs.json" ;;
        unknown) sed 's/"automation: breaking"/"automation: blocked"/' "$tmp_dir/labels.json" > "$tmp_dir/mutated-labels.json" ;;
    esac
    if "$validator" "$tmp_dir/pr.json" "$tmp_dir/mutated-runs.json" "$tmp_dir/mutated-e2e.json" "$tmp_dir/mutated-labels.json" "$tmp_dir/reviews.json" "$tmp_dir/threads.json" "current-sha" "copilot-pull-request-reviewer[bot]"; then
        echo "maintenance safety accepted invalid fixture: $mutation" >&2
        exit 1
    fi
done

grep -Fq 'Maintenance safety' "$workflow"
grep -Fq "github.event_name != 'workflow_run'" "$workflow"
grep -Fq 'pull_request_target:' "$workflow"
grep -Fq 'ref: main' "$workflow"
grep -Fq 'repository_dispatch:' "$workflow"
grep -Fq 'client_payload.head_sha' "$workflow"
grep -Fq 'client_payload.pr_number' "$workflow"
grep -Fq 'pr_number:' "$workflow"
grep -Fq 'head_sha:' "$workflow"
if grep -Fq '^  pull_request:' "$workflow"; then
    echo "maintenance safety must not execute from an untrusted pull_request ref" >&2
    exit 1
fi
grep -Fq 'validate-maintenance-safety.sh' "$workflow"
grep -Fq 'workflow_runs' "$workflow"
# pull_request_target fires before the required checks finish; the job must wait
# for them to settle rather than fail on the early run.
grep -Fq "actions/runs?head_sha=\$HEAD_SHA" "$workflow"
grep -Fq 'all(. == "completed")' "$workflow"
grep -Fq 'test-generated-repository-e2e.yml' "$workflow"
grep -Fq 'BOOTSTRAP_COPILOT_REVIEWER_LOGIN' "$workflow"
# A dispatched Test Generated Repository E2E run carries no pull_requests[0];
# completing that gate must still re-evaluate safety via the PR head branch,
# but only for non-main heads so routine/manual E2E runs do not spawn a failing
# safety run, and a run with no open PR skips rather than fails.
grep -Fq "github.event.workflow_run.name == 'Test Generated Repository E2E'" "$workflow"
grep -Fq "github.event.workflow_run.head_branch != 'main'" "$workflow"
grep -Fq 'no open maintenance PR for this run; nothing to validate.' "$workflow"
# shellcheck disable=SC2016  # literal workflow substrings, not shell to expand
grep -Fq 'HEAD_BRANCH: ${{ github.event.workflow_run.head_branch }}' "$workflow"
# shellcheck disable=SC2016
grep -Fq 'head="${GITHUB_REPOSITORY%%/*}:$HEAD_BRANCH"' "$workflow"
grep -Fq 'required_status_checks' "$ruleset"
grep -Fq 'Maintenance safety' "$ruleset"
grep -Fq 'bypass_actors' "$ruleset"

echo "Maintenance safety contract passed."
