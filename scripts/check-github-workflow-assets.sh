#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_assets=(
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

template_workflow="$ROOT_DIR/templates/.github/workflows/project-status-sync.yml"
if [ ! -s "$template_workflow" ]; then
    echo "MISSING_OR_EMPTY: $template_workflow" >&2
    errors=$((errors + 1))
fi

if [ "$errors" -ne 0 ]; then
    exit 1
fi

echo "OK: generic GitHub workflow assets exist in the bootstrap repo and templates."
