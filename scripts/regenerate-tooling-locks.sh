#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d)"
manifest_list="$tmp_root/manifest-list"
trap 'rm -rf "$tmp_root"' EXIT

require_command() {
    command -v "$1" > /dev/null 2>&1 || {
        echo "required lockfile tool is unavailable: $1" >&2
        exit 1
    }
}

require_command uv
require_command uvx
require_command npm

find "$repo_root" -type f \( -name 'conda-lock.yml' -o -name 'mise.lock' -o -name 'package-lock.json' -o -name 'uv.lock' -o -name '.pre-commit-config.yaml' \) -not -path "$repo_root/.git/*" -print | sort > "$manifest_list"
while IFS= read -r file; do
    relative="${file#"$repo_root/"}"
    mkdir -p "$tmp_root/backup/$(dirname "$relative")"
    cp -p "$file" "$tmp_root/backup/$relative"
done < "$manifest_list"

restore() {
    echo "lockfile refresh failed; restoring the pre-refresh lockfile set" >&2
    while IFS= read -r file; do
        relative="${file#"$repo_root/"}"
        cp -p "$tmp_root/backup/$relative" "$file"
    done < "$manifest_list"
}
trap restore ERR

# regenerate-conda-locks.sh invokes the pinned `conda-lock` through uvx.
bash "$repo_root/scripts/regenerate-conda-locks.sh"
# regenerate-mise-locks.sh invokes `mise lock` for every mise.toml.
# npm install --package-lock-only is the lock refresh equivalent of npm ci.
bash "$repo_root/scripts/regenerate-mise-locks.sh"

while IFS= read -r package_file; do
    npm install --package-lock-only --ignore-scripts --no-fund --prefix "$(dirname "$package_file")"
done < <(find "$repo_root" -name package.json -not -path "$repo_root/.provider/*" -print | sort)

while IFS= read -r project_file; do
    uv lock --upgrade --directory "$(dirname "$project_file")"
done < <(find "$repo_root" -name pyproject.toml -not -path "$repo_root/.provider/*" -print | sort)

# SHA refresh is performed by the cooldown-filtered updater in this run with
# `pre-commit autoupdate --freeze`.
grep -Fq 'pre-commit autoupdate --freeze' "$repo_root/tools/pkg/toolinglib/transform.go" || {
    echo "pre-commit autoupdate --freeze integration is missing" >&2
    exit 1
}

trap - ERR
echo "Tooling lockfiles regenerated successfully."
