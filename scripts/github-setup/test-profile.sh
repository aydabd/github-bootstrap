#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
profile_file="$repo_root/templates/.github/config/bootstrap-profile.json"
validator="$script_dir/validate-profile.sh"

command -v jq > /dev/null 2>&1 || {
    echo "jq is required to validate bootstrap profiles" >&2
    exit 1
}

[ -x "$validator" ] || {
    echo "profile validator is not executable: $validator" >&2
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
for creation_workflow in \
    "$repo_root/.github/workflows/create-repository.yml" \
    "$repo_root/.github/workflows/terraform-create-repository.yml"; do
    grep -q 'cp AGENTS.md new-repo/' "$creation_workflow"
    grep -q 'cp WORKTREES.md new-repo/' "$creation_workflow"
    grep -qF "tr -d '[:space:]'" "$creation_workflow"
    grep -q 'DELIVERY_MODE.*CENTRAL_REPOSITORY.*CENTRAL_REF' "$creation_workflow"
    grep -q '^      app_owner:' "$creation_workflow"
    grep -q '^      allowed_repo_owners:' "$creation_workflow"
    grep -q '^      require_cleanup_approval:' "$creation_workflow"
    grep -q '^      optional_features:' "$creation_workflow"
    grep -q 'OWNER/REPOSITORY@REF' "$creation_workflow"
    grep -q "OPTIONAL_FEATURES=\"\${{ inputs.optional_features || 'none' }}\"" "$creation_workflow"
done
if grep -Eq '^    if: .*matrix\.' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"; then
    echo "E2E workflow must not use matrix context in a job-level condition" >&2
    exit 1
fi
grep -q '^      - name: Select requested creation workflow$' "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
for runtime_input in python_version node_version go_version java_version; do
    runtime_env="$(printf '%s' "$runtime_input" | tr '[:lower:]' '[:upper:]')"
    grep -q -- "--field ${runtime_input}=\"\$${runtime_env}\"" \
        "$repo_root/.github/workflows/test-repository-creation.yml"
done
grep -q "REQUESTED_DELIVERY: \${{ inputs.delivery }}" "$repo_root/.github/workflows/test-generated-repository-e2e.yml"
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
grep -q 'LINT_MODE=check provider_run pre-commit' "$repo_root/templates/.github/actions/quality/run-quality/action.yml"
grep -q 'LINT_MODE=check provider_run pre-commit' "$repo_root/templates/.github/actions/quality/run-capability/action.yml"
grep -qF "(cd \"\$WORKING_DIRECTORY\" && provider_run python3 -m pytest)" "$repo_root/templates/.github/actions/quality/run-quality/action.yml"
grep -qF "(cd \"\$WORKING_DIRECTORY\" && LINT_MODE=check provider_run pre-commit run --all-files --color=always)" \
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
    grep -Eq -- "-type f -name ['\"]\\*\.json['\"] -exec jq empty \\{\\} \\+" "$json_quality_file"
    if grep -Eq 'while .*provider_run jq empty' "$json_quality_file"; then
        echo "lint-json must enter the provider once per capability: $json_quality_file" >&2
        exit 1
    fi
done
grep -q 'zizmor.*1.29.0' "$repo_root/environment.yml"
grep -q 'zizmor.*1.29.0' "$repo_root/mise.toml"
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
    grep -q 'zizmor.*1.29.0' "$setup_action"
    grep -q 'actions/cache@27d5ce7f107fe9357f9df03efb73ab90386fccae' "$setup_action"
    grep -q 'path: ~/.cache/pip' "$setup_action"
    grep -q 'pip-zizmor-1.29.0' "$setup_action"
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
awk '/lint-shell\)/ { in_block=1 } in_block && /node_modules/ { found=1 } in_block && /;;/ { exit(found ? 0 : 1) } END { if (!found) exit 1 }' \
    "$repo_root/templates/.github/actions/quality/run-quality/action.yml"
awk '/lint-shell\)/ { in_block=1 } in_block && /node_modules/ { found=1 } in_block && /;;/ { exit(found ? 0 : 1) } END { if (!found) exit 1 }' \
    "$repo_root/templates/.github/actions/quality/run-capability/action.yml"
awk '/lint-shell\)/ { in_block=1 } in_block && /node_modules/ { found=1 } in_block && /;;/ { exit(found ? 0 : 1) } END { if (!found) exit 1 }' \
    "$repo_root/templates/centralized-actions-workflows/.github/workflows/quality.yml"
for provider_file in "$repo_root"/templates/languages/*/providers/micromamba/environment.yml; do
    grep -q 'actionlint=1.7.12' "$provider_file"
    grep -q 'zizmor.*1.29.0' "$provider_file"
done
for provider_file in "$repo_root"/templates/languages/*/providers/mise/mise.toml; do
    grep -q 'actionlint = "1.7.12"' "$provider_file"
    grep -q 'zizmor.*1.29.0' "$provider_file"
done
for provider_file in "$repo_root"/templates/languages/*/providers/micromamba/environment.yml; do
    grep -q 'terraform' "$provider_file"
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

echo "bootstrap profile contract validated"
