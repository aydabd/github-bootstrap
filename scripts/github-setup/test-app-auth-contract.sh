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

workflow_step_block() {
    local step_name="$1" file="$2"
    awk -v step_name="$step_name" '
        $0 == "      - name: " step_name { in_step = 1 }
        in_step && $0 ~ /^      - name:/ && $0 != "      - name: " step_name { exit }
        in_step { print }
    ' "$file"
}

workflow_job_block() {
    local job_name="$1" file="$2"
    awk -v job_name="$job_name" '
        $0 == "  " job_name ":" { in_job = 1 }
        in_job && /^  [A-Za-z0-9_-]+:/ && $0 != "  " job_name ":" { exit }
        in_job { print }
    ' "$file"
}

assert_not_line() {
    local pattern="$1"
    local file="$2"
    if grep -Eq -- "$pattern" "$file"; then
        echo "unexpected line matching '$pattern' in $file" >&2
        exit 1
    fi
}

# Keep helper declarations before every contract assertion so ShellCheck can
# resolve the functions when this script is analyzed as a whole.
first_assertion_line="$(awk '
    /^[[:space:]]*assert_(contains|not_contains|not_line)[[:space:]]+/ &&
        $0 !~ /^[[:space:]]*assert_(contains|not_contains|not_line)\(\)[[:space:]]*\{/ {
        print NR
        exit
    }
' "${BASH_SOURCE[0]}")"
for helper in assert_contains assert_not_contains assert_not_line; do
    helper_definition_line="$(awk -v name="$helper" '$0 ~ ("^" name "\\(\\)") { print NR; exit }' "${BASH_SOURCE[0]}")"
    [ "$helper_definition_line" -lt "$first_assertion_line" ] || {
        echo "$helper must be defined before contract assertions" >&2
        exit 1
    }
done

assert_contains "client-id: \${{ inputs.client_id }}" "$resolver"
assert_contains "private-key: \${{ inputs.app_private_key }}" "$resolver"
assert_contains "app_user_refresh_token" "$resolver"
assert_contains "app_client_secret" "$resolver"
assert_contains "refresh_token_secret" "$resolver"
assert_contains "refresh_token_secret_environment" "$resolver"
legacy_prefix='BOOTSTRAP_PROVISIONER_APP_'
assert_not_contains "${legacy_prefix}USER_REFRESH_TOKEN" "$resolver"
assert_not_contains "${legacy_prefix}CLIENT_SECRET" "$resolver"
assert_contains "ghr_ prefix" "$resolver"
assert_contains "GH_TOKEN: \${{ github.token }}" "$resolver"
assert_contains "target_owner_type=\"\$(gh api \"/users/\$TARGET_OWNER\" --jq '.type')\"" "$resolver"
assert_contains "AUTH_MODE=owner-only bash ./scripts/github-setup/validate-app-auth.sh" "$resolver"
assert_contains "AUTH_MODE=app-user bash ./scripts/github-setup/validate-app-auth.sh" "$resolver"
assert_contains "echo \"::add-mask::\$APP_USER_REFRESH_TOKEN\"" "$resolver"
assert_contains "case \"\$target_owner_type\" in" "$resolver"
assert_contains "Organization)" "$resolver"
assert_contains "repository-creation|repository-cleanup|e2e-dispatch" "$resolver"
assert_contains "e2e-dispatch" "$resolver"
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
assert_contains "maintenance-merge" "$resolver"
assert_contains "maintenance-labeling" "$resolver"
assert_contains "permission_profile == 'maintenance-labeling'" "$resolver"
assert_contains "e2e-lifecycle" "$resolver"
assert_contains "inputs.permission_profile == 'e2e-dispatch'" "$resolver"
assert_contains "Repository scoping is required" "$resolver"
assert_contains "Unsupported GitHub App permission profile '\$PERMISSION_PROFILE'" "$resolver"
assert_contains "required except for repository-creation" "$resolver"
assert_not_contains "gh_pat_secret" "$resolver"
assert_not_contains "gh_token" "$resolver"
assert_contains "github.event.workflow_run.conclusion == 'success'" "$merge_workflow"
# Conda pull_request runs carry the exact PR number; pull_request_target-driven
# safety runs still use the validated head branch fallback.
assert_contains "github.event.workflow_run.pull_requests[0].number" "$merge_workflow"
assert_contains "-f head=\"\${REPOSITORY%%/*}:\$HEAD_BRANCH\" -f base=main -f state=open" "$merge_workflow"
assert_contains "github.event.workflow_run.head_branch" "$merge_workflow"
assert_contains "github.event.workflow_run.head_branch != 'main'" "$merge_workflow"
assert_contains "pull_request_target:" "$repo_root/.github/workflows/classify-maintenance-pr.yml"
assert_contains "permission_profile: maintenance-labeling" "$repo_root/.github/workflows/classify-maintenance-pr.yml"
assert_contains "Verify Writer App installation" "$repo_root/.github/workflows/classify-maintenance-pr.yml"
assert_contains 'automation: breaking' "$repo_root/.github/workflows/classify-maintenance-pr.yml"

# release-please must run under the Writer App identity, otherwise its release
# PRs are opened with GITHUB_TOKEN and never trigger the maintenance automation.
release_workflow="$repo_root/.github/workflows/release-please.yml"
assert_contains "release-please" "$resolver"
assert_contains "permission_profile == 'release-please'" "$resolver"
assert_contains "permission_profile: release-please" "$release_workflow"
assert_contains "uses: ./.github/actions/resolve-gh-token" "$release_workflow"
assert_contains "token: \${{ steps.resolve-token.outputs.token }}" "$release_workflow"
assert_contains "environment: production-maintenance" "$release_workflow"
assert_not_contains "\${{ secrets.GITHUB_TOKEN }}" "$release_workflow"
assert_contains "Verify Maintenance Writer installation access" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "/installation/repositories" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "gh api --paginate --slurp /installation/repositories" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "jq -c --arg target \"\$TARGET_REPOSITORY\"" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "Maintenance Writer repository access:" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "Maintenance Writer installation cannot see" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
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

template_script_dir="$repo_root/templates/.github/scripts"
for script_name in gh-common.sh validate-app-auth.sh validate-maintenance-pr.sh \
    validate-maintenance-merge.sh validate-workflow-approval.sh \
    validate-copilot-review.sh validate-maintenance-safety.sh; do
    [ -x "$template_script_dir/$script_name" ] || {
        echo "missing executable template maintenance script: $script_name" >&2
        exit 1
    }
done
for workflow in approve-automation-workflows.yml classify-maintenance-pr.yml \
    maintenance-safety.yml merge-maintenance-pr.yml; do
    workflow_path="$repo_root/templates/.github/workflows/$workflow"
    while IFS= read -r script_reference; do
        script_name="${script_reference##*/}"
        [ -x "$template_script_dir/$script_name" ] || {
            echo "workflow references an unshipped template script: $script_name" >&2
            exit 1
        }
    done < <(grep -oE '\.github/scripts/[A-Za-z0-9._-]+\.sh' "$workflow_path" | sort -u)
done

template_release_workflow="$repo_root/templates/.github/workflows/release-please.yml"
assert_contains "actions/create-github-app-token" "$template_release_workflow"
assert_contains "client-id: \${{ vars.BOOTSTRAP_MAINTENANCE_WRITER_APP_CLIENT_ID }}" "$template_release_workflow"
assert_contains "private-key: \${{ secrets.BOOTSTRAP_MAINTENANCE_WRITER_APP_PRIVATE_KEY }}" "$template_release_workflow"
assert_contains "token: \${{ steps.resolve-token.outputs.token }}" "$template_release_workflow"
assert_contains "APP_SLUG: \${{ steps.resolve-token.outputs.app-slug }}" "$template_release_workflow"
assert_contains "EXPECTED_APP_SLUG" "$template_release_workflow"
assert_contains "Resolved App is not the configured Writer" "$template_release_workflow"
assert_not_contains "token: \${{ github.token }}" "$template_release_workflow"

maintenance_workflows=(
    classify-maintenance-pr.yml
    maintenance-safety.yml
    approve-automation-workflows.yml
    merge-maintenance-pr.yml
    release-please.yml
)
for workflow in "${maintenance_workflows[@]}"; do
    workflow_path="$repo_root/templates/.github/workflows/$workflow"
    assert_contains "environment: production-maintenance" "$workflow_path"
    assert_not_contains "BOOTSTRAP_REVIEWER_APP_CLIENT_ID" "$workflow_path"
    assert_not_contains "BOOTSTRAP_REVIEWER_APP_PRIVATE_KEY" "$workflow_path"
    assert_not_contains "secrets.GITHUB_TOKEN" "$workflow_path"
done

template_classifier="$repo_root/templates/.github/workflows/classify-maintenance-pr.yml"
# shellcheck disable=SC2016 # Literal GitHub Actions expression in contract text.
assert_contains 'WRITER_APP_SLUG: ${{ vars.BOOTSTRAP_MAINTENANCE_WRITER_APP_SLUG }}' \
    "$template_classifier"
assert_not_contains 'github-actions[bot]' \
    "$repo_root/templates/.github/scripts/validate-maintenance-pr.sh"
for template_validator in validate-maintenance-merge.sh validate-workflow-approval.sh; do
    assert_not_contains 'github-actions[bot]' \
        "$repo_root/templates/.github/scripts/$template_validator"
done

template_approval="$repo_root/templates/.github/workflows/approve-automation-workflows.yml"
assert_contains 'validate-workflow-approval.sh' "$template_approval"
assert_contains 'validate-copilot-review.sh' "$template_approval"
assert_contains 'reviewThreads(first:100)' "$template_approval"
assert_contains 'isResolved' "$template_approval"
# shellcheck disable=SC2016 # Literal workflow command in contract text.
assert_contains 'gh api --method POST "/repos/$GITHUB_REPOSITORY/actions/runs/$RUN_ID/approve"' \
    "$template_approval"

template_merge="$repo_root/templates/.github/workflows/merge-maintenance-pr.yml"
assert_contains 'permission_profile: maintenance-review' "$template_merge"
assert_contains 'permission_profile: maintenance-merge' "$template_merge"
assert_contains 'validate_state true' "$template_merge"
# shellcheck disable=SC2016 # Literal workflow command in contract text.
assert_contains 'gh api --method POST "/repos/$REPOSITORY/pulls/$PR_NUMBER/reviews"' \
    "$template_merge"
# shellcheck disable=SC2016 # Literal workflow command in contract text.
assert_contains 'GH_TOKEN="$MERGE_TOKEN" gh api graphql' "$template_merge"
assert_not_contains 'gh pr merge' "$template_merge"

for workflow in create-repository.yml terraform-create-repository.yml; do
    workflow_path="$repo_root/.github/workflows/$workflow"
    assert_contains "provisioner_profile:" "$workflow_path"
    assert_contains "default: production-provisioner" "$workflow_path"
    assert_contains "- production-provisioner" "$workflow_path"
    assert_contains "- e2e-provisioner" "$workflow_path"
    assert_contains "needs.validate-provisioner.outputs.profile" "$workflow_path"
    assert_contains "BOOTSTRAP_PRODUCTION_PROVISIONER_APP_PRIVATE_KEY" "$workflow_path"
    assert_contains "BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_SECRET" "$workflow_path"
    assert_contains "BOOTSTRAP_PRODUCTION_PROVISIONER_APP_USER_REFRESH_TOKEN" "$workflow_path"
    assert_contains "BOOTSTRAP_E2E_PROVISIONER_APP_PRIVATE_KEY" "$workflow_path"
    assert_contains "BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_SECRET" "$workflow_path"
    assert_contains "BOOTSTRAP_E2E_PROVISIONER_APP_USER_REFRESH_TOKEN" "$workflow_path"
    assert_not_contains "secrets.${legacy_prefix}PRIVATE_KEY" "$workflow_path"
    assert_not_contains "secrets.${legacy_prefix}CLIENT_SECRET" "$workflow_path"
    assert_not_contains "secrets.${legacy_prefix}USER_REFRESH_TOKEN" "$workflow_path"
    assert_contains "refresh_token_secret:" "$workflow_path"
    assert_contains "refresh_token_secret_environment:" "$workflow_path"
    assert_not_line '^      client_id:' "$workflow_path"
    assert_not_contains "inputs.client_id ||" "$workflow_path"
    assert_contains "PROVISIONER_PROFILE: \${{ needs.validate-provisioner.outputs.profile }}" "$workflow_path"
    assert_contains "environment: \${{ needs.validate-provisioner.outputs.environment }}" "$workflow_path"
    assert_contains "PROVISIONER_ENVIRONMENT: \${{ needs.validate-provisioner.outputs.environment }}" "$workflow_path"
    assert_not_contains "secrets[" "$workflow_path"
    assert_contains "uses: ./.github/actions/configure-provisioner-credentials" "$workflow_path"
    assert_contains "if: needs.validate-provisioner.outputs.profile == 'production-provisioner'" "$workflow_path"
    assert_contains "if: needs.validate-provisioner.outputs.profile == 'e2e-provisioner'" "$workflow_path"
    assert_contains "app_private_key: \${{ env.PROVISIONER_PRIVATE_KEY }}" "$workflow_path"
    assert_contains "app_user_refresh_token: \${{ env.PROVISIONER_REFRESH_TOKEN }}" "$workflow_path"
    assert_contains "app_client_secret: \${{ env.PROVISIONER_CLIENT_SECRET }}" "$workflow_path"
    assert_contains "target_owner:" "$workflow_path"
    assert_contains "Reject internal visibility for personal accounts" "$workflow_path"
    assert_contains "inputs.visibility == 'internal'" "$workflow_path"
    assert_contains "Internal visibility is supported only for organization repositories" "$workflow_path"
    assert_contains "git remote set-url origin" "$workflow_path"
    assert_contains "http.extraheader=\"AUTHORIZATION: basic \$GIT_AUTH_HEADER\"" "$workflow_path"
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

for caller_job in create-public create-private; do
    caller_block="$(awk -v job="$caller_job" '
        $0 == "  " job ":" { in_job = 1 }
        in_job && /^  [A-Za-z0-9_-]+:/ && $0 != "  " job ":" { exit }
        in_job { print }
    ' "$repo_root/.github/workflows/test-personal-app-e2e.yml")"
    printf '%s\n' "$caller_block" | grep -Fq \
        "BOOTSTRAP_E2E_MAINTENANCE_WRITER_APP_PRIVATE_KEY: \${{ secrets.BOOTSTRAP_E2E_MAINTENANCE_WRITER_APP_PRIVATE_KEY }}"
    printf '%s\n' "$caller_block" | grep -Fq \
        "BOOTSTRAP_E2E_MAINTENANCE_REVIEWER_APP_PRIVATE_KEY: \${{ secrets.BOOTSTRAP_E2E_MAINTENANCE_REVIEWER_APP_PRIVATE_KEY }}"
done

assert_contains "needs: validate-provisioner" "$repo_root/.github/workflows/create-repository.yml"
assert_contains "needs: validate-provisioner" "$repo_root/.github/workflows/terraform-create-repository.yml"
assert_not_contains "environment: \${{ inputs.provisioner_profile == 'e2e-provisioner' && 'e2e-testing' || 'production-provisioning' }}" "$repo_root/.github/workflows/create-repository.yml"
assert_not_contains "environment: \${{ inputs.provisioner_profile == 'e2e-provisioner' && 'e2e-testing' || 'production-provisioning' }}" "$repo_root/.github/workflows/terraform-create-repository.yml"

credentials_action="$repo_root/.github/actions/configure-provisioner-credentials/action.yml"
assert_contains "profile:" "$credentials_action"
assert_contains "repository:" "$credentials_action"
assert_contains "app_slug:" "$credentials_action"
assert_contains "e2e-maintenance-writer" "$credentials_action"
assert_contains "e2e-maintenance-reviewer" "$credentials_action"
assert_contains "app_slug_variable" "$credentials_action"
assert_contains "private_key_secret" "$credentials_action"
assert_contains "--env \"\$ENVIRONMENT_INPUT\"" "$credentials_action"
assert_contains "gh_token:" "$credentials_action"
assert_contains "GH_TOKEN_INPUT: \${{ inputs.gh_token }}" "$credentials_action"
assert_contains "if [ -z \"\$GH_TOKEN_INPUT\" ]; then" "$credentials_action"
assert_contains 'Missing GitHub token for maintenance credential writes' "$credentials_action"
assert_contains "GH_TOKEN=\"\$GH_TOKEN_INPUT\" gh variable set" "$credentials_action"
assert_contains "GH_TOKEN=\"\$GH_TOKEN_INPUT\" gh secret set" "$credentials_action"
assert_not_contains "--body \"\$APP_PRIVATE_KEY_INPUT\"" "$credentials_action"
assert_contains "production-maintenance-writer" "$credentials_action"
assert_contains "production-maintenance-reviewer" "$credentials_action"
assert_contains "installation (\$PROFILE_INPUT) cannot see \$REPOSITORY_INPUT" "$credentials_action"
assert_contains "Profile-specific maintenance installation preflight failed" "$credentials_action"
assert_contains "/installation/repositories" "$credentials_action"
assert_contains "gh api \"/repos/\$REPOSITORY_INPUT\"" "$credentials_action"
assert_contains "MAINTENANCE_TOKEN_INPUT" "$credentials_action"
assert_contains "actions/create-github-app-token" "$credentials_action"
assert_contains "target_owner" "$credentials_action"
assert_contains "repository_name" "$credentials_action"
assert_not_contains "Maintenance credentials must target e2e-maintenance" "$credentials_action"

token_guard_line="$(grep -nF "if [ -z \"\$GH_TOKEN_INPUT\" ]; then" "$credentials_action" | head -n1 | cut -d: -f1)"
first_write_line="$(grep -nF "GH_TOKEN=\"\$GH_TOKEN_INPUT\" gh variable set" "$credentials_action" | head -n1 | cut -d: -f1)"
if [ -z "$token_guard_line" ] || [ -z "$first_write_line" ] || [ "$token_guard_line" -ge "$first_write_line" ]; then
    echo "GitHub token must be rejected before maintenance credential writes" >&2
    exit 1
