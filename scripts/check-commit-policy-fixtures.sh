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

weekly_workflow="$ROOT_DIR/.github/workflows/weekly-tooling-updates.yml"
# shellcheck disable=SC2016
if ! grep -qF 'git commit --no-verify -s -m "$commit_msg"' "$weekly_workflow"; then
    echo "MISSING_SIGNED_OFF_BY: weekly tooling workflow commit" >&2
    exit 1
fi

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

conventional_script="$ROOT_DIR/.github/actions/verify-conventional-commits/validate.sh"
title_script="$ROOT_DIR/.github/actions/verify-pull-request-title/validate.sh"
conventional_action="$ROOT_DIR/.github/actions/verify-conventional-commits/action.yml"
for script_path in "$conventional_script" "$title_script"; do
    if [ ! -s "$script_path" ]; then
        echo "MISSING_OR_EMPTY: $script_path" >&2
        exit 1
    fi
done

# shellcheck disable=SC2016
if ! grep -qF '  working-directory:' "$conventional_action" ||
    ! grep -qF '    default: "."' "$conventional_action" ||
    ! grep -qF '      working-directory: ${{ inputs.working-directory }}' "$conventional_action"; then
    echo "MISSING_WORKING_DIRECTORY_INPUT: verify-conventional-commits action" >&2
    exit 1
fi

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/bin" "$fixture_dir/run/monorepo"

cat > "$fixture_dir/bin/gh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ] || [ "$1" != "api" ] || [ "$2" != "--paginate" ] || [ "$3" != "--slurp" ] || [ "$4" != "/repos/owner/repository/pulls/42/commits?per_page=100" ]; then
    echo "unexpected gh invocation: $*" >&2
    exit 1
fi

cat "$GH_FIXTURE"
EOF

cat > "$fixture_dir/bin/mise" << EOF
#!/usr/bin/env bash
set -euo pipefail

if [ "\$#" -lt 8 ] || [ "\$1" != "x" ] || [ "\$2" != "node@26.6.0" ] || [ "\$3" != "--" ] || [ "\$4" != "npm" ] || [ "\$5" != "exec" ] || [ "\$6" != "--yes" ]; then
    echo "unexpected mise invocation: \$*" >&2
    exit 1
fi
shift 6

has_cli=false
has_default_config=false
while [ "\$1" != "--" ]; do
    case "\$1" in
        "--package=@commitlint/cli@$COMMITLINT_CLI_VERSION") has_cli=true ;;
        "--package=@commitlint/config-conventional@$COMMITLINT_CONFIG_CONVENTIONAL_VERSION") has_default_config=true ;;
        *)
            echo "unexpected npm package argument: \$1" >&2
            exit 1
            ;;
    esac
    shift
done

if [ "\$has_cli" != true ] || [ "\$has_default_config" != true ]; then
    echo "missing pinned commitlint package" >&2
    exit 1
fi
shift
exec "\$@"
EOF

cat > "$fixture_dir/bin/commitlint" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

default_policy=false
local_config=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --cwd)
            default_policy=true
            shift 2
            ;;
        --extends)
            if [ "${2:-}" != "@commitlint/config-conventional" ]; then
                echo "unexpected commitlint preset: ${2:-}" >&2
                exit 1
            fi
            default_policy=true
            shift 2
            ;;
        --config)
            local_config="${2:-}"
            shift 2
            ;;
        *)
            echo "unexpected commitlint argument: $1" >&2
            exit 1
            ;;
    esac
done

message="$(cat)"
if [ -n "$local_config" ]; then
    if [ ! -f "$local_config" ]; then
        echo "missing local config: $local_config" >&2
        exit 1
    fi
    if ! grep -qF "'type-enum': [2, 'always', ['feat']]" "$local_config"; then
        echo "unexpected local config type-enum rule: $local_config" >&2
        exit 1
    fi
    if [[ "$message" =~ ^feat:\ .+ ]]; then
        exit 0
    fi
    echo "local policy rejected: $message" >&2
    exit 1
