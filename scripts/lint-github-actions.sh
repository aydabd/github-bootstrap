#!/usr/bin/env bash
set -euo pipefail

mapfile -d '' workflow_files < <(
    find .github/workflows -type f -name '*.y*ml' -print0
)
mapfile -d '' action_files < <(
    find .github/actions -type f \( -name 'action.yml' -o -name 'action.yaml' \) -print0
)

if [ "${#workflow_files[@]}" -eq 0 ] && [ "${#action_files[@]}" -eq 0 ]; then
    echo "No GitHub Actions workflows or actions found; skipping action lint."
    exit 0
fi

if [ "${#workflow_files[@]}" -gt 0 ]; then
    actionlint -ignore 'SC[0-9]+' "${workflow_files[@]}"
fi
uv run --no-sync zizmor --pedantic .github