fi

for workflow in create-repository.yml terraform-create-repository.yml; do
    workflow_path="$repo_root/.github/workflows/$workflow"
    assert_not_contains "provisioner_token: \${{ steps.resolve-token.outputs.token }}" "$workflow_path"
    assert_not_contains 'outputs.provisioner_token' "$workflow_path"
    assert_contains "BOOTSTRAP_MAINTENANCE_WRITER_APP_PRIVATE_KEY" "$workflow_path"
    assert_contains "BOOTSTRAP_MAINTENANCE_REVIEWER_APP_PRIVATE_KEY" "$workflow_path"
    assert_contains "profile: production-maintenance-writer" "$workflow_path"
    assert_contains "profile: production-maintenance-reviewer" "$workflow_path"
    assert_contains "Profile-specific maintenance installation preflight failed" "$credentials_action"
    assert_contains "cannot see \$REPOSITORY_INPUT" "$credentials_action"
    assert_contains "[ -n \"\$MAINTENANCE_TOKEN_INPUT\" ]" "$credentials_action"
    assert_contains "GH_TOKEN=\"\$GH_TOKEN_INPUT\" gh variable set \"\$client_id_variable\" --repo \"\$REPOSITORY_INPUT\" --env \"\$ENVIRONMENT_INPUT\"" "$credentials_action"
    assert_contains "gh secret set \"\$private_key_secret\"" "$credentials_action"
    assert_contains "--env \"\$ENVIRONMENT_INPUT\"" "$credentials_action"
    assert_contains "environment: production-maintenance" "$workflow_path"
    assert_contains "environment: e2e-maintenance" "$workflow_path"
    assert_contains "if: needs.validate-provisioner.outputs.profile == 'production-provisioner'" "$workflow_path"
    assert_contains "if: needs.validate-provisioner.outputs.profile == 'e2e-provisioner'" "$workflow_path"
    for maintenance_job in configure-e2e-maintenance-credentials configure-production-maintenance-credentials; do
        grep -Fq "  $maintenance_job:" "$workflow_path"
    done
    grep -Fq 'id: provisioner-token' "$workflow_path"
    grep -Fq 'uses: ./.github/actions/resolve-gh-token' "$workflow_path"
    # shellcheck disable=SC2016 # Literal GitHub Actions expression.
    grep -Fq 'app_private_key: ${{ secrets.BOOTSTRAP_' "$workflow_path"
    assert_not_contains 'needs.create-repository.outputs.provisioner_token' "$workflow_path"
    assert_not_contains 'needs.terraform-create-repository.outputs.provisioner_token' "$workflow_path"
    assert_not_contains 'refresh_token_secret_environment: e2e-testing' "$workflow_path"
    assert_not_contains 'refresh_token_secret_environment: production-provisioning' "$workflow_path"
    grep -Fq 'environment: e2e-maintenance' "$workflow_path"
    grep -Fq 'environment: production-maintenance' "$workflow_path"
    grep -Fq "GH_HOST: \${{ inputs.github_host || 'github.com' }}" "$workflow_path"
