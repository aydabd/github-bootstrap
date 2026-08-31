#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
resolver="$repo_root/.github/actions/resolve-gh-token/action.yml"
app_validator="$script_dir/validate-app-auth.sh"
merge_workflow="$repo_root/.github/workflows/merge-maintenance-pr.yml"

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

assert_contains "client-id: \${{ inputs.client_id }}" "$resolver"
assert_contains "private-key: \${{ inputs.app_private_key }}" "$resolver"
assert_contains "app_user_token" "$resolver"
assert_contains "GH_TOKEN=\"\$APP_USER_TOKEN\" gh api /user --jq '.login'" "$resolver"
assert_contains "ghu_ prefix" "$resolver"
assert_contains "GH_TOKEN: \${{ github.token }}" "$resolver"
assert_contains "target_owner_type=\"\$(gh api \"/users/\$TARGET_OWNER\" --jq '.type')\"" "$resolver"
assert_contains "AUTH_MODE=owner-only bash ./scripts/github-setup/validate-app-auth.sh" "$resolver"
assert_contains "AUTH_MODE=app-user bash ./scripts/github-setup/validate-app-auth.sh" "$resolver"
assert_contains "echo \"::add-mask::\$APP_USER_TOKEN\"" "$resolver"
assert_contains "case \"\$target_owner_type\" in" "$resolver"
assert_contains "Organization)" "$resolver"
assert_contains "User access tokens cannot be used for organization targets" "$resolver"
assert_contains "repository-creation|repository-cleanup" "$resolver"
assert_contains "mode=app-user" "$resolver"
assert_contains "owner: \${{ inputs.app_owner }}" "$resolver"
assert_contains "permission-administration:" "$resolver"
assert_contains "permission-contents:" "$resolver"
assert_contains "permission-issues:" "$resolver"
assert_contains "permission-organization-administration:" "$resolver"
assert_contains "permission_profile:" "$resolver"
assert_contains "repositories:" "$resolver"
assert_contains "repositories: \${{ inputs.repositories }}" "$resolver"
assert_contains "permission-pull-requests:" "$resolver"
assert_contains "permission-actions:" "$resolver"
assert_contains "workflow-approval" "$resolver"
assert_contains "maintenance-review" "$resolver"
assert_contains "maintenance-labeling" "$resolver"
assert_contains "permission_profile == 'maintenance-labeling'" "$resolver"
assert_contains "e2e-lifecycle" "$resolver"
assert_contains "Repository scoping is required" "$resolver"
assert_contains "Unsupported GitHub App permission profile '\$PERMISSION_PROFILE'" "$resolver"
assert_contains "required except for repository-creation" "$resolver"
assert_not_contains "gh_pat_secret" "$resolver"
assert_not_contains "gh_token" "$resolver"
assert_contains "github.event.workflow_run.conclusion == 'success' &&" "$merge_workflow"
assert_contains "github.event.workflow_run.pull_requests[0].number" "$merge_workflow"
assert_contains "pull_request_target:" "$repo_root/.github/workflows/classify-maintenance-pr.yml"
assert_contains "permission_profile: maintenance-labeling" "$repo_root/.github/workflows/classify-maintenance-pr.yml"
assert_contains "Verify Writer App installation" "$repo_root/.github/workflows/classify-maintenance-pr.yml"
assert_contains "validate-maintenance-pr.sh" "$repo_root/.github/workflows/classify-maintenance-pr.yml"
assert_contains 'automation: maintenance' "$repo_root/.github/workflows/classify-maintenance-pr.yml"
assert_contains 'automation: validating' "$repo_root/.github/workflows/classify-maintenance-pr.yml"
assert_contains "issues/\$PR_NUMBER/labels" "$repo_root/.github/workflows/classify-maintenance-pr.yml"
assert_not_contains "gh pr edit \"\$PR_NUMBER\"" "$repo_root/.github/workflows/classify-maintenance-pr.yml"
assert_contains "if ! classification=\"\$(bash scripts/github-setup/validate-maintenance-pr.sh \"\$pr_file\")\"; then" "$repo_root/.github/workflows/classify-maintenance-pr.yml"
template_classifier="$repo_root/templates/.github/workflows/classify-maintenance-pr.yml"
assert_contains "actions/create-github-app-token" "$template_classifier"
assert_contains "Verify Writer App installation" "$template_classifier"
assert_contains ".github/scripts/validate-maintenance-pr.sh" "$template_classifier"
assert_contains "issues/\$PR_NUMBER/labels" "$template_classifier"
assert_not_contains "gh pr edit \"\$PR_NUMBER\"" "$template_classifier"
[ -x "$repo_root/templates/.github/scripts/validate-maintenance-pr.sh" ]

