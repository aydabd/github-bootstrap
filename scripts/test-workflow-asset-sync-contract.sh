#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sync_script="$repo_root/scripts/sync-workflow-assets.sh"

[ -x "$sync_script" ] || {
    echo "workflow asset sync script must be executable" >&2
    exit 1
}

grep -Fq 'sync-workflow-assets.sh --check' "$repo_root/.pre-commit-config.yaml" || {
    echo "pre-commit must run the workflow asset sync check" >&2
    exit 1
}

sync_hook_line="$(grep -n '^      - id: sync-workflow-assets$' "$repo_root/.pre-commit-config.yaml" | cut -d: -f1)"
parity_hook_line="$(grep -n '^      - id: github-workflow-assets$' "$repo_root/.pre-commit-config.yaml" | cut -d: -f1)"
if [ "$sync_hook_line" -ge "$parity_hook_line" ]; then
    echo "sync hook must run before the workflow asset parity check" >&2
    exit 1
fi

if grep -Fq '/templates' "$repo_root/.github/dependabot.yml"; then
    echo "root Dependabot Actions config must not scan /templates" >&2
    exit 1
fi

if grep -Fq '/templates' "$repo_root/templates/.github/dependabot.yml"; then
    echo "template Dependabot Actions config must not scan /templates" >&2
    exit 1
fi

"$sync_script" --check

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/scripts" "$fixture_dir/.github/workflows" "$fixture_dir/templates/.github/workflows"
cp "$sync_script" "$fixture_dir/scripts/sync-workflow-assets.sh"
chmod +x "$fixture_dir/scripts/sync-workflow-assets.sh"
printf 'root version\n' > "$fixture_dir/.github/workflows/commit-policy.yml"
printf 'template version\n' > "$fixture_dir/templates/.github/workflows/commit-policy.yml"
for relative_path in \
    ".github/actions/verify-conventional-commits/action.yml" \
    ".github/actions/verify-conventional-commits/validate.sh" \
    ".github/actions/verify-pull-request-title/action.yml" \
    ".github/actions/verify-pull-request-title/validate.sh" \
    ".github/actions/verify-signed-off-by/action.yml"; do
    mkdir -p "$fixture_dir/$(dirname "$relative_path")" \
        "$fixture_dir/templates/$(dirname "$relative_path")"
    printf 'shared asset\n' > "$fixture_dir/$relative_path"
    cp "$fixture_dir/$relative_path" "$fixture_dir/templates/$relative_path"
done

if "$fixture_dir/scripts/sync-workflow-assets.sh" --check; then
    echo "sync check must fail for divergent fixture" >&2
    exit 1
fi

"$fixture_dir/scripts/sync-workflow-assets.sh"
cmp -s "$fixture_dir/.github/workflows/commit-policy.yml" \
    "$fixture_dir/templates/.github/workflows/commit-policy.yml"

echo "Workflow asset sync contract checks passed."
