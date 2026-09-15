#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
profile_file="$repo_root/templates/.github/config/bootstrap-profile.json"
validator="$script_dir/validate-profile.sh"
workflow_helper="$repo_root/scripts/select-generated-workflows.sh"

command -v jq > /dev/null 2>&1 || {
    echo "jq is required to validate bootstrap profiles" >&2
    exit 1
}

[ -x "$validator" ] || {
    echo "profile validator is not executable: $validator" >&2
    exit 1
}

[ -x "$workflow_helper" ] || {
    echo "generated workflow helper is not executable: $workflow_helper" >&2
    exit 1
}

jq -e '.profiles.baseline.capabilities | contains(["lint-markdown", "lint-json", "lint-yaml", "lint-actions", "lint-shell", "lint-python", "lint-terraform", "lint-format", "lint-tests"])' "$profile_file" > /dev/null
jq -e '.bundles.planning.enabled_by_default == false' "$profile_file" > /dev/null
jq -e '[.capabilities[] | .classification] | all(. == "baseline" or . == "optional:planning" or . == "provider-specific")' "$profile_file" > /dev/null
jq -e 'all(.capabilities[]; .workflow as $workflow | (.owned_paths | index($workflow)) != null)' "$profile_file" > /dev/null
if jq -e '.assets[] | select(.path == "languages" or .path == "providers")' "$profile_file" > /dev/null; then
    echo "removed template helper trees must not be declared as generated profile assets" >&2
    exit 1
fi
[ -f "$repo_root/templates/.github/workflows/quality.yml" ]
[ -f "$repo_root/templates/.github/workflows/centralized-quality.yml" ]
[ -f "$repo_root/templates/centralized-actions-workflows/examples/consumer-quality.yml" ]
[ -f "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml" ]
[ -f "$repo_root/templates/centralized-actions-workflows/.github/actions/setup-lint-mise/action.yml" ]
[ -f "$repo_root/templates/centralized-actions-workflows/.github/actions/setup-lint-system/action.yml" ]
grep -q '^  workflow_call:' "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml"
if grep -Eq '^  (push|pull_request|workflow_dispatch):' "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml"; then
    echo "centralized seed quality workflow must not have repository event triggers" >&2
    exit 1
fi
grep -q '{{CENTRAL_REPOSITORY}}/.github/workflows/quality.yml@{{CENTRAL_REF}}' "$repo_root/templates/.github/workflows/centralized-quality.yml"
grep -qF "name: quality (\${{ matrix['environment-manager'] }})" "$repo_root/.github/workflows/test-quality-providers.yml"
if grep -Fq "tools/go.mod" "$repo_root/templates/.github/workflows/test-quality-providers.yml"; then
    echo "templated test-quality-providers.yml must not reference the bootstrap repository's own tools/go.mod: generated repositories do not have a tools/ directory" >&2
    exit 1
fi

# GitHub's labels endpoint requires both issues:write and pull-requests:write
# to label a pull request (issues:write alone 403s with "Resource not
# accessible by integration"); the templated workflow mints its own token
# directly instead of reusing resolve-gh-token's maintenance-labeling
# profile (which already requests both), so it must match that profile.
if grep -Fq 'permission-pull-requests: read' "$repo_root/templates/.github/workflows/classify-maintenance-pr.yml"; then
    echo "templated classify-maintenance-pr.yml must request pull-requests write, not read: labeling a pull request needs both issues:write and pull-requests:write" >&2
    exit 1
fi
grep -Fq 'permission-pull-requests: write' "$repo_root/templates/.github/workflows/classify-maintenance-pr.yml"
grep -q '^  workflow_dispatch:' "$repo_root/.github/workflows/coderabbit-dependabot-review.yml"
grep -q '^  workflow_dispatch:' "$repo_root/templates/.github/workflows/coderabbit-dependabot-review.yml"
if grep -q '^  pull_request_target:' "$repo_root/.github/workflows/coderabbit-dependabot-review.yml"; then
    echo "CodeRabbit review workflow must be explicit opt-in" >&2
    exit 1
fi
if grep -q '^  pull_request_target:' "$repo_root/templates/.github/workflows/coderabbit-dependabot-review.yml"; then
    echo "templated CodeRabbit review workflow must be explicit opt-in" >&2
    exit 1
fi
grep -q '^      pr_number:' "$repo_root/.github/workflows/coderabbit-dependabot-review.yml"
grep -q '^      pr_number:' "$repo_root/templates/.github/workflows/coderabbit-dependabot-review.yml"
for coderabbit_workflow in \
    "$repo_root/.github/workflows/coderabbit-dependabot-review.yml" \
    "$repo_root/templates/.github/workflows/coderabbit-dependabot-review.yml"; do
    grep -q "if \[ \"\$pr_state\" != OPEN \]" "$coderabbit_workflow"
    grep -q 'gh api --paginate' "$coderabbit_workflow"
