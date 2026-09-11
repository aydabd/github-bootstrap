#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow="$repo_root/.github/workflows/test-generated-repository-e2e.yml"
runbook="$repo_root/docs/maintenance-operations.md"
validator="$repo_root/scripts/github-setup/validate-copilot-review.sh"
classifier="$repo_root/scripts/github-setup/validate-maintenance-pr.sh"
merge_state_validator="$repo_root/scripts/github-setup/validate-maintenance-merge-state.sh"
merge_validator="$repo_root/scripts/github-setup/validate-maintenance-merge.sh"
release_validator="$repo_root/scripts/github-setup/validate-maintenance-release.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

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

assert_contains 'name: Generated Maintenance Lifecycle' "$workflow"
assert_contains 'workflows=quality,maintenance' "$workflow"
assert_contains 'workflows=quality,codeql,maintenance' "$workflow"
assert_contains 'automation: maintenance' "$workflow"
assert_contains 'automation: validating' "$workflow"
assert_contains 'e2e-maintenance' "$workflow"
assert_contains 'e2e-maintenance-writer' "$workflow"
assert_contains 'e2e-maintenance-reviewer' "$workflow"
assert_contains 'e2e-maintenance-fixture' "$workflow"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_CLIENT_ID' "$workflow"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_PRIVATE_KEY' "$workflow"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_CLIENT_SECRET' "$workflow"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_USER_REFRESH_TOKEN' "$workflow"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_WRITER_APP_CLIENT_ID' "$workflow"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_REVIEWER_APP_CLIENT_ID' "$workflow"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_WRITER_APP_PRIVATE_KEY' "$workflow"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_REVIEWER_APP_PRIVATE_KEY' "$workflow"
assert_contains 'MAINTENANCE_IDENTITY_MODE' "$workflow"
assert_contains 'MAINTENANCE_FIXTURE_LOGIN' "$workflow"
assert_contains 'e2e-maintenance-user' "$workflow"
assert_contains 'MAINTENANCE_COPILOT_REVIEWER_LOGIN' "$workflow"
assert_contains 'reviewers[]=$MAINTENANCE_COPILOT_REVIEWER_LOGIN' "$workflow"
assert_contains '.login == $login' "$workflow"
assert_contains 'validate-copilot-review.sh' "$workflow"
assert_contains 'Maintenance safety' "$workflow"
assert_contains 'Writer auto-merge' "$workflow"
assert_contains 'release-please' "$workflow"
assert_contains 'archive_repository' "$workflow"
assert_contains 'validate-e2e-archive-target.sh' "$workflow"
assert_contains 'bootstrap-e2e' "$workflow"
assert_contains 'cleanup-generated-maintenance' "$workflow"
assert_contains 'needs: generated-maintenance-lifecycle' "$workflow"
assert_contains "always() &&" "$workflow"
assert_contains 'Arm cleanup before repository creation' "$workflow"
assert_not_contains "needs.generated-maintenance-lifecycle.outputs.cleanup_armed == 'true'" "$workflow"
assert_contains 'permission_profile: repository-cleanup' "$workflow"
assert_contains 'BOOTSTRAP_E2E_PROVISIONER_APP_PRIVATE_KEY' "$workflow"
assert_contains 'continue-on-error: true' "$workflow"
assert_contains 'provisioner cleanup token resolver failed' "$workflow"
assert_contains 'requested_target_sha' "$workflow"
assert_contains 'expected_pr' "$workflow"
assert_contains 'pull_requests[]?.number' "$workflow"
assert_contains 'same repository, pull request, and head' "$workflow"
assert_contains 'wait_for_run maintenance-safety.yml pull_request_target "$pr_head_sha" "$branch" "$maintenance_started_at" "$PR_NUMBER" true' "$workflow"
assert_contains 'wait_for_run merge-maintenance-pr.yml workflow_run "$pr_head_sha" "$branch" "$maintenance_started_at" "$PR_NUMBER" true' "$workflow"
assert_contains 'validate-maintenance-merge-state.sh' "$workflow"
assert_contains 'validate-maintenance-release.sh' "$workflow"
assert_contains 'release_pr_number' "$workflow"
assert_contains 'release_merge_sha' "$workflow"
assert_contains 'release_pushed_at' "$workflow"
assert_contains 'cleanup_armed=true' "$workflow"
assert_contains 'enabled_by.login' "$workflow"
assert_contains 'merged_by.login' "$workflow"
assert_contains 'timeout_seconds' "$workflow"
assert_contains 'diagnostic' "$workflow"
assert_contains 'gh run view' "$workflow"
assert_contains 'credential configuration jobs did not complete successfully' "$workflow"
assert_not_contains 'outputs.provisioner_token' "$workflow"
assert_not_contains 'outputs.e2e_token' "$workflow"
assert_contains 'requested_reviewers' "$workflow"
assert_contains 'reviewers[]=$MAINTENANCE_COPILOT_REVIEWER_LOGIN' "$workflow"
assert_contains 'REQUIRE_COPILOT_REVIEW=true' "$workflow"
assert_contains 'reviewThreads(first:100)' "$workflow"
assert_contains 'author_login: (.comments.nodes[0].author.login // "")}]' "$workflow"
assert_contains 'pageInfo.hasNextPage == false' "$workflow"
assert_contains "created_at >= \$since" "$workflow"
assert_contains ".head_sha == \$sha" "$workflow"
assert_contains "head_branch == \$branch" "$workflow"
assert_contains 'head_repository' "$workflow"

