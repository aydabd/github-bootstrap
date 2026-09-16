#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
validator="$script_dir/validate-maintenance-safety.sh"
workflow="$script_dir/../../.github/workflows/maintenance-safety.yml"
config="$script_dir/../../.github/config/maintenance-e2e.json"
template_workflow="$script_dir/../../templates/.github/workflows/maintenance-safety.yml"
template_config="$script_dir/../../templates/.github/config/maintenance-e2e.json"
template_validator="$script_dir/../../templates/.github/scripts/validate-maintenance-safety.sh"
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
cat > "$tmp_dir/enabled-config.json" << 'EOF'
{"schema_version":1,"enabled":true,"workflow":"test-generated-repository-e2e.yml"}
EOF
cat > "$tmp_dir/disabled-config.json" << 'EOF'
{"schema_version":1,"enabled":false,"workflow":""}
EOF
for empty_file in empty-runs empty-e2e empty-labels empty-reviews empty-threads; do
    printf '%s\n' '[]' > "$tmp_dir/$empty_file.json"
done

"$validator" "$tmp_dir/pr.json" "$tmp_dir/runs.json" "$tmp_dir/e2e.json" "$tmp_dir/labels.json" "$tmp_dir/reviews.json" "$tmp_dir/threads.json" "current-sha" "copilot-pull-request-reviewer[bot]" "$tmp_dir/enabled-config.json"

cat > "$tmp_dir/non-maintenance.json" << 'EOF'
{"number":8,"head":{"sha":"other-sha"},"requested_reviewers":[]}
EOF
"$validator" "$tmp_dir/non-maintenance.json" "$tmp_dir/empty-runs.json" "$tmp_dir/empty-e2e.json" "$tmp_dir/empty-labels.json" "$tmp_dir/empty-reviews.json" "$tmp_dir/empty-threads.json" "other-sha" "" "$tmp_dir/enabled-config.json"

sed 's/"automation: breaking"/"automation: routine"/' "$tmp_dir/labels.json" > "$tmp_dir/non-breaking-labels.json"
"$template_validator" "$tmp_dir/pr.json" "$tmp_dir/runs.json" "$tmp_dir/empty-e2e.json" "$tmp_dir/non-breaking-labels.json" "$tmp_dir/reviews.json" "$tmp_dir/threads.json" "current-sha" "copilot-pull-request-reviewer[bot]" "$tmp_dir/enabled-config.json"
"$validator" "$tmp_dir/pr.json" "$tmp_dir/runs.json" "$tmp_dir/empty-e2e.json" "$tmp_dir/non-breaking-labels.json" "$tmp_dir/reviews.json" "$tmp_dir/threads.json" "current-sha" "copilot-pull-request-reviewer[bot]" "$tmp_dir/enabled-config.json"

if "$validator" "$tmp_dir/pr.json" "$tmp_dir/runs.json" "$tmp_dir/empty-e2e.json" "$tmp_dir/labels.json" "$tmp_dir/reviews.json" "$tmp_dir/threads.json" "current-sha" "copilot-pull-request-reviewer[bot]" "$tmp_dir/disabled-config.json"; then
    echo "breaking maintenance PR passed with E2E disabled" >&2
    exit 1
fi

for mutation in missing pending stale failed; do
    cp "$tmp_dir/e2e.json" "$tmp_dir/mutated-e2e.json"
    case "$mutation" in
        missing) printf '%s\n' '[]' > "$tmp_dir/mutated-e2e.json" ;;
        pending) sed 's/"status":"completed"/"status":"in_progress"/' "$tmp_dir/e2e.json" > "$tmp_dir/mutated-e2e.json" ;;
        stale) sed 's/current-sha/stale-sha/g' "$tmp_dir/e2e.json" > "$tmp_dir/mutated-e2e.json" ;;
        failed) sed 's/"conclusion":"success"/"conclusion":"failure"/' "$tmp_dir/e2e.json" > "$tmp_dir/mutated-e2e.json" ;;
    esac
    if "$validator" "$tmp_dir/pr.json" "$tmp_dir/runs.json" "$tmp_dir/mutated-e2e.json" "$tmp_dir/labels.json" "$tmp_dir/reviews.json" "$tmp_dir/threads.json" "current-sha" "copilot-pull-request-reviewer[bot]" "$tmp_dir/enabled-config.json"; then
        echo "maintenance safety accepted invalid E2E fixture: $mutation" >&2
        exit 1
    fi