done
grep -Eq '^  issues: write( +#.*)?$' "$repo_root/.github/workflows/coderabbit-dependabot-review.yml"
grep -Eq '^  issues: write( +#.*)?$' "$repo_root/templates/.github/workflows/coderabbit-dependabot-review.yml"
for claude_workflow in \
    "$repo_root/.github/workflows/ai-code-review.yml" \
    "$repo_root/templates/.github/workflows/ai-code-review.yml"; do
    if grep -Eq 'ANTHROPIC_API_KEY|anthropic_api_key:' "$claude_workflow"; then
        echo "Claude workflow must not use a static Anthropic API key: $claude_workflow" >&2
        exit 1
    fi
    grep -q '^  issue_comment:' "$claude_workflow"
    if grep -q '^  pull_request:' "$claude_workflow"; then
        echo "Claude workflow must be comment-triggered to remain explicit opt-in: $claude_workflow" >&2
        exit 1
    fi
    grep -q 'id-token: write' "$claude_workflow"
    grep -q 'anthropic_federation_rule_id:' "$claude_workflow"
    grep -q 'anthropic_organization_id:' "$claude_workflow"
done
grep -q 'coderabbit-dependabot-review.yml' "$repo_root/README.md"
templated_labels_file="$repo_root/templates/.github/config/labels-default.json"
[ -f "$templated_labels_file" ] || {
    echo "missing templated labels file: $templated_labels_file" >&2
    exit 1
}
while IFS= read -r dependabot_label; do
    jq -e --arg name "$dependabot_label" '.labels[] | select(.name == $name)' "$templated_labels_file" > /dev/null || {
        echo "templated labels file is missing a label dependabot.yml requires: $dependabot_label" >&2
        exit 1
    }
done < <(grep -A2 '^    labels:' "$repo_root/templates/.github/dependabot.yml" | grep -o '"[^"]*"' | tr -d '"' | sort -u)
for creation_workflow in \
    "$repo_root/.github/workflows/create-repository.yml" \
    "$repo_root/.github/workflows/terraform-create-repository.yml"; do
    grep -q 'uses: ./.github/actions/apply-labels' "$creation_workflow"
    grep -q 'cp templates/AGENTS.md new-repo/AGENTS.md' "$creation_workflow"
    grep -q 'cp WORKTREES.md new-repo/' "$creation_workflow"
    grep -qF "tr -d '[:space:]'" "$creation_workflow"
    grep -q 'DELIVERY_MODE.*CENTRAL_REPOSITORY.*CENTRAL_REF' "$creation_workflow"
    grep -q '^      app_owner:' "$creation_workflow"
    grep -q '^      allowed_repo_owners:' "$creation_workflow"
    grep -q '^      require_cleanup_approval:' "$creation_workflow"
    grep -q '^      optional_features:' "$creation_workflow"
    grep -q 'OWNER/REPOSITORY@REF' "$creation_workflow"
    grep -q "OPTIONAL_FEATURES=\"\${{ inputs.optional_features || 'github-planning' }}\"" "$creation_workflow"
    grep -q 'maintenance' "$creation_workflow"
    grep -q 'e2e' "$creation_workflow"
    grep -q 'scripts/select-generated-workflows.sh' "$creation_workflow"
    grep -q 'select new-repo' "$creation_workflow"
    grep -q 'bind-e2e new-repo' "$creation_workflow"
    if awk '/name: Remove unselected workflows/,/select-generated-workflows.sh select new-repo/' \
        "$creation_workflow" | grep -q 'cd new-repo'; then
        echo "Remove unselected workflows step must not cd into new-repo before calling the repo-root-relative select-generated-workflows.sh script: $creation_workflow" >&2
        exit 1
    fi
    grep -qF "group: provisioner-token-\${{ inputs.provisioner_profile || 'production-provisioner' }}" "$creation_workflow"
    if ! awk '/^jobs:/{exit} /^concurrency:/{found=1} END{exit !found}' "$creation_workflow"; then
        echo "provisioner-token concurrency must be a workflow-level group, not job-level: $creation_workflow" >&2
        exit 1
    fi
    grep -qF "cancel-in-progress: false" "$creation_workflow"
    if ! awk '/name: Wait for repository initialization/{f=1} f && /name: Clone new repository/{exit} f && /name: Configure E2E maintenance Writer credentials before push/{found=1} END{exit !found}' \
        "$creation_workflow"; then
        echo "E2E Writer credentials must be provisioned between repository creation and the initial push: $creation_workflow" >&2
        exit 1
    fi
    if ! awk '/name: Wait for repository initialization/{f=1} f && /name: Clone new repository/{exit} f && /name: Configure E2E maintenance Reviewer credentials before push/{found=1} END{exit !found}' \
        "$creation_workflow"; then
        echo "E2E Reviewer credentials must be provisioned between repository creation and the initial push: $creation_workflow" >&2
        exit 1
    fi
    if grep -q 'KEEP_FILES=' "$creation_workflow"; then
        echo "workflow bundle mapping must live in the shared helper: $creation_workflow" >&2
        exit 1
    fi
done
grep -q 'production' "$workflow_helper"
grep -q 'e2e' "$workflow_helper"
maintenance_templates=(
    approve-automation-workflows.yml
    classify-maintenance-pr.yml
    maintenance-safety.yml
    merge-maintenance-pr.yml
    release-please.yml
)
for maintenance_workflow in "${maintenance_templates[@]}"; do
    template_workflow="$repo_root/templates/.github/workflows/$maintenance_workflow"
    grep -q '^    environment: production$' "$template_workflow"