for required_workflow in quality.yml codeql.yml test-quality-providers.yml \
    commit-policy.yml classify-maintenance-pr.yml maintenance-safety.yml \
    approve-automation-workflows.yml merge-maintenance-pr.yml release-please.yml; do
    assert_contains "${required_workflow}" "$repo_root/scripts/select-generated-workflows.sh"
done

for creation_workflow in create-repository.yml terraform-create-repository.yml; do
    creation_path="$repo_root/.github/workflows/$creation_workflow"
    assert_contains 'configure-e2e-maintenance-credentials' "$creation_path"
    assert_contains 'environment: production-maintenance' "$creation_path"
    assert_contains 'environment: e2e-maintenance' "$creation_path"
    assert_contains 'configure-e2e-maintenance-credentials' "$creation_path"
    assert_contains 'configure-production-maintenance-credentials' "$creation_path"
done
assert_contains 'tags?per_page=100' "$workflow"
assert_contains 'names[]=bootstrap-e2e' "$workflow"
assert_contains 'PATCH' "$workflow"
assert_contains 'PUT' "$workflow"
assert_not_contains "printf '%s\\n' '[]'" "$workflow"

for limit in 'seq 1 60' 'seq 1 90' 'seq 1 120'; do
    assert_contains "$limit" "$workflow"
done

assert_not_contains 'BOOTSTRAP_MAINTENANCE_WRITER_APP_' "$workflow"
assert_not_contains 'BOOTSTRAP_REVIEWER_APP_' "$workflow"
assert_contains 'app_client_secret: ${{ secrets.BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_CLIENT_SECRET }}' "$workflow"
assert_not_contains 'production-maintenance' "$workflow"
assert_not_contains 'production-maintenance-writer' "$workflow"
assert_not_contains 'production-maintenance-reviewer' "$workflow"
assert_not_contains 'BOOTSTRAP_MAINTENANCE_FIXTURE_TOKEN' "$workflow"
assert_not_contains 'BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_TOKEN' "$workflow"
assert_contains 'PR_AUTHOR_USER_TOKEN: ${{ steps.fixture-token.outputs.token }}' "$workflow"
assert_not_contains 'PR_AUTHOR_TOKEN:' "$workflow"
setup_script="$repo_root/scripts/github-setup/install-e2e-maintenance-credentials.sh"
assert_contains 'install-e2e-maintenance-credentials.sh' "$runbook"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_USER_REFRESH_TOKEN' "$runbook"
assert_contains 'BOOTSTRAP_MAINTENANCE_REVIEWER_APP_CLIENT_ID' "$runbook"
assert_contains 'BOOTSTRAP_MAINTENANCE_REVIEWER_APP_PRIVATE_KEY' "$runbook"
assert_not_contains 'BOOTSTRAP_REVIEWER_APP_CLIENT_ID' "$runbook"
assert_not_contains 'missing/rotated `BOOTSTRAP_REVIEWER_APP_PRIVATE_KEY`' "$runbook"
if [ ! -x "$setup_script" ]; then
    echo "missing executable E2E maintenance setup script" >&2
    exit 1
fi

setup_tmp_dir="$tmp_dir/setup"
mkdir -p "$setup_tmp_dir/bin" "$setup_tmp_dir/writer" "$setup_tmp_dir/reviewer" "$setup_tmp_dir/fixture"
setup_calls="$setup_tmp_dir/gh-calls"
cat > "$setup_tmp_dir/bin/gh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SETUP_GH_CALLS:?}"
case "$*" in
    api\ *\/installation\/repositories*)
        printf '%s\n' '{"repositories":[{"full_name":"acme/github-bootstrap"}]}'
        ;;