done

preflight_tmp="$(mktemp -d)"
preflight_bin="$preflight_tmp/bin"
mkdir -p "$preflight_bin"
cat > "$preflight_bin/gh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\t%s\t%s\n' "${GH_TOKEN:-}" "${GITHUB_API_URL:-}" "$*" >> "${CALLER_GH_CALLS:?}"
case "$*" in
    *"/installation/repositories"*) printf '%s\n' '[{"repositories":[]}]' ;;
    *) exit 1 ;;
esac
EOF
chmod 700 "$preflight_bin/gh"
run_caller_preflight_fixture() {
    local workflow_path="$1" fixture_name="$2" repository_fixture="$3"
    local api_url_fixture="$4" provisioner_token_fixture="$5"
    local maintenance_token_fixture="$6" expected_condition="$7"
    local workflow_name="${workflow_path##*/}" caller_fixture caller_block
    caller_fixture="$preflight_tmp/$fixture_name-caller.sh"
    caller_block="$(workflow_job_block configure-e2e-maintenance-credentials "$workflow_path")"
    caller_profile="$(printf '%s\n' "$caller_block" | sed -n 's/^          profile: //p' | head -n1)"
    caller_environment="$(printf '%s\n' "$caller_block" | sed -n 's/^          environment: //p' | head -n1)"
    caller_key_reference="$(printf '%s\n' "$caller_block" | sed -n 's/.*secrets\.\([^ }]*\).*/\1/p' | head -n1)"
    caller_client_reference="$(printf '%s\n' "$caller_block" | sed -n 's/.*vars\.\([^ }]*\).*/\1/p' | head -n1)"
    caller_slug_reference="$(printf '%s\n' "$caller_block" | sed -n 's/^          app_slug: .*vars\.\([^ }]*\).*/\1/p' | head -n1)"
    caller_api_reference="$(printf '%s\n' "$caller_block" | sed -n 's/^          github_api_url: //p' | head -n1)"
    caller_condition="$(printf '%s\n' "$caller_block" | sed -n 's/^    if: //p')"
    caller_client_id="client-$caller_client_reference"
    caller_app_slug="slug-$caller_slug_reference"
    caller_private_key="key-$caller_key_reference"
    caller_output="$preflight_tmp/$fixture_name.output"
    caller_calls="$preflight_tmp/$fixture_name.calls"
    [ "$caller_condition" = "$expected_condition" ] || {
        echo "unexpected maintenance caller condition in $workflow_name" >&2
        exit 1
    }
    [ "$caller_api_reference" = "\${{ inputs.github_host == 'github.com' && 'https://api.github.com' || format('https://{0}/api/v3', inputs.github_host) }}" ] || {
        echo "unexpected maintenance caller API wiring in $workflow_name" >&2
        exit 1
    }
    awk '
        /^      run: \|$/ { capture = 1; next }
        capture && /^        / { sub(/^        /, ""); print; next }
        capture { exit }
    ' "$credentials_action" > "$caller_fixture"
    chmod 700 "$caller_fixture"
    : > "$caller_calls"
    if CALLER_GH_CALLS="$caller_calls" PATH="$preflight_bin:$PATH" \
        GITHUB_ACTION_PATH="$repo_root/.github/actions/configure-provisioner-credentials" \
        REPOSITORY_INPUT="$repository_fixture" PROFILE_INPUT="$caller_profile" \
        ENVIRONMENT_INPUT="$caller_environment" CLIENT_ID_INPUT="$caller_client_id" \
        APP_SLUG_INPUT="$caller_app_slug" APP_PRIVATE_KEY_INPUT="$caller_private_key" \
        GH_TOKEN_INPUT="$provisioner_token_fixture" \
        MAINTENANCE_TOKEN_INPUT="$maintenance_token_fixture" \
        GITHUB_API_URL="$api_url_fixture" bash "$caller_fixture" > "$caller_output" 2>&1; then
        echo "missing maintenance installation was accepted by $workflow_name" >&2
        exit 1
    fi
    grep -Fq "cannot see $repository_fixture" "$caller_output"
    grep -Eq "${maintenance_token_fixture}.*${api_url_fixture}.*installation/repositories" "$caller_calls"
    grep -Fq "$caller_profile" "$caller_output" ||
        grep -Fq "$caller_profile" "$caller_calls"
    test "$caller_key_reference" != "$caller_client_reference"
    test "$caller_client_reference" != "$caller_slug_reference"
}