done
for production_reference in \
    'BOOTSTRAP_PRODUCTION_WRITER_APP_CLIENT_ID' \
    'BOOTSTRAP_PRODUCTION_WRITER_APP_PRIVATE_KEY' \
    'BOOTSTRAP_PRODUCTION_WRITER_APP_SLUG' \
    'BOOTSTRAP_PRODUCTION_REVIEWER_APP_CLIENT_ID' \
    'BOOTSTRAP_PRODUCTION_REVIEWER_APP_PRIVATE_KEY' \
    'BOOTSTRAP_PRODUCTION_REVIEWER_APP_SLUG'; do
    template_reference_count="$({ grep -Roh "$production_reference" \
        "$repo_root/templates/.github/workflows" || true; } | wc -l | tr -d ' ')"
    [ "$template_reference_count" -gt 0 ] || {
        echo "missing production maintenance credential reference: $production_reference" >&2
        exit 1
    }
done
for production_workflow in classify-maintenance-pr.yml maintenance-safety.yml \
    approve-automation-workflows.yml merge-maintenance-pr.yml release-please.yml; do
    grep -q 'environment: production' \
        "$repo_root/templates/.github/workflows/$production_workflow"
    if grep -Eq 'BOOTSTRAP_E2E_(WRITER|REVIEWER|FIXTURE|PROVISIONER)_|e2e-(writer|reviewer|fixture|provisioner)' \
        "$repo_root/templates/.github/workflows/$production_workflow"; then
        echo "production maintenance workflow must not contain E2E maintenance identity: $production_workflow" >&2
        exit 1
    fi
done
for maintenance_workflow in classify-maintenance-pr.yml maintenance-safety.yml \
    approve-automation-workflows.yml merge-maintenance-pr.yml; do
    test -f "$repo_root/templates/.github/workflows/$maintenance_workflow"
    grep -q "$maintenance_workflow" "$workflow_helper"
done
grep -q 'release-please.yml' "$workflow_helper"
grep -q 'git-cliff-release.yml' "$workflow_helper"
run_workflow_fixture() {
    local workflow_input="$1" release_tool="$2" fixture
    fixture="$(mktemp -d)"
    mkdir -p "$fixture/.github/workflows"
    for workflow in commit-policy.yml quality.yml codeql.yml test-quality-providers.yml ai-code-review.yml \
        classify-maintenance-pr.yml maintenance-safety.yml \
        approve-automation-workflows.yml merge-maintenance-pr.yml \
        release-please.yml git-cliff-release.yml unrelated.yml; do
        template_workflow="$repo_root/templates/.github/workflows/$workflow"
        if [ -f "$template_workflow" ]; then
            cp "$template_workflow" "$fixture/.github/workflows/$workflow"
        else
            : > "$fixture/.github/workflows/$workflow"
        fi
    done
    "$workflow_helper" select "$fixture" "$workflow_input" "$release_tool" > /dev/null
    printf '%s\n' "$fixture"
}

standard_fixture="$(run_workflow_fixture ' quality, maintenance ' release-please)"
for retained in commit-policy.yml quality.yml codeql.yml test-quality-providers.yml classify-maintenance-pr.yml \
    maintenance-safety.yml approve-automation-workflows.yml merge-maintenance-pr.yml \
    release-please.yml; do
    test -f "$standard_fixture/.github/workflows/$retained"
done
for maintenance_workflow in "${maintenance_templates[@]}" release-please.yml; do
    generated_workflow="$standard_fixture/.github/workflows/$maintenance_workflow"
    grep -q 'environment: production' "$generated_workflow"
    for production_reference in \
        BOOTSTRAP_PRODUCTION_WRITER_APP_CLIENT_ID \
        BOOTSTRAP_PRODUCTION_WRITER_APP_PRIVATE_KEY \
        BOOTSTRAP_PRODUCTION_WRITER_APP_SLUG \
        BOOTSTRAP_PRODUCTION_REVIEWER_APP_CLIENT_ID \
        BOOTSTRAP_PRODUCTION_REVIEWER_APP_PRIVATE_KEY \
        BOOTSTRAP_PRODUCTION_REVIEWER_APP_SLUG; do
        if grep -q "$production_reference" "$repo_root/templates/.github/workflows/$maintenance_workflow"; then
            grep -q "$production_reference" "$generated_workflow"
        fi
    done
    if grep -Eq 'BOOTSTRAP_E2E_(WRITER|REVIEWER|FIXTURE|PROVISIONER)_|e2e-(writer|reviewer|fixture|provisioner)' \
        "$generated_workflow"; then
        echo "production generated workflow retained E2E maintenance material: $maintenance_workflow" >&2
        exit 1
    fi
done
e2e_maintenance_workflows=("${maintenance_templates[@]}" release-please.yml)
E2E_COPILOT_REVIEWER_LOGIN='copilot-pull-request-reviewer[bot]' \
    "$workflow_helper" bind-e2e "$standard_fixture" ' quality, maintenance ' release-please