for workflow in create-repository.yml terraform-create-repository.yml; do
    workflow_path="$repo_root/.github/workflows/$workflow"
    assert_contains "client_id: \${{ inputs.client_id }}" "$workflow_path"
    assert_contains "app_private_key: \${{ secrets.BOOTSTRAP_PROVISIONER_APP_PRIVATE_KEY }}" "$workflow_path"
    assert_contains "app_user_token: \${{ secrets.BOOTSTRAP_PROVISIONER_APP_USER_TOKEN }}" "$workflow_path"
    assert_contains "target_owner:" "$workflow_path"
    assert_contains "Reject internal visibility for personal accounts" "$workflow_path"
    assert_contains "inputs.visibility == 'internal'" "$workflow_path"
    assert_contains "Internal visibility is supported only for organization repositories" "$workflow_path"
    assert_contains "git remote set-url origin" "$workflow_path"
    if [ "$workflow" = create-repository.yml ]; then
        assert_contains "http.extraheader=\"AUTHORIZATION: basic \$GIT_AUTH_HEADER\"" "$workflow_path"
    else
        assert_contains "http.extraheader=\"AUTHORIZATION: bearer \$GH_TOKEN\"" "$workflow_path"
    fi
    assert_contains "allowed_repo_owners:" "$workflow_path"
    assert_not_contains "GH_PAT" "$workflow_path"
    assert_not_contains "gh_token: \${{ inputs.gh_token }}" "$workflow_path"
    assert_not_contains "REPO_NAME=\"\${{ inputs.repo_name }}\"" "$workflow_path"
    assert_not_contains "VISIBILITY=\"\${{ inputs.visibility }}\"" "$workflow_path"
    assert_not_contains "if [ -z \"\${{ inputs.repo_owner }}\" ]" "$workflow_path"
    assert_not_contains "git clone https://x-access-token:\${GH_TOKEN}@\${GH_HOST}/\${{" "$workflow_path"
    assert_not_contains "sed -i \"s/team-leads/\${{ inputs.team_name }}/g\"" "$workflow_path"
    assert_not_contains "OWNER=\"\${{ needs." "$workflow_path"
done

assert_contains "AUTH_MODE: \${{ steps.resolve-token.outputs.auth_mode }}" "$repo_root/.github/workflows/create-repository.yml"
assert_contains "set -euo pipefail" "$repo_root/.github/workflows/create-repository.yml"
assert_not_contains "echo \"repo_created=false\" >> \"\$GITHUB_OUTPUT\"" "$repo_root/.github/workflows/create-repository.yml"

for workflow in create-repository.yml terraform-create-repository.yml; do
    assert_contains "BOOTSTRAP_PROVISIONER_APP_USER_TOKEN:" "$repo_root/.github/workflows/$workflow"
    assert_contains "required: false" "$repo_root/.github/workflows/$workflow"
done

assert_contains "target_owner: \${{ steps.target.outputs.owner }}" "$repo_root/.github/workflows/delete-repo.yml"
assert_contains "repositories: \${{ steps.target.outputs.repository }}" "$repo_root/.github/workflows/delete-repo.yml"
assert_contains "bash ./scripts/github-setup/validate-app-auth.sh" "$resolver"
assert_contains "repositories: \${{ inputs.repo_name }}" "$repo_root/.github/workflows/setup-existing-repository.yml"
assert_contains "repositories: \${{ github.event.repository.name }}" "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
assert_contains "repositories: \${{ needs.create-test-repo.outputs.test_repo_name }}" "$repo_root/.github/workflows/test-repository-creation.yml"
assert_contains "contents: write" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "pull-requests: write" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "issues: read" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "inputs.permission_profile == 'weekly-tooling'" "$resolver"
assert_contains "inputs.permission_profile == 'repository-creation'" "$resolver"
assert_contains "uses: ./.github/actions/resolve-gh-token" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "permission_profile: weekly-tooling" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains 'TOOLING_UPDATE_METADATA_FILE' "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains 'validate-tooling-metadata.sh' "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains 'TOOLING_UPDATE_EXPLICIT_BREAKING' "$repo_root/.github/workflows/weekly-tooling-updates.yml"
no_update_line="$(grep -n 'No tooling updates detected; skipping PR creation.' "$repo_root/.github/workflows/weekly-tooling-updates.yml" | cut -d: -f1)"
validator_line="$(grep -n 'validate-tooling-metadata.sh' "$repo_root/.github/workflows/weekly-tooling-updates.yml" | cut -d: -f1)"
[ "$no_update_line" -lt "$validator_line" ] || {
    echo "no-update path must precede strict metadata validation" >&2
    exit 1
}
assert_contains 'automation: maintenance' "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains 'automation: validating' "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains 'automation: breaking' "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains 'automation: blocked' "$repo_root/.github/workflows/weekly-tooling-updates.yml"
approval_workflow="$repo_root/.github/workflows/approve-automation-workflows.yml"
assert_contains "workflow_run:" "$approval_workflow"
assert_contains "conclusion == 'action_required'" "$approval_workflow"
assert_contains "permission_profile: workflow-approval" "$approval_workflow"
assert_contains "BOOTSTRAP_REVIEWER_APP_PRIVATE_KEY" "$approval_workflow"
assert_contains "BOOTSTRAP_MAINTENANCE_REVIEWER_APP_SLUG" "$approval_workflow"
assert_contains 'Resolved App is not the configured maintenance Reviewer' "$approval_workflow"
assert_contains "actions: read" "$approval_workflow"
assert_contains "pull-requests: read" "$approval_workflow"
assert_contains "actions/runs/\$RUN_ID/approve" "$approval_workflow"
assert_contains "validate-workflow-approval.sh" "$approval_workflow"
assert_not_contains "pull-requests: write" "$approval_workflow"
assert_contains '--add-label' "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains '--remove-label "automation: breaking"' "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains '--remove-label "automation: blocked"' "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_not_contains "gh pr edit \"\$pr_number\" --label" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "GH_TOKEN: \${{ steps.resolve-token.outputs.token }}" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "APP_SLUG: \${{ steps.resolve-token.outputs.app_slug }}" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_not_contains "APP_ID:" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_not_contains "app_id:" "$resolver"
assert_not_contains "GH_TOKEN: \${{ github.token }}" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_not_contains "automation_login=\"\$GITHUB_ACTOR\"" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_not_contains "automation_id=\"\$GITHUB_ACTOR_ID\"" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_not_contains 'gh api /user --jq' "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "set -euo pipefail" "$resolver"
assert_not_contains ">> \$GITHUB_OUTPUT" "$resolver"
assert_not_contains ">> \$GITHUB_OUTPUT" "$repo_root/.github/workflows/test-repository-creation.yml"
for workflow in create-repository.yml terraform-create-repository.yml test-repository-creation.yml; do
    assert_not_contains ">> \$GITHUB_STEP_SUMMARY" "$repo_root/.github/workflows/$workflow"