fi

if [ "$default_policy" != true ]; then
    echo "default policy did not receive a conventional preset" >&2
    exit 1
fi
if [[ "$message" =~ ^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([[:alnum:]._-]+\))?!?:\ .+ ]]; then
    exit 0
fi
echo "default policy rejected: $message" >&2
exit 1
EOF

chmod +x "$fixture_dir/bin/gh" "$fixture_dir/bin/mise" "$fixture_dir/bin/commitlint"

cat > "$fixture_dir/default-valid.json" << 'EOF'
[[
    {"commit": {"message": "feat: add reusable policy actions"}},
    {"commit": {"message": "fix: reject invalid pull-request titles"}}
]]
EOF

cat > "$fixture_dir/default-invalid.json" << 'EOF'
[[
    {"commit": {"message": "feat: add reusable policy actions"}},
    {"commit": {"message": "add reusable policy actions"}}
]]
EOF

cat > "$fixture_dir/local-valid.json" << 'EOF'
[[{"commit": {"message": "feat: accept repository policy"}}]]
EOF

cat > "$fixture_dir/local-invalid.json" << 'EOF'
[[{"commit": {"message": "fix: reject repository policy"}}]]
EOF

cat > "$fixture_dir/run/monorepo/commitlint.config.cjs" << 'EOF'
module.exports = {
    rules: {
        'type-enum': [2, 'always', ['feat']],
    },
};
EOF

cat > "$fixture_dir/run/monorepo/unexpected-commitlint.config.cjs" << 'EOF'
module.exports = {
    rules: {
        'type-enum': [2, 'always', ['fix']],
    },
};
EOF

run_conventional_action() {
    local fixture_name="$1"
    local config_path="$2"
    local working_directory="$3"

    (
        cd "$fixture_dir/run/$working_directory"
        PATH="$fixture_dir/bin:$PATH" \
            GH_FIXTURE="$fixture_dir/$fixture_name" \
            GH_TOKEN="fixture-token" \
            REPOSITORY="owner/repository" \
            PR_NUMBER="42" \
            CONFIG_PATH="$config_path" \
            bash "$conventional_script"
    )
}

run_title_action() {
    local title="$1"
    local config_path="$2"

    PATH="$fixture_dir/bin:$PATH" \
        TITLE="$title" \
        CONFIG_PATH="$config_path" \
        bash "$title_script"
}

expect_valid() {
    local description="$1"
    shift

    if ! "$@"; then
        echo "EXPECTED_VALID: $description" >&2
        exit 1
    fi
}

expect_invalid() {
    local description="$1"
    shift

    if "$@"; then
        echo "EXPECTED_INVALID: $description" >&2
        exit 1
    fi
}

expect_valid "every default commit" run_conventional_action default-valid.json "" "."
expect_invalid "invalid default commit" run_conventional_action default-invalid.json "" "."
expect_valid "default pull-request title" run_title_action "fix: reject invalid pull-request titles" ""
expect_invalid "invalid default pull-request title" run_title_action "reject invalid pull-request titles" ""
expect_valid "local config commit" run_conventional_action local-valid.json "commitlint.config.cjs" "monorepo"
expect_invalid "local config commit" run_conventional_action local-invalid.json "commitlint.config.cjs" "monorepo"
expect_invalid "unexpected local config rule" run_conventional_action local-valid.json "unexpected-commitlint.config.cjs" "monorepo"
expect_valid "local config pull-request title" run_title_action "feat: accept repository title policy" "$fixture_dir/run/monorepo/commitlint.config.cjs"
expect_invalid "local config pull-request title" run_title_action "fix: reject repository title policy" "$fixture_dir/run/monorepo/commitlint.config.cjs"

echo "OK: shared policy action validation accepted valid fixtures and rejected invalid fixtures."