for maintenance_workflow in "${e2e_maintenance_workflows[@]}"; do
    generated_workflow="$standard_fixture/.github/workflows/$maintenance_workflow"
    if ! grep -qx '    environment: e2e' "$generated_workflow"; then
        echo "E2E maintenance workflow is missing its E2E Environment: $maintenance_workflow" >&2
        exit 1
    fi
    for e2e_reference in \
        'BOOTSTRAP_E2E_WRITER_APP_CLIENT_ID' \
        'BOOTSTRAP_E2E_WRITER_APP_PRIVATE_KEY' \
        'BOOTSTRAP_E2E_WRITER_APP_SLUG' \
        'BOOTSTRAP_E2E_REVIEWER_APP_CLIENT_ID' \
        'BOOTSTRAP_E2E_REVIEWER_APP_PRIVATE_KEY' \
        'BOOTSTRAP_E2E_REVIEWER_APP_SLUG'; do
        production_reference="${e2e_reference/BOOTSTRAP_E2E_/BOOTSTRAP_}"
        if grep -q "$production_reference" \
            "$repo_root/templates/.github/workflows/$maintenance_workflow"; then
            grep -q "$e2e_reference" "$generated_workflow" || {
                echo "E2E maintenance workflow is missing credential reference $e2e_reference: $maintenance_workflow" >&2
                exit 1
            }
        fi
    done
    for production_reference in \
        'BOOTSTRAP_PRODUCTION_WRITER_APP_CLIENT_ID' \
        'BOOTSTRAP_PRODUCTION_WRITER_APP_PRIVATE_KEY' \
        'BOOTSTRAP_PRODUCTION_WRITER_APP_SLUG' \
        'BOOTSTRAP_PRODUCTION_REVIEWER_APP_CLIENT_ID' \
        'BOOTSTRAP_PRODUCTION_REVIEWER_APP_PRIVATE_KEY' \
        'BOOTSTRAP_PRODUCTION_REVIEWER_APP_SLUG'; do
        grep -Fq "$production_reference" "$generated_workflow" && {
            echo "E2E maintenance workflow retained production credential reference $production_reference: $maintenance_workflow" >&2
            exit 1
        }
    done
done
for removed in ai-code-review.yml git-cliff-release.yml unrelated.yml; do
    test ! -e "$standard_fixture/.github/workflows/$removed"
done
rm -rf "$standard_fixture"

terraform_fixture="$(run_workflow_fixture maintenance git-cliff)"
for retained in commit-policy.yml classify-maintenance-pr.yml maintenance-safety.yml \
    approve-automation-workflows.yml merge-maintenance-pr.yml git-cliff-release.yml; do
    test -f "$terraform_fixture/.github/workflows/$retained"
done
for removed in ai-code-review.yml release-please.yml unrelated.yml; do
    test ! -e "$terraform_fixture/.github/workflows/$removed"
done
rm -rf "$terraform_fixture"

binding_fixture="$(mktemp -d)"
mkdir -p "$binding_fixture/.github/workflows"
for maintenance_workflow in classify-maintenance-pr.yml maintenance-safety.yml \
    approve-automation-workflows.yml merge-maintenance-pr.yml release-please.yml; do
    if [ "$maintenance_workflow" = release-please.yml ]; then
        : > "$binding_fixture/.github/workflows/$maintenance_workflow"
    else
        printf '    environment: production\n' > \
            "$binding_fixture/.github/workflows/$maintenance_workflow"
    fi
done
E2E_COPILOT_REVIEWER_LOGIN='copilot-pull-request-reviewer[bot]' \
    "$workflow_helper" bind-e2e "$binding_fixture" maintenance release-please
grep -qx '    environment: e2e' \
    "$binding_fixture/.github/workflows/maintenance-safety.yml"
printf '    environment: production\n' > \
    "$binding_fixture/.github/workflows/maintenance-safety.yml"
for maintenance_workflow in classify-maintenance-pr.yml maintenance-safety.yml \
    approve-automation-workflows.yml merge-maintenance-pr.yml release-please.yml; do
    printf '    environment: production\n' > \
        "$binding_fixture/.github/workflows/$maintenance_workflow"
done
printf '    environment: unexpected-environment\n' > \
    "$binding_fixture/.github/workflows/maintenance-safety.yml"
if E2E_COPILOT_REVIEWER_LOGIN='copilot-pull-request-reviewer[bot]' \
    "$workflow_helper" bind-e2e "$binding_fixture" maintenance release-please; then
    echo "E2E binding unexpectedly accepted a missing expected substitution" >&2
    exit 1
fi
rm -rf "$binding_fixture"
if grep -Eq '^    if: .*matrix\.' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"; then
    echo "E2E workflow must not use matrix context in a job-level condition" >&2
    exit 1
fi
grep -q '^      - name: Select requested creation workflow$' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
grep -q '^      head_sha:' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
grep -q '^    name: .*matrix.creation_workflow.*matrix.delivery.*matrix.provider' \
    "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
grep -q '@ .*inputs.head_sha' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
grep -q 'validate-generated-e2e-head.sh' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
grep -q 'git/refs' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
grep -q 'DISPATCH_REF' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
grep -q 'requested_head_sha=' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
grep -q -- '--field workflows=quality,maintenance' \
    "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
for runtime_input in python_version node_version go_version java_version; do
    runtime_env="$(printf '%s' "$runtime_input" | tr '[:lower:]' '[:upper:]')"
    grep -q -- "--field ${runtime_input}=\"\$${runtime_env}\"" \
        "$repo_root/.github/workflows/test-repository-creation.yml"
done
grep -q "REQUESTED_DELIVERY: \${{ inputs.delivery }}" "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
grep -q -- '--field provisioner_profile=e2e-provisioner' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
if grep -q -- '--field client_id=' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"; then
    echo "generated E2E must not pass the removed client_id input" >&2
    exit 1