run_caller_preflight_fixture \
    "$repo_root/.github/workflows/create-repository.yml" create-caller \
    acme/create-caller-generated https://create.example/api/v3 \
    create-provisioner-token create-maintenance-token \
    "needs.create-repository.result == 'success' && needs.create-repository.outputs.provisioner_profile == 'e2e-provisioner'"
run_caller_preflight_fixture \
    "$repo_root/.github/workflows/terraform-create-repository.yml" terraform-caller \
    acme/terraform-caller-generated https://terraform.example/api/v3 \
    terraform-provisioner-token terraform-maintenance-token \
    "needs.terraform-create-repository.result == 'success' && needs.terraform-create-repository.outputs.provisioner_profile == 'e2e-provisioner'"
rm -rf "$preflight_tmp"

for workflow in create-repository.yml terraform-create-repository.yml; do
    workflow_path="$repo_root/.github/workflows/$workflow"
    assert_contains "e2e-maintenance-writer" "$workflow_path"
    assert_contains "e2e-maintenance-reviewer" "$workflow_path"
    assert_contains "e2e-maintenance" "$workflow_path"
    assert_contains "production-maintenance" "$workflow_path"
    assert_contains "BOOTSTRAP_MAINTENANCE_WRITER_APP_CLIENT_ID" "$workflow_path"
    assert_contains "BOOTSTRAP_MAINTENANCE_REVIEWER_APP_CLIENT_ID" "$workflow_path"
