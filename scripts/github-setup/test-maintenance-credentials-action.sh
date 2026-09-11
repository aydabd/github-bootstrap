#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
action="$repo_root/.github/actions/configure-provisioner-credentials/action.yml"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

grep -Fq "github-api-url: \${{ inputs.github_api_url }}" "$action" || {
    echo "maintenance App token creation must receive the selected API base" >&2
    exit 1
}
for workflow in create-repository.yml terraform-create-repository.yml; do
    workflow_path="$repo_root/.github/workflows/$workflow"
    grep -Fq 'github_api_url:' "$workflow_path" || {
        echo "maintenance callers must forward a GitHub API base: $workflow" >&2
        exit 1
    }
    grep -Fq "format('https://{0}/api/v3', inputs.github_host)" "$workflow_path" || {
        echo "maintenance callers must derive the GHES API base: $workflow" >&2
        exit 1
    }
done

run_script="$tmp_dir/action-run.sh"
awk '
    /^      run: \|$/ { capture = 1; next }
    capture && /^        / { sub(/^        /, ""); print; next }
    capture { exit }
' "$action" > "$run_script"
chmod 700 "$run_script"

fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/gh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\t%s\n' "${GH_TOKEN:-}" "$*" >> "$GH_CALLS"
case "$*" in
    *"/installation/repositories"*)
        if [ "${GH_TOKEN:-}" = provisioner-token ] || [ "${MAINTENANCE_ACCESS:-yes}" = yes ]; then
            printf '%s\n' '[{"repositories":[{"full_name":"acme/generated"}]}]'
        else
            printf '%s\n' '[{"repositories":[]}]'
        fi
        ;;
    *"/repos/acme/generated"*)
        if [ "${GH_TOKEN:-}" = provisioner-token ] || [ "${MAINTENANCE_ACCESS:-yes}" = yes ]; then
            printf '%s\n' '{"full_name":"acme/generated"}'
        else
            exit 1
        fi
        ;;
esac
EOF
chmod 700 "$fake_bin/gh"

run_action() {
    local profile="$1"
    local environment="$2"
    local maintenance_access="$3"
    : > "$tmp_dir/gh-calls"
    if MAINTENANCE_ACCESS="$maintenance_access" \
        GH_CALLS="$tmp_dir/gh-calls" \
        PATH="$fake_bin:$PATH" \
        GITHUB_ACTION_PATH="$repo_root/.github/actions/configure-provisioner-credentials" \
        GITHUB_ENV="$tmp_dir/github-env" \
        REPOSITORY_INPUT=acme/generated \
        PROFILE_INPUT="$profile" \
        ENVIRONMENT_INPUT="$environment" \
        CLIENT_ID_INPUT=maintenance-client-id \
        APP_SLUG_INPUT=maintenance-app \
        APP_PRIVATE_KEY_INPUT=maintenance-private-key \
        GH_TOKEN_INPUT=provisioner-token \
        MAINTENANCE_TOKEN_INPUT=maintenance-token \
        bash "$run_script" > "$tmp_dir/action-output" 2>&1; then
        return 0
    fi
    return 1
}

failures=0
if ! run_action production-maintenance-writer production-maintenance yes; then
    echo "production maintenance profile was rejected by the action" >&2
    failures=$((failures + 1))
fi
if ! grep -Fq $'maintenance-token\tapi --paginate --slurp /installation/repositories' "$tmp_dir/gh-calls"; then
    echo "maintenance preflight did not use the selected App token" >&2
    failures=$((failures + 1))
fi

if run_action e2e-maintenance-writer e2e-maintenance no; then
    echo "maintenance installation access denial was not enforced" >&2
    failures=$((failures + 1))
fi
grep -Fq 'https://github.com/apps/maintenance-app/installations/new' "$tmp_dir/action-output" || {
    echo "maintenance installation denial must include an App remediation URL" >&2
    failures=$((failures + 1))
}

[ "$failures" -eq 0 ] || exit 1

echo "Maintenance credential action runtime contract passed."
