#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_assets=(
    ".github/workflows/quality.yml"
    ".github/workflows/commit-policy.yml"
    ".github/actions/verify-conventional-commits/action.yml"
    ".github/actions/verify-pull-request-title/action.yml"
    ".github/actions/verify-signed-off-by/action.yml"
    ".github/skills/github-stack/SKILL.md"
    ".github/skills/git-worktree/SKILL.md"
    ".github/skills/github-issue-triage/SKILL.md"
    ".github/skills/tracker-setup/SKILL.md"
    ".github/skills/tracker-views/SKILL.md"
    ".github/skills/backlog-breakdown/SKILL.md"
    ".github/skills/roadmap-prioritization/SKILL.md"
    ".github/agents/roadmap-prioritizer.agent.md"
    ".github/pull_request_template.md"
    ".github/ISSUE_TEMPLATE/config.yml"
    ".github/ISSUE_TEMPLATE/bug_report.md"
    ".github/ISSUE_TEMPLATE/feature_request.md"
    ".github/ISSUE_TEMPLATE/task.md"
    ".github/ISSUE_TEMPLATE/planning.md"
)

errors=0
for relative_path in "${required_assets[@]}"; do
    for base_dir in "$ROOT_DIR" "$ROOT_DIR/templates"; do
        path="$base_dir/$relative_path"
        if [ ! -s "$path" ]; then
            echo "MISSING_OR_EMPTY: $path" >&2
            errors=$((errors + 1))
        fi
    done
done

shared_assets=(
    ".github/workflows/commit-policy.yml"
    ".github/actions/verify-conventional-commits/action.yml"
    ".github/actions/verify-pull-request-title/action.yml"
    ".github/actions/verify-signed-off-by/action.yml"
)
for relative_path in "${shared_assets[@]}"; do
    if ! cmp -s "$ROOT_DIR/$relative_path" "$ROOT_DIR/templates/$relative_path" 2> /dev/null; then
        echo "OUT_OF_SYNC: $relative_path differs between root and templates" >&2
        errors=$((errors + 1))
    fi
done

obsolete_assets=(
    ".github/workflows/signed-off-by.yml"
)
for relative_path in "${obsolete_assets[@]}"; do
    for base_dir in "$ROOT_DIR" "$ROOT_DIR/templates"; do
        path="$base_dir/$relative_path"
        if [ -e "$path" ]; then
            echo "OBSOLETE_ASSET: $path must be removed" >&2
            errors=$((errors + 1))
        fi
    done
done

template_quality_assets=(
    ".github/workflows/quality-capability.yml"
    ".github/actions/quality/run-capability/action.yml"
    ".github/actions/quality/run-quality/action.yml"
)
for relative_path in "${template_quality_assets[@]}"; do
    path="$ROOT_DIR/templates/$relative_path"
    if [ ! -s "$path" ]; then
        echo "MISSING_OR_EMPTY: $path" >&2
        errors=$((errors + 1))
    fi
done

template_workflow="$ROOT_DIR/templates/.github/workflows/project-status-sync.yml"
if [ ! -s "$template_workflow" ]; then
    echo "MISSING_OR_EMPTY: $template_workflow" >&2
    errors=$((errors + 1))
fi

template_profile="$ROOT_DIR/templates/.github/config/bootstrap-profile.json"
if [ ! -s "$template_profile" ]; then
    echo "MISSING_OR_EMPTY: $template_profile" >&2
    errors=$((errors + 1))
fi

if [ "$errors" -ne 0 ]; then
    exit 1
fi

echo "OK: generic GitHub workflow assets exist in the bootstrap repo and templates."