done

printf '%s\n' '{"schema_version":1,"enabled":"yes","workflow":"test-generated-repository-e2e.yml"}' > "$tmp_dir/malformed-config.json"
if "$validator" "$tmp_dir/pr.json" "$tmp_dir/runs.json" "$tmp_dir/e2e.json" "$tmp_dir/labels.json" "$tmp_dir/reviews.json" "$tmp_dir/threads.json" "current-sha" "copilot-pull-request-reviewer[bot]" "$tmp_dir/malformed-config.json"; then
    echo "maintenance safety accepted malformed capability config" >&2
    exit 1
fi

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
    if "$validator" "$tmp_dir/pr.json" "$tmp_dir/mutated-runs.json" "$tmp_dir/mutated-e2e.json" "$tmp_dir/mutated-labels.json" "$tmp_dir/reviews.json" "$tmp_dir/threads.json" "current-sha" "copilot-pull-request-reviewer[bot]" "$tmp_dir/enabled-config.json"; then
        echo "maintenance safety accepted invalid fixture: $mutation" >&2
        exit 1
    fi
done

jq -e '.schema_version == 1 and .enabled == true and .workflow == "test-generated-repository-e2e.yml"' "$config" > /dev/null
jq -e '.schema_version == 1 and .enabled == false and .workflow == ""' "$template_config" > /dev/null
grep -Fq 'maintenance-e2e.json' "$workflow"
grep -Fq 'automation: accepted' "$workflow"
grep -Fq 'automation: maintenance' "$workflow"
grep -Fq 'DELETE' "$workflow"
grep -Fq 'POST' "$workflow"
grep -Fq 'maintenance-e2e.json' "$template_workflow"

# GitHub's labels endpoint requires both issue and pull-request write access
# when the target is a pull request; issues:write alone returns HTTP 403.
for maintenance_workflow in "$workflow" "$template_workflow"; do
    grep -Fq 'issues: write' "$maintenance_workflow"
    grep -Fq 'pull-requests: write' "$maintenance_workflow" || {
        echo "maintenance safety must request pull-requests: write for accepted-label mutation: $maintenance_workflow" >&2
        exit 1
    }
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
# Each required workflow completion retriggers safety; the job must defer
# while gates are pending rather than spend runner time polling.
grep -Fq "actions/runs?head_sha=\$HEAD_SHA" "$workflow"
grep -Fq 'all(. == "completed")' "$workflow"
grep -Fq 'Verify Conda Lockfiles' "$workflow"
# shellcheck disable=SC2016  # literal workflow substrings, not shell to expand
if grep -Fq 'for _ in $(seq 1 45)' "$workflow" || grep -Fq 'sleep 20' "$workflow"; then
    echo "maintenance safety must not poll required checks for 15 minutes" >&2
    exit 1
fi
grep -Fq 'e2e_workflow' "$workflow"
grep -Fq 'only query the declared maintenance E2E workflow when enabled' "$workflow"
grep -Fq 'automation: maintenance' "$workflow"
accepted_remove_line="$(grep -n 'automation%3A%20accepted' "$workflow" | head -n1 | cut -d: -f1)"
required_gate_line="$(grep -n 'required_status_jq=' "$workflow" | head -n1 | cut -d: -f1)"
[ "$accepted_remove_line" -lt "$required_gate_line" ]
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
