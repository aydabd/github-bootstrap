#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/verify-commit-verification.sh"
workflow="$script_dir/../../.github/workflows/weekly-tooling-updates.yml"
resolver="$script_dir/../../.github/actions/resolve-gh-token/action.yml"

[ -x "$helper" ] || {
    echo "commit verification helper is not executable" >&2
    exit 1
}

for required_text in \
    "uses: ./.github/actions/resolve-gh-token" \
    "environment: production-maintenance" \
    "permission_profile: weekly-tooling" \
    "BOOTSTRAP_MAINTENANCE_WRITER_APP_PRIVATE_KEY" \
    "BOOTSTRAP_MAINTENANCE_WRITER_APP_CLIENT_ID" \
    "BOOTSTRAP_MAINTENANCE_WRITER_APP_SLUG" \
    "[ \"\$APP_SLUG\" = \"\$EXPECTED_APP_SLUG\" ]" \
    "APP_SLUG: \${{ steps.resolve-token.outputs.app_slug }}" \
    "signoff_name=\"\$GITHUB_ACTOR\"" \
    "Signed-off-by: \${signoff_name} <\${signoff_email}>" \
    "X-GitHub-Bootstrap-Automation: weekly-tooling-updates" \
    "git diff --cached --name-only" \
    "file_changes=\"\$payload_dir/file-changes.json\"" \
    "create_commit_payload=\"\$payload_dir/create-commit.json\"" \
    "create_commit_response=\"\$payload_dir/create-commit-response.json\"" \
    "mode=\"\$(git ls-files -s -- \"\$path\" | awk" \
    "[ \"\$mode\" = \"100644\" ] ||" \
    "createCommitOnBranch" \
    "expectedHeadOid" \
    "fileChanges" \
    "repositoryNameWithOwner" \
    "gh api --method POST \"/repos/\$GITHUB_REPOSITORY/git/refs\"" \
    "ref_payload=\"\$payload_dir/ref.json\"" \
    "ref_response=\"\$payload_dir/ref-response.json\"" \
    "'{ref: \$ref, sha: \$sha}'" \
    "gh api graphql --input \"\$create_commit_payload\"" \
    "commit_sha=\"\$(jq -er" \
    "gh api --method POST \"/repos/\$GITHUB_REPOSITORY/pulls\"" \
    "wait_for_branch()" \
    "weekly tooling branch did not become visible" \
    "visible_branch_sha=\"\$(wait_for_branch)\"" \
    "[ \"\$visible_branch_sha\" = \"\$parent_sha\" ]" \
    "branch_sha=\"\$(gh api" \
    "bash ./scripts/github-setup/verify-commit-verification.sh \"\$GITHUB_REPOSITORY\" \"\$commit_sha\"" \
    "expected_branch_sha=\"\$(gh api" \
    "branch_message=\"\$(gh api" \
    "Weekly tooling branch is not owned by this automation" \
    "printf '%s\\n' \"\$branch_message\" | grep -Fqx"; do
    grep -Fq -- "$required_text" "$workflow" || {
        echo "expected '$required_text' in $workflow" >&2
        exit 1
    }
done

if grep -Fq 'gh pr create' "$workflow"; then
    echo "weekly tooling PR creation must use the REST API" >&2
    exit 1
fi

if grep -Fq 'create_label_args' "$workflow"; then
    echo "weekly tooling workflow must not retain unused create-label arguments" >&2
    exit 1
fi

for forbidden_text in \
    "gh api --method POST \"/repos/\$GITHUB_REPOSITORY/git/blobs\"" \
    "gh api --method POST \"/repos/\$GITHUB_REPOSITORY/git/trees\"" \
    "gh api --method POST \"/repos/\$GITHUB_REPOSITORY/git/commits\"" \
    "git push"; do
    if grep -Fq -- "$forbidden_text" "$workflow"; then
        echo "weekly tooling workflow must use the atomic GraphQL commit path" >&2
        exit 1
    fi
done

if grep -Fq '  push:' "$workflow"; then
    echo "weekly tooling workflow must not run after every main push" >&2
    exit 1
fi
for required_trigger in '  schedule:' '  workflow_dispatch:'; do
    grep -Fq "$required_trigger" "$workflow" || {
        echo "weekly tooling workflow must retain $required_trigger trigger" >&2
        exit 1
    }
done

if grep -Fq 'BOOTSTRAP_APP_SIGNING_KEY' "$workflow" ||
    grep -Fq 'git commit ' "$workflow" ||
    grep -Fq 'git write-tree' "$workflow" ||
    grep -Fq 'force=true' "$workflow"; then
    echo "verified App commits must use the Git database API, not local git signing" >&2
    exit 1
fi

if grep -Fq 'git -c http.extraheader=' "$workflow"; then
    echo "Git push must pass authentication through Git config environment variables" >&2
    exit 1
fi

grep -Fq 'app_slug:' "$resolver" || {
    echo "resolver must expose the authenticated App slug" >&2
    exit 1
}
if grep -Fq 'app_id:' "$resolver"; then
    echo "resolver must not expose the deprecated App ID output" >&2
    exit 1
fi

for forbidden_text in \
    "GH_TOKEN: \${{ github.token }}" \
    "automation_login=\"\$GITHUB_ACTOR\"" \
    "automation_id=\"\$GITHUB_ACTOR_ID\"" \
    "git remote set-url"; do
    if grep -Fq "$forbidden_text" "$workflow"; then
        echo "unexpected ordinary Actions token path in $workflow" >&2
        exit 1
    fi
done

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/bin"
cat > "$fixture_dir/bin/gh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$GH_VERIFICATION"
EOF
chmod 700 "$fixture_dir/bin/gh"

expect_rejected() {
    if PATH="$fixture_dir/bin:$PATH" GH_TOKEN=secret GH_VERIFICATION="$1" \
        "$helper" owner/repository "0123456789abcdef0123456789abcdef01234567" \
        > "$fixture_dir/output" 2>&1; then
        echo "expected unverified commit to be rejected: $1" >&2
        exit 1
    fi
}

expect_rejected $'false\tunsigned'
expect_rejected $'true\tunknown'
PATH="$fixture_dir/bin:$PATH" GH_TOKEN=secret GH_VERIFICATION=$'true\tvalid' \
    "$helper" owner/repository "0123456789abcdef0123456789abcdef01234567" \
    > "$fixture_dir/output"
[ ! -s "$fixture_dir/output" ] || {
    echo "commit verification helper must not print credentials or API responses" >&2
    exit 1
}

echo "Commit verification contract checks passed."