done

assert_contains "e2e-maintenance-writer" "$repo_root/scripts/github-setup/install-app-secrets.sh"
assert_contains "e2e-maintenance-reviewer" "$repo_root/scripts/github-setup/install-app-secrets.sh"
assert_contains "app_slug_file" "$repo_root/scripts/github-setup/install-app-secrets.sh"

for workflow in "$repo_root"/.github/workflows/*.yml; do
    resolver_calls=$(grep -cF 'uses: ./.github/actions/resolve-gh-token' "$workflow" || true)
    [ "$resolver_calls" -eq 0 ] && continue
    refresh_inputs=$(grep -cE '^          refresh_token_secret:' "$workflow" || true)
    [ "$resolver_calls" -eq "$refresh_inputs" ] || {
        echo "every resolve-gh-token caller must provide refresh_token_secret: $workflow" >&2
        exit 1
    }
done

for workflow in approve-automation-workflows.yml classify-maintenance-pr.yml cleanup-archived-e2e.yml delete-repo.yml dispatch-maintenance-e2e.yml merge-maintenance-pr.yml release-please.yml setup-existing-repository.yml test-local-setup-scripts.yml weekly-tooling-updates.yml; do
    workflow_path="$repo_root/.github/workflows/$workflow"
    assert_contains 'refresh_token_secret: ""' "$workflow_path"
done

assert_contains "provisioner_profile: e2e-provisioner" "$repo_root/.github/workflows/test-personal-app-e2e.yml"
assert_not_line '^      client_id:' "$repo_root/.github/workflows/test-personal-app-e2e.yml"
assert_not_contains "${legacy_prefix}" "$repo_root/.github/workflows/test-personal-app-e2e.yml"
assert_contains "BOOTSTRAP_E2E_PROVISIONER_APP_PRIVATE_KEY" "$repo_root/.github/workflows/test-personal-app-e2e.yml"
assert_contains "BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_SECRET" "$repo_root/.github/workflows/test-personal-app-e2e.yml"
assert_contains "BOOTSTRAP_E2E_PROVISIONER_APP_USER_REFRESH_TOKEN" "$repo_root/.github/workflows/test-personal-app-e2e.yml"

assert_contains "AUTH_MODE: \${{ steps.resolve-token.outputs.auth_mode }}" "$repo_root/.github/workflows/create-repository.yml"
assert_contains "set -euo pipefail" "$repo_root/.github/workflows/create-repository.yml"
assert_not_contains "echo \"repo_created=false\" >> \"\$GITHUB_OUTPUT\"" "$repo_root/.github/workflows/create-repository.yml"

for workflow in create-repository.yml terraform-create-repository.yml; do
    assert_contains "BOOTSTRAP_PRODUCTION_PROVISIONER_APP_USER_REFRESH_TOKEN:" "$repo_root/.github/workflows/$workflow"
    assert_contains "BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_SECRET:" "$repo_root/.github/workflows/$workflow"
    assert_contains "BOOTSTRAP_E2E_PROVISIONER_APP_USER_REFRESH_TOKEN:" "$repo_root/.github/workflows/$workflow"
    assert_contains "BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_SECRET:" "$repo_root/.github/workflows/$workflow"
    assert_contains "required: false" "$repo_root/.github/workflows/$workflow"
done

assert_contains "target_owner: \${{ steps.target.outputs.owner }}" "$repo_root/.github/workflows/delete-repo.yml"
assert_contains "repositories: \${{ steps.target.outputs.repository }}" "$repo_root/.github/workflows/delete-repo.yml"
assert_contains "bash ./scripts/github-setup/validate-app-auth.sh" "$resolver"
assert_contains "repositories: \${{ inputs.repo_name }}" "$repo_root/.github/workflows/setup-existing-repository.yml"
assert_contains "environment: e2e-testing" "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
assert_contains "repositories: \${{ github.event.repository.name }}" "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
assert_contains "permission_profile: e2e-dispatch" "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
assert_not_line '^      client_id:' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
assert_not_contains "app_client_secret: \${{ secrets.BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_SECRET }}" "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
assert_not_contains "app_user_refresh_token: \${{ secrets.BOOTSTRAP_E2E_PROVISIONER_APP_USER_REFRESH_TOKEN }}" "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
assert_contains "--field provisioner_profile=e2e-provisioner" "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
assert_not_contains "--field provisioner_profile=production-provisioner" "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
assert_not_contains 'BOOTSTRAP_PRODUCTION_PROVISIONER_APP' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
assert_contains "--field cleanup_on_failure=false" "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
assert_contains "app_user_refresh_token: \${{ secrets.BOOTSTRAP_E2E_PROVISIONER_APP_USER_REFRESH_TOKEN }}" "$repo_root/.github/workflows/test-repository-creation.yml"
assert_contains "app_client_secret: \${{ secrets.BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_SECRET }}" "$repo_root/.github/workflows/test-repository-creation.yml"
assert_contains "repositories: \${{ needs.create-test-repo.outputs.cleanup_repositories }}" "$repo_root/.github/workflows/test-repository-creation.yml"

if rg -n 'APP_CLIENT_SECRET|app_client_secret|APP_USER_REFRESH_TOKEN|app_user_refresh_token' \
    "$repo_root/templates/.github"; then
    echo "generated repositories must not contain provisioner client-secret or refresh-token material" >&2
    exit 1
fi

assert_contains "contents: write" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_not_contains "      workflows: write" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "pull-requests: write" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "issues: read" "$repo_root/.github/workflows/weekly-tooling-updates.yml"
assert_contains "inputs.permission_profile == 'weekly-tooling'" "$resolver"
assert_contains "permission-workflows:" "$resolver"
assert_contains "inputs.permission_profile == 'repository-creation' || inputs.permission_profile == 'repository-setup'" "$resolver"
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
assert_contains "ref: main" "$approval_workflow"
if grep -Fq 'A-Za-z0-9_-' "$repo_root/templates/.github/scripts/gh-common.sh"; then
    echo "GitHub owner validation must reject underscores" >&2
    exit 1
fi
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