fi
grep -q -- "--field app_owner=\"\$APP_OWNER\"" "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
grep -q -- "--field allowed_repo_owners=\"\$OWNER\"" "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
grep -q -- '--json status,conclusion,url' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
if grep -q '^  actions: write$' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"; then
    echo "E2E workflow must not grant actions: write to the default token" >&2
    exit 1
fi
if grep -q 'QUALITY_STARTED_AT' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"; then
    echo "E2E quality-run correlation must not use timestamp string comparisons" >&2
    exit 1
fi
grep -q '^    name: quality$' "$repo_root/templates/.github/workflows/centralized-quality.yml"
grep -q '^    name: quality$' "$repo_root/templates/centralized-actions-workflows/examples/consumer-quality.yml"
grep -q "capability=.*sed 's/^ \*//;s/ \*$//'" \
    "$repo_root/templates/centralized-actions-workflows/.github/actions/quality/action.yml"
if grep -q 'xargs' "$repo_root/templates/centralized-actions-workflows/.github/actions/quality/action.yml"; then
    echo "centralized capability validation must not trim with xargs" >&2
    exit 1
fi
grep -q 'LINT_MODE=check provider_run uv run pre-commit' "$repo_root/templates/.github/actions/quality/run-quality/action.yml"
grep -q 'LINT_MODE=check provider_run uv run pre-commit' "$repo_root/templates/.github/actions/quality/run-capability/action.yml"
for yaml_ignore_file in \
    "$repo_root/templates/.github/linters/.yaml-lint-ignore" \
    "$repo_root/templates/centralized-actions-workflows/.github/linters/.yaml-lint-ignore"; do
    test -f "$yaml_ignore_file"
    grep -Fxq 'node_modules' "$yaml_ignore_file"
    grep -Fxq '.venv' "$yaml_ignore_file"
    grep -Fxq '.git' "$yaml_ignore_file"
done
for markdown_ignore_file in \
    "$repo_root/templates/.github/linters/.markdownlintignore" \
    "$repo_root/templates/centralized-actions-workflows/.github/linters/.markdownlintignore"; do
    test -f "$markdown_ignore_file"
    grep -Fxq 'CHANGELOG.md' "$markdown_ignore_file"
    grep -Fxq 'node_modules' "$markdown_ignore_file"
    grep -Fxq '.venv' "$markdown_ignore_file"
    grep -Fxq '.git' "$markdown_ignore_file"
done
for shell_ignore_file in \
    "$repo_root/templates/.github/linters/.shell-lint-ignore" \
    "$repo_root/templates/centralized-actions-workflows/.github/linters/.shell-lint-ignore"; do
    test -f "$shell_ignore_file"
    grep -Fxq 'node_modules' "$shell_ignore_file"
    grep -Fxq '.venv' "$shell_ignore_file"
    grep -Fxq '.git' "$shell_ignore_file"
done
for yaml_runner in \
    "$repo_root/templates/scripts/lint-yaml.sh" \
    "$repo_root/templates/centralized-actions-workflows/scripts/lint-yaml.sh"; do
    test -x "$yaml_runner"
    grep -Fq '.yaml-lint-ignore' "$yaml_runner"
done
for shell_runner in \
    "$repo_root/templates/scripts/lint-shell.sh" \
    "$repo_root/templates/centralized-actions-workflows/scripts/lint-shell.sh"; do
    test -x "$shell_runner"
    grep -Fq '.shell-lint-ignore' "$shell_runner"
done
grep -Fq 'scripts/lint-yaml.sh' "$repo_root/templates/.github/actions/quality/run-quality/action.yml"
grep -Fq 'scripts/lint-yaml.sh' "$repo_root/templates/.github/actions/quality/run-capability/action.yml"
grep -Fq 'scripts/lint-yaml.sh' "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml"
grep -Fq 'scripts/lint-shell.sh' "$repo_root/templates/.github/actions/quality/run-quality/action.yml"
grep -Fq 'scripts/lint-shell.sh' "$repo_root/templates/.github/actions/quality/run-capability/action.yml"
grep -Fq 'scripts/lint-shell.sh' "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml"
grep -Fq -- "--ignore-path \"\$WORKING_DIRECTORY/.github/linters/.markdownlintignore\"" \
    "$repo_root/templates/.github/actions/quality/run-quality/action.yml"
grep -Fq -- '--ignore-path .github/linters/.markdownlintignore' \
    "$repo_root/templates/.github/actions/quality/run-capability/action.yml" \
    "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml"
grep -Fq -- '--ignore-path .github/linters/.markdownlintignore' \
    "$repo_root/templates/languages/agnostic/pre-commit-snippets/base.tmpl"
if grep -Eq 'yamllint.*--ignore|yamllint --config-file' \
    "$repo_root/templates/.github/actions/quality/run-quality/action.yml" \
    "$repo_root/templates/.github/actions/quality/run-capability/action.yml" \
    "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml"; then
    echo "YAML exclusions must be configured in .yaml-lint-ignore" >&2
    exit 1
