#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMITLINT_CLI_VERSION="19.8.1"
COMMITLINT_CONFIG_CONVENTIONAL_VERSION="19.8.1"

policy_actions=(
    ".github/actions/verify-conventional-commits/action.yml"
    ".github/actions/verify-pull-request-title/action.yml"
    ".github/actions/verify-signed-off-by/action.yml"
)

for relative_path in "${policy_actions[@]}"; do
    root_path="$ROOT_DIR/$relative_path"
    template_path="$ROOT_DIR/templates/$relative_path"
    if [ ! -s "$root_path" ] || [ ! -s "$template_path" ]; then
        echo "MISSING_OR_EMPTY: $relative_path" >&2
        exit 1
    fi
    if ! cmp -s "$root_path" "$template_path"; then
        echo "OUT_OF_SYNC: $relative_path differs between root and templates" >&2
        exit 1
    fi
done

if ! command -v mise >/dev/null 2>&1; then
    echo "mise is required to run commit-policy fixtures" >&2
    exit 1
fi

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

run_default_policy() {
    # shellcheck disable=SC2016
    MISE_LOCKED=0 mise x node@26.6.0 -- npm exec --yes \
        "--package=@commitlint/cli@$COMMITLINT_CLI_VERSION" \
        "--package=@commitlint/config-conventional@$COMMITLINT_CONFIG_CONVENTIONAL_VERSION" \
        -- bash -euo pipefail -c '
            package_root="$(cd "$(dirname "$(command -v commitlint)")/.." && pwd)"
            commitlint --cwd "$package_root" --extends @commitlint/config-conventional
        '
}

run_local_policy() {
    MISE_LOCKED=0 mise x node@26.6.0 -- npm exec --yes \
        "--package=@commitlint/cli@$COMMITLINT_CLI_VERSION" \
        "--package=@commitlint/config-conventional@$COMMITLINT_CONFIG_CONVENTIONAL_VERSION" \
        -- commitlint --config "$fixture_dir/commitlint.config.cjs"
}

expect_valid() {
    local description="$1"
    local message="$2"
    local validator="$3"

    if ! printf '%s\n' "$message" | "$validator"; then
        echo "EXPECTED_VALID: $description" >&2
        exit 1
    fi
}

expect_invalid() {
    local description="$1"
    local message="$2"
    local validator="$3"

    if printf '%s\n' "$message" | "$validator"; then
        echo "EXPECTED_INVALID: $description" >&2
        exit 1
    fi
}

expect_valid "default commit without local configuration" "feat: add reusable policy actions" run_default_policy
expect_invalid "default commit without local configuration" "add reusable policy actions" run_default_policy
expect_valid "default pull-request title without local configuration" "fix: reject invalid pull-request titles" run_default_policy
expect_invalid "default pull-request title without local configuration" "reject invalid pull-request titles" run_default_policy

cat > "$fixture_dir/commitlint.config.cjs" <<'EOF'
module.exports = {
    rules: {
        'type-enum': [2, 'always', ['feat']],
    },
};
EOF

expect_valid "local config commit" "feat: accept repository policy" run_local_policy
expect_invalid "local config commit" "fix: reject repository policy" run_local_policy
expect_valid "local config pull-request title" "feat: accept repository title policy" run_local_policy
expect_invalid "local config pull-request title" "fix: reject repository title policy" run_local_policy

echo "OK: commit-policy fixtures accepted valid messages and rejected invalid messages."