esac
EOF
chmod +x "$setup_tmp_dir/bin/gh"
printf 'writer-client-id\n' > "$setup_tmp_dir/writer/app-client-id"
printf 'writer-slug\n' > "$setup_tmp_dir/writer/app-slug"
printf '%s\n' '-----BEGIN PRIVATE KEY-----' 'writer-key' '-----END PRIVATE KEY-----' > "$setup_tmp_dir/writer/app-private-key.pem"
printf 'reviewer-client-id\n' > "$setup_tmp_dir/reviewer/app-client-id"
printf 'reviewer-slug\n' > "$setup_tmp_dir/reviewer/app-slug"
printf '%s\n' '-----BEGIN PRIVATE KEY-----' 'reviewer-key' '-----END PRIVATE KEY-----' > "$setup_tmp_dir/reviewer/app-private-key.pem"
printf 'fixture-client-id\n' > "$setup_tmp_dir/fixture/app-client-id"
printf 'fixture-slug\n' > "$setup_tmp_dir/fixture/app-slug"
printf '%s\n' '-----BEGIN PRIVATE KEY-----' 'fixture-key' '-----END PRIVATE KEY-----' > "$setup_tmp_dir/fixture/app-private-key.pem"
printf 'fixture-client-secret\n' > "$setup_tmp_dir/fixture/app-client-secret"
printf 'ghr_fixture-refresh-token\n' > "$setup_tmp_dir/fixture/app-user-refresh-token"
chmod 600 "$setup_tmp_dir/writer"/* "$setup_tmp_dir/reviewer"/* "$setup_tmp_dir/fixture"/*
chmod 700 "$setup_tmp_dir/writer" "$setup_tmp_dir/reviewer" "$setup_tmp_dir/fixture"
GH_TOKEN=contract-token SETUP_GH_CALLS="$setup_calls" PATH="$setup_tmp_dir/bin:$PATH" \
    bash "$setup_script" acme/github-bootstrap "$setup_tmp_dir/writer" \
    "$setup_tmp_dir/reviewer" "$setup_tmp_dir/fixture" > "$setup_tmp_dir/output"
assert_contains 'e2e-maintenance' "$setup_calls"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_WRITER_APP_CLIENT_ID' "$setup_calls"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_WRITER_APP_SLUG' "$setup_calls"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_WRITER_APP_PRIVATE_KEY' "$setup_calls"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_REVIEWER_APP_CLIENT_ID' "$setup_calls"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_REVIEWER_APP_SLUG' "$setup_calls"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_REVIEWER_APP_PRIVATE_KEY' "$setup_calls"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_CLIENT_ID' "$setup_calls"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_PRIVATE_KEY' "$setup_calls"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_CLIENT_SECRET' "$setup_calls"
assert_contains 'BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_USER_REFRESH_TOKEN' "$setup_calls"
if grep -Fq '/repos/acme/github-bootstrap/installation' "$setup_calls"; then
    echo "source setup must not claim App installation validation with operator credentials" >&2
    exit 1
fi
assert_not_contains 'ghr_fixture-refresh-token' "$setup_calls"
assert_not_contains 'ghr_fixture-refresh-token' "$setup_tmp_dir/output"
assert_not_contains 'writer-key' "$setup_tmp_dir/output"
assert_not_contains 'reviewer-key' "$setup_tmp_dir/output"

if GH_TOKEN=contract-token SETUP_GH_CALLS="$setup_calls" PATH="$setup_tmp_dir/bin:$PATH" \
    bash "$setup_script" acme/not-bootstrap "$setup_tmp_dir/writer" \
    "$setup_tmp_dir/reviewer" "$setup_tmp_dir/fixture" \
    2> "$setup_tmp_dir/scope-error"; then
    echo "setup accepted a non-source repository" >&2
    exit 1
fi
assert_contains 'OWNER/github-bootstrap' "$setup_tmp_dir/scope-error"

chmod 644 "$setup_tmp_dir/fixture/app-user-refresh-token"
if GH_TOKEN=contract-token SETUP_GH_CALLS="$setup_calls" PATH="$setup_tmp_dir/bin:$PATH" \
    bash "$setup_script" acme/github-bootstrap "$setup_tmp_dir/writer" \
    "$setup_tmp_dir/reviewer" "$setup_tmp_dir/fixture" \
    2> "$setup_tmp_dir/protection-error"; then
    echo "setup accepted an unprotected fixture refresh token" >&2
    exit 1
fi
grep -Fq 'mode 600' "$setup_tmp_dir/protection-error"
chmod 600 "$setup_tmp_dir/fixture/app-user-refresh-token"

fixture_setup_line="$(grep -n 'After creating and authorizing the fixture App' "$runbook" | cut -d: -f1)"
installer_line="$(grep -n 'install-e2e-maintenance-credentials.sh' "$runbook" | tail -n 1 | cut -d: -f1)"
[ "$fixture_setup_line" -lt "$installer_line" ] || {
    echo "runbook must create fixture credentials before invoking the installer" >&2
    exit 1
}

assert_contains 'E2E maintenance setup' "$runbook"
assert_contains 'never use production-maintenance credentials' "$runbook"
assert_contains 'install each maintenance App account-wide' "$runbook"
assert_contains 'Manual preflight sequence' "$runbook"
assert_contains 'gh api --paginate --slurp /installation/repositories' "$runbook"
assert_contains 'Verify both App installations' "$runbook"
assert_contains 'archived' "$runbook"
assert_contains 'repository-maintenance-writer-e2e' "$runbook"
assert_contains 'repository-maintenance-reviewer-e2e' "$runbook"
assert_contains 'reads until EOF' "$runbook"
assert_contains 'stty echo < /dev/tty' "$runbook"
assert_contains 'printf '\''%s'\'' "$writer_private_key" | gh secret set' "$runbook"
if grep -Eq '^read -r -s' "$runbook"; then
    echo "runbook must not use a one-line read -r -s secret example" >&2
    exit 1
fi

generated_dir="$tmp_dir/generated"
mkdir -p "$generated_dir/.github/workflows"
for maintenance_workflow in maintenance-safety.yml approve-automation-workflows.yml \
    classify-maintenance-pr.yml merge-maintenance-pr.yml git-cliff-release.yml; do
    cp "$repo_root/templates/.github/workflows/$maintenance_workflow" \
        "$generated_dir/.github/workflows/$maintenance_workflow"
done
E2E_COPILOT_REVIEWER_LOGIN='copilot-pull-request-reviewer[bot]' \
    bash "$repo_root/scripts/select-generated-workflows.sh" bind-e2e "$generated_dir" maintenance
assert_contains 'MAINTENANCE_COPILOT_REVIEWER_LOGIN: copilot-pull-request-reviewer[bot]' \
    "$generated_dir/.github/workflows/maintenance-safety.yml"
assert_contains 'COPILOT_REVIEWER_LOGIN: ${{ env.MAINTENANCE_COPILOT_REVIEWER_LOGIN }}' \
    "$generated_dir/.github/workflows/maintenance-safety.yml"
assert_contains 'COPILOT_REVIEWER_LOGIN: ${{ env.MAINTENANCE_COPILOT_REVIEWER_LOGIN }}' \
    "$generated_dir/.github/workflows/approve-automation-workflows.yml"

cat > "$tmp_dir/bot-pr.json" << 'EOF'
{"user":{"login":"repository-maintenance-writer[bot]"},"head":{"sha":"current-sha"}}
EOF
cat > "$tmp_dir/copilot-review.json" << 'EOF'
[{"user":{"login":"copilot-pull-request-reviewer[bot]"},"state":"COMMENTED","commit_id":"current-sha"}]
EOF
printf '%s\n' '[]' > "$tmp_dir/empty-reviews.json"
cat > "$tmp_dir/resolved-threads.json" << 'EOF'
[{"author_login":"copilot-pull-request-reviewer[bot]","isResolved":true}]
EOF
cat > "$tmp_dir/human-pr.json" << 'EOF'
{"state":"open","draft":false,"base":{"ref":"main","repo":{"full_name":"acme/project"}},"head":{"sha":"current-sha","repo":{"full_name":"acme/project"}},"user":{"login":"e2e-maintenance-user"},"labels":[{"name":"automation: maintenance"},{"name":"automation: validating"}],"auto_merge":{"merge_method":"SQUASH","enabled_by":{"login":"writer[bot]"}}}
EOF
if FULL_REPOSITORY=acme/project "$classifier" "$tmp_dir/human-pr.json"; then
    echo "production classifier accepted the human E2E fixture" >&2
    exit 1
fi
MAINTENANCE_IDENTITY_MODE=e2e-disposable \
    MAINTENANCE_FIXTURE_LOGIN=e2e-maintenance-user \
    FULL_REPOSITORY=acme/project "$classifier" "$tmp_dir/human-pr.json"

cat > "$tmp_dir/human-reviews.json" << 'EOF'
[{"user":{"login":"copilot-pull-request-reviewer[bot]"},"state":"COMMENTED","commit_id":"current-sha"},{"user":{"login":"reviewer[bot]"},"state":"APPROVED","commit_id":"current-sha"}]
EOF
cat > "$tmp_dir/human-reviewer-only.json" << 'EOF'
[{"user":{"login":"reviewer[bot]"},"state":"APPROVED","commit_id":"current-sha"}]
EOF
cat > "$tmp_dir/checks.json" << 'EOF'
[{"name":"Quality","state":"SUCCESS"}]
EOF
cat > "$tmp_dir/labels.json" << 'EOF'
[{"name":"automation: maintenance"},{"name":"automation: validating"}]
EOF
MAINTENANCE_IDENTITY_MODE=e2e-disposable \
    MAINTENANCE_FIXTURE_LOGIN=e2e-maintenance-user \
    MAINTENANCE_COPILOT_REVIEWER_LOGIN='copilot-pull-request-reviewer[bot]' \
    FULL_REPOSITORY=acme/project bash "$merge_validator" "$tmp_dir/human-pr.json" \
    "$tmp_dir/checks.json" "$tmp_dir/human-reviews.json" "$tmp_dir/labels.json" \
    acme/project current-sha writer reviewer true
if MAINTENANCE_IDENTITY_MODE=e2e-disposable \
    MAINTENANCE_FIXTURE_LOGIN=e2e-maintenance-user \
    MAINTENANCE_COPILOT_REVIEWER_LOGIN='copilot-pull-request-reviewer[bot]' \
    FULL_REPOSITORY=acme/project bash "$merge_validator" "$tmp_dir/human-pr.json" \
    "$tmp_dir/checks.json" "$tmp_dir/human-reviewer-only.json" "$tmp_dir/labels.json" \
    acme/project current-sha writer reviewer true; then
    echo "E2E fixture without Copilot evidence was accepted" >&2
    exit 1
fi
REQUIRE_COPILOT_REVIEW=true "$validator" "$tmp_dir/human-pr.json" \
    "$tmp_dir/copilot-review.json" "$tmp_dir/resolved-threads.json" \
    'copilot-pull-request-reviewer[bot]'
if REQUIRE_COPILOT_REVIEW=true "$validator" "$tmp_dir/bot-pr.json" \
    "$tmp_dir/empty-reviews.json" "$tmp_dir/resolved-threads.json" \
    'copilot-pull-request-reviewer[bot]'; then
    echo "generated maintenance fixture bypassed missing Copilot evidence" >&2
    exit 1
fi

cat > "$tmp_dir/merge-pr.json" << 'EOF'
{"head":{"sha":"current-sha"},"auto_merge":{"merge_method":"SQUASH","enabled_by":{"login":"writer[bot]"}}}
EOF
cat > "$tmp_dir/reviewer-approval.json" << 'EOF'
[{"user":{"login":"reviewer[bot]"},"state":"APPROVED","commit_id":"current-sha"}]
EOF
bash "$merge_state_validator" "$tmp_dir/merge-pr.json" "$tmp_dir/reviewer-approval.json" \
    current-sha writer reviewer
sed 's/"enabled_by"/"disabled_by"/' "$tmp_dir/merge-pr.json" > "$tmp_dir/no-auto-merge.json"
if bash "$merge_state_validator" "$tmp_dir/no-auto-merge.json" \
    "$tmp_dir/reviewer-approval.json" current-sha writer reviewer; then
    echo "missing Writer auto-merge state was accepted" >&2
    exit 1
fi
cat > "$tmp_dir/releases.json" << 'EOF'
[{"tag_name":"v1.2.3","created_at":"2026-09-10T05:00:00Z"}]
EOF
cat > "$tmp_dir/tags.json" << 'EOF'
[{"name":"v1.2.3","commit":{"sha":"merge-sha"}}]
EOF
bash "$release_validator" "$tmp_dir/releases.json" "$tmp_dir/tags.json" \
    merge-sha 2026-09-10T04:00:00Z
sed 's/merge-sha/stale-sha/' "$tmp_dir/tags.json" > "$tmp_dir/stale-tags.json"
if bash "$release_validator" "$tmp_dir/releases.json" "$tmp_dir/stale-tags.json" \
    merge-sha 2026-09-10T04:00:00Z; then
    echo "release pointing at a stale head was accepted" >&2
    exit 1
fi

echo "Generated maintenance E2E contract passed."