done

for example in "$repo_root"/examples/launcher-*.yml; do
    assert_not_contains "PAT" "$example"
    assert_not_contains "app_id" "$example"
done

assert_not_contains "app_id" "$repo_root/README.md"
assert_not_contains "app_id" "$repo_root/terraform/README.md"
assert_contains "allowed_repo_owners" "$repo_root/terraform/README.md"
assert_contains "personal-account mode" "$repo_root/README.md"
assert_not_contains "BOOTSTRAP_APP_ID" "$repo_root/examples/launcher-actions.yml"
assert_not_contains "BOOTSTRAP_APP_ID" "$repo_root/examples/launcher-terraform.yml"
assert_contains "Owner allowlist is required" "$repo_root/.github/actions/validate-bootstrap-owner/action.yml"
assert_not_contains 'default: ""' "$repo_root/.github/actions/validate-bootstrap-owner/action.yml"
assert_contains "GitHub App user access token for personal targets" "$repo_root/terraform/README.md"
assert_contains "empty uses the authenticated token owner" "$repo_root/terraform/variables.tf"
assert_contains "When empty, the GitHub provider uses the authenticated token owner" "$repo_root/terraform/README.md"
assert_not_contains "Members, pull requests, actions" "$repo_root/docs/github-app-permission-matrix.md"
assert_contains "Pull-request" "$repo_root/docs/github-app-permission-matrix.md"
assert_contains "does not match target repository owner" "$app_validator"
assert_contains "GitHub App user-token owner" "$app_validator"
assert_contains "Configured GitHub App owner" "$app_validator"
assert_contains "AUTH_MODE=\"\${AUTH_MODE:-app}\"" "$app_validator"
assert_contains "AUTH_MODE=app-user" "$resolver"
assert_contains "GitHub App user access tokens are reserved" "$repo_root/.github/actions/audit-bootstrap-request/action.yml"
assert_contains "set -euo pipefail" "$repo_root/.github/actions/audit-bootstrap-request/action.yml"
assert_contains ">> \"\$GITHUB_OUTPUT\"" "$repo_root/.github/workflows/terraform-create-repository.yml"
assert_not_contains ">> \$GITHUB_OUTPUT" "$repo_root/.github/workflows/create-repository.yml"

expect_rejected() {
    if env "$@" > /dev/null 2>&1; then
        echo "expected App configuration to be rejected: $*" >&2
        exit 1
    fi
}

APP_CLIENT_ID=client APP_PRIVATE_KEY=key APP_OWNER=acme TARGET_OWNER=acme \
    bash "$app_validator" > /dev/null
AUTH_MODE=app-user APP_OWNER=alice TARGET_OWNER=Alice \
    bash "$app_validator" > /dev/null
AUTH_MODE=owner-only APP_OWNER=alice TARGET_OWNER=Alice \
    bash "$app_validator" > /dev/null
expect_rejected APP_CLIENT_ID=client APP_PRIVATE_KEY=key APP_OWNER=acme TARGET_OWNER=other \
    bash "$app_validator"
expect_rejected AUTH_MODE=app-user APP_OWNER=alice TARGET_OWNER=other \
    bash "$app_validator"
expect_rejected APP_CLIENT_ID=client APP_PRIVATE_KEY= APP_OWNER=acme TARGET_OWNER=acme \
    bash "$app_validator"
expect_rejected APP_CLIENT_ID=client APP_PRIVATE_KEY=key APP_OWNER= TARGET_OWNER=acme \
    bash "$app_validator"

echo "GitHub App auth contract checks passed."
