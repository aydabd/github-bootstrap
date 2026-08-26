#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

for config in \
    "$repo_root/.pre-commit-config.yaml" \
    "$repo_root/templates/languages/agnostic/.pre-commit-config.yaml" \
    "$repo_root/templates/languages/golang/.pre-commit-config.yaml" \
    "$repo_root/templates/languages/java/.pre-commit-config.yaml" \
    "$repo_root/templates/languages/python/.pre-commit-config.yaml" \
    "$repo_root/templates/languages/typescript/.pre-commit-config.yaml"; do
    assert_contains "id: lint-actions" "$config"
    assert_contains "entry: ./scripts/lint-github-actions.sh" "$config"
    assert_contains ".github/(workflows|actions)" "$config"
    assert_contains "stages: [manual]" "$config"
done

assert_contains "actionlint" "$repo_root/scripts/lint-github-actions.sh"
assert_contains "zizmor --pedantic" "$repo_root/scripts/lint-github-actions.sh"
assert_contains ".github/workflows" "$repo_root/scripts/lint-github-actions.sh"
assert_contains ".github/actions" "$repo_root/scripts/lint-github-actions.sh"
assert_contains "actionlint" "$repo_root/templates/scripts/lint-github-actions.sh"
assert_contains "zizmor --pedantic" "$repo_root/templates/scripts/lint-github-actions.sh"
assert_contains "quality-actions" "$repo_root/make/lint.mk"
for workflow in create-repository.yml terraform-create-repository.yml; do
    assert_not_contains "default: lint-markdown,lint-json,lint-yaml,lint-actions" "$repo_root/.github/workflows/$workflow"
done

for manifest in "$repo_root/environment.yml" \
    "$repo_root/templates/languages/agnostic/providers/micromamba/environment.yml"; do
    assert_contains "- actionlint=1.7.12" "$manifest"
    assert_contains "- zizmor=1.29.0" "$manifest"
done

echo "Action lint contract checks passed."