fi
grep -qF 'provider_run python3 -c "import pytest"' "$repo_root/templates/.github/actions/quality/run-quality/action.yml"
grep -qF "provider_run uv run python3 -m pytest" "$repo_root/templates/.github/actions/quality/run-quality/action.yml"
grep -qF 'provider_run python3 -c "import pytest"' "$repo_root/templates/.github/actions/quality/run-capability/action.yml"
grep -qF "provider_run uv run python3 -m pytest" "$repo_root/templates/.github/actions/quality/run-capability/action.yml"
grep -qF 'provider_run python3 -c "import pytest"' "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml"
grep -qF "provider_run uv run python3 -m pytest" "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml"
grep -qF "(cd \"\$WORKING_DIRECTORY\" && LINT_MODE=check provider_run uv run pre-commit run --all-files --color=always)" \
    "$repo_root/templates/.github/actions/quality/run-quality/action.yml"
grep -qF "WORKING_DIRECTORY=\"\$PWD/\$WORKING_DIRECTORY\"" "$repo_root/templates/.github/actions/quality/run-capability/action.yml"
grep -q 'No Terraform files found; skipping lint-terraform' "$repo_root/templates/.github/actions/quality/run-quality/action.yml"
grep -q 'No Terraform files found; skipping lint-terraform' "$repo_root/templates/.github/actions/quality/run-capability/action.yml"
grep -q 'No Terraform files found; skipping lint-terraform' "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml"
for terraform_quality_file in \
    "$repo_root/templates/.github/actions/quality/run-quality/action.yml" \
    "$repo_root/templates/.github/actions/quality/run-capability/action.yml" \
    "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml"; do
    grep -q 'terraform_dir=' "$terraform_quality_file"
    grep -q 'terraform.*init -backend=false' "$terraform_quality_file"
    grep -q -- "-chdir=\"\$terraform_dir\" validate" "$terraform_quality_file"
done
for json_quality_file in \
    "$repo_root/templates/.github/actions/quality/run-quality/action.yml" \
    "$repo_root/templates/.github/actions/quality/run-capability/action.yml" \
    "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml"; do
    grep -q 'provider_run bash -c' "$json_quality_file"
    grep -Eq -- "-path ['\"]\\./\\.git['\"] -prune -o -path ['\"]\\./node_modules['\"] -prune -o" "$json_quality_file"
    grep -Fq -- '-type f -name' "$json_quality_file"
    grep -Fq -- '-exec jq empty {} +' "$json_quality_file"
    if grep -Eq 'while .*provider_run jq empty' "$json_quality_file"; then
        echo "lint-json must enter the provider once per capability: $json_quality_file" >&2
        exit 1
    fi
done
grep -Fq -- '-type f -name \"*.json\" -exec jq empty {} +' \
    "$repo_root/templates/.github/actions/quality/run-quality/action.yml"
grep -Fq -- '-type f -name \"*.json\" -exec jq empty {} +' \
    "$repo_root/templates/.github/actions/quality/run-capability/action.yml"
grep -q 'zizmor==1.30.0' "$repo_root/pyproject.toml"
grep -q '\- uv=' "$repo_root/environment.yml"
grep -q 'uv = "' "$repo_root/mise.toml"
grep -q 'actionlint=1.7.12' "$repo_root/environment.yml"
grep -q 'actionlint = "1.7.12"' "$repo_root/mise.toml"
for setup_action in \
    "$repo_root/.github/actions/setup-lint-system/action.yml" \
    "$repo_root/templates/.github/actions/setup-lint-system/action.yml" \
    "$repo_root/templates/centralized-actions-workflows/.github/actions/setup-lint-system/action.yml"; do
    grep -q 'actionlint@v1.7.12' "$setup_action"
    grep -q 'cache: false' "$setup_action"
    grep -q "mkdir -p \"\\\$HOME/.local/bin\"" "$setup_action"
    grep -q 'setup-terraform' "$setup_action"
    grep -q 'astral-sh/setup-uv@' "$setup_action"
    grep -q 'uv sync --locked' "$setup_action"
done
for rendered_quality_file in \
    "$repo_root/templates/.github/workflows/quality.yml" \
    "$repo_root/templates/.github/actions/quality/run-quality/action.yml" \
    "$repo_root/templates/.github/actions/setup-lint-system/action.yml"; do
    if ! awk 'length($0) > 160 { exit 1 }' "$rendered_quality_file"; then
        echo "rendered quality file exceeds the 160-column contract: $rendered_quality_file" >&2
        exit 1
    fi
done
grep -q "github.event_name == 'workflow_call' && inputs.capabilities" \
    "$repo_root/templates/.github/workflows/quality.yml"
grep -q "github.event_name == 'workflow_call' && inputs\['environment-manager'\]" \
    "$repo_root/templates/.github/workflows/quality.yml"
grep -q "if: (github.event_name == 'workflow_call' && inputs\['environment-manager'\]" \
    "$repo_root/templates/.github/workflows/quality.yml"
grep -q "ENV_MANAGER=\"\\\$ENVIRONMENT_MANAGER\" make install" \
    "$repo_root/templates/.github/workflows/quality.yml"
grep -q "ENV_MANAGER=\"\\\$ENVIRONMENT_MANAGER\" make install" \
    "$repo_root/templates/.github/workflows/quality-capability.yml"
grep -q "ENV_MANAGER=\"\\\$ENVIRONMENT_MANAGER\" make install" \
    "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml"

# test-quality-providers.yml must be baked to the repository's own single
# selected provider (mirroring quality.yml's {{ENV_MANAGER}} substitution)
# instead of matrixing over providers/languages the repository was never
# created with -- a repository only ever has one provider's config present.
if grep -q "strategy:" "$repo_root/templates/.github/workflows/test-quality-providers.yml"; then
    echo "templated test-quality-providers.yml must not matrix over providers the repository lacks config for" >&2
    exit 1
fi
grep -q '{{ENV_MANAGER}}' "$repo_root/templates/.github/workflows/test-quality-providers.yml"
for workflow in create-repository.yml terraform-create-repository.yml; do
    grep -q '.github/workflows/test-quality-providers.yml' "$repo_root/.github/workflows/$workflow"
done

if grep -R -q 'package-ecosystem: "poetry"' "$repo_root/templates"; then
    echo "Dependabot templates must not use the unsupported poetry ecosystem" >&2
    exit 1
fi

# No template ever produces a Dockerfile, *.tf file, Chart.yaml, go.mod,
# build.gradle, pom.xml, Cargo.toml, composer.json, Gemfile, or *.csproj, so
# those Dependabot ecosystems always fail with dependency_file_not_found;
# only github-actions and uv (root tooling, present in every repository) and
# npm (present for mise/system providers) can ever find a manifest to update.
dead_dependabot_ecosystems=(docker maven gradle cargo composer bundler nuget gomod terraform helm)
for ecosystem in "${dead_dependabot_ecosystems[@]}"; do
    if grep -Fq "package-ecosystem: \"$ecosystem\"" "$repo_root/templates/.github/dependabot.yml"; then
        echo "templated dependabot.yml declares the '$ecosystem' ecosystem, which no template ever produces a manifest for" >&2
        exit 1
    fi
done

# npm has no manifest for micromamba-provisioned repositories (they use conda
# packages, not a root package.json); confirm the fix removes that entry.
configure_dependabot_action="$repo_root/.github/actions/configure-dependabot/action.yml"
configure_dependabot_script="$repo_root/.github/scripts/configure-dependabot.py"
[ -f "$configure_dependabot_action" ] || {
    echo "missing configure-dependabot action: $configure_dependabot_action" >&2
    exit 1
}
[ -f "$configure_dependabot_script" ] || {
    echo "missing configure-dependabot script: $configure_dependabot_script" >&2
    exit 1
}
for workflow in create-repository.yml terraform-create-repository.yml; do
    grep -q './.github/actions/configure-dependabot' "$repo_root/.github/workflows/$workflow"
done
dependabot_test_dir="$(mktemp -d)"
mkdir -p "$dependabot_test_dir/.github"
cp "$repo_root/templates/.github/dependabot.yml" "$dependabot_test_dir/.github/dependabot.yml"
(cd "$dependabot_test_dir" && ENV_MANAGER=micromamba python3 "$configure_dependabot_script")
if grep -Fq 'package-ecosystem: "npm"' "$dependabot_test_dir/.github/dependabot.yml"; then
    echo "configure-dependabot.py did not remove npm for env_manager=micromamba" >&2
    exit 1
fi
cp "$repo_root/templates/.github/dependabot.yml" "$dependabot_test_dir/.github/dependabot.yml"
(cd "$dependabot_test_dir" && ENV_MANAGER=mise python3 "$configure_dependabot_script")
grep -Fq 'package-ecosystem: "npm"' "$dependabot_test_dir/.github/dependabot.yml" || {
    echo "configure-dependabot.py incorrectly removed npm for env_manager=mise" >&2
    exit 1
}
rm -rf "$dependabot_test_dir"
if grep -q 'shellcheck' \
    "$repo_root/templates/.github/actions/quality/run-quality/action.yml" \
    "$repo_root/templates/.github/actions/quality/run-capability/action.yml" \
    "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml"; then
    echo "Shell exclusions and invocation must be configured in lint-shell.sh" >&2
    exit 1
fi
for provider_file in "$repo_root"/templates/languages/*/providers/micromamba/environment.yml; do
    grep -q 'actionlint=1.7.12' "$provider_file"
    grep -q '\- uv=' "$provider_file"
done
for provider_file in "$repo_root"/templates/languages/*/providers/mise/mise.toml; do
    grep -q 'actionlint = "1.7.12"' "$provider_file"
    grep -q 'uv = "' "$provider_file"
done
for lang_dir in "$repo_root"/templates/languages/*/; do
    grep -q 'zizmor==1.30.0' "$lang_dir/pyproject.toml"
done
for provider_file in "$repo_root"/templates/languages/*/providers/micromamba/environment.yml; do
    grep -q 'terraform' "$provider_file"
done
for provider_makefile in "$repo_root"/templates/languages/*/providers/micromamba/Makefile; do
    grep -q "\$(MICROMAMBA) create -y -n \$(MAMBA_ENV) -f \$(MAMBA_SPEC)" "$provider_makefile"
done
if jq -e '.profiles.baseline.bundles | index("planning")' "$profile_file" > /dev/null; then
    echo "planning bundle unexpectedly enabled in baseline profile" >&2
    exit 1
fi

"$validator" --profile-file "$profile_file" --profile baseline --delivery-mode embedded
"$validator" --profile-file "$profile_file" --profile baseline --delivery-mode embedded

temp_file="$(mktemp)"
ruleset_test_root="$(mktemp -d)"
trap 'rm -f "$temp_file"; rm -rf "$ruleset_test_root"' EXIT
jq '.delivery_modes.centralized.repository = ""' "$profile_file" > "$temp_file"
if "$validator" --profile-file "$temp_file" --profile baseline --delivery-mode centralized > /dev/null 2>&1; then
    echo "centralized profile without repository unexpectedly passed" >&2
    exit 1
fi

jq '.delivery_modes.centralized.repository = "test-owner/test-workflows" | .delivery_modes.centralized.ref = "v1.0.0"' "$profile_file" > "$temp_file"
"$validator" --profile-file "$temp_file" --profile baseline --delivery-mode centralized

missing_value_output="$("$validator" --profile-file 2>&1 || true)"
if ! grep -q "requires a value" <<< "$missing_value_output"; then
    echo "missing option value did not produce a clear validation error" >&2
    exit 1
fi

mkdir -p "$ruleset_test_root/.github/workflows"
printf '%s\n' 'name: quality' > "$ruleset_test_root/.github/workflows/quality.yml"
printf '%s\n' 'name: Signed-off-by trailers' > "$ruleset_test_root/.github/workflows/commit-policy.yml"
invalid_ruleset_profile_output="$(
    "$repo_root/scripts/github-setup/setup-ruleset.sh" \
        --owner test-owner \
        --repo test-repo \
        --ruleset-file "$ruleset_test_root/missing-ruleset.json" \
        --profile-file "$profile_file" \
        --profile unknown \
        --installed-root "$ruleset_test_root" 2>&1 || true
)"
if ! grep -q "invalid profile" <<< "$invalid_ruleset_profile_output"; then
    echo "invalid profile did not fail before ruleset derivation" >&2
    exit 1
fi
grep -q -- "derive checks from validated workflow files under" \
    "$repo_root/scripts/github-setup/setup-ruleset.sh"
grep -q -- "--installed-root" "$repo_root/scripts/github-setup/setup-ruleset.sh"
grep -q -- ".github/workflows/commit-policy.yml" \
    "$repo_root/scripts/github-setup/setup-ruleset.sh"
if grep -q -- ".github/workflows/signed-off-by.yml" \
    "$repo_root/scripts/github-setup/setup-ruleset.sh"; then
    echo "ruleset setup must use the commit-policy workflow" >&2
    exit 1
fi

jq '.capabilities[0].classification = "optional:planning"' "$profile_file" > "$temp_file"
"$validator" --profile-file "$temp_file" --profile baseline --delivery-mode embedded

jq '.capabilities[0].classification = "optional:unknown"' "$profile_file" > "$temp_file"
if "$validator" --profile-file "$temp_file" --profile baseline --delivery-mode embedded > /dev/null 2>&1; then
    echo "profile with unknown optional classification unexpectedly passed" >&2
    exit 1
fi

jq '.profiles.baseline.capabilities[0] = "unknown-capability"' "$profile_file" > "$temp_file"
if "$validator" --profile-file "$temp_file" --profile baseline --delivery-mode embedded > /dev/null 2>&1; then
    echo "profile with unknown capability unexpectedly passed" >&2
    exit 1
fi

jq '.profiles.baseline.bundles = ["unknown-bundle"]' "$profile_file" > "$temp_file"
if "$validator" --profile-file "$temp_file" --profile baseline --delivery-mode embedded > /dev/null 2>&1; then
    echo "profile with unknown bundle unexpectedly passed" >&2
    exit 1
fi

jq '.capabilities[0].owned_paths = [123]' "$profile_file" > "$temp_file"
if "$validator" --profile-file "$temp_file" --profile baseline --delivery-mode embedded > /dev/null 2>&1; then
    echo "profile with non-string owned path unexpectedly passed" >&2
    exit 1
fi

jq '.capabilities[0].providers = [{}]' "$profile_file" > "$temp_file"
if "$validator" --profile-file "$temp_file" --profile baseline --delivery-mode embedded > /dev/null 2>&1; then
    echo "profile with non-string provider unexpectedly passed" >&2
    exit 1
fi

jq '.bundles.planning.assets = [false]' "$profile_file" > "$temp_file"
if "$validator" --profile-file "$temp_file" --profile baseline --delivery-mode embedded > /dev/null 2>&1; then
    echo "profile with non-string bundle asset unexpectedly passed" >&2
    exit 1
fi

while IFS= read -r ignored_pattern; do
    grep -Fqx "$ignored_pattern" "$repo_root/templates/.prettierignore" || {
        echo "templates/.prettierignore is missing a pattern this repository's own .prettierignore excludes: $ignored_pattern" >&2
        exit 1
    }
done < <(grep -F 'conda-lock.yml' "$repo_root/.prettierignore")

for precommit_config in \
    "$repo_root/templates/languages/agnostic/pre-commit-snippets/base.tmpl" \
    "$repo_root/templates/languages/agnostic/.pre-commit-config.yaml" \
    "$repo_root/templates/languages/golang/.pre-commit-config.yaml" \
    "$repo_root/templates/languages/java/.pre-commit-config.yaml" \
    "$repo_root/templates/languages/python/.pre-commit-config.yaml" \
    "$repo_root/templates/languages/typescript/.pre-commit-config.yaml"; do
    awk '/id: yamllint/{f=1} f && /types: \[yaml\]/{print; exit} f' "$precommit_config" | grep -Fq "exclude: '(^|/)conda-lock\\.yml\$'" || {
        echo "templated yamllint hook must exclude conda-lock.yml, matching this repository's own .pre-commit-config.yaml: $precommit_config" >&2
        exit 1
    }
done

echo "bootstrap profile contract validated"
