#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$repo_root"

changed="$(git diff HEAD --name-only)"
has_changed() {
    local path="${1#./}"
    printf '%s\n' "$changed" | grep -Fxq -- "$path"
}

require_lock_for() {
    local manifest="$1"
    local lock="$2"
    if has_changed "$manifest" && ! has_changed "$lock"; then
        echo "tooling manifest changed without lockfile refresh: $manifest -> $lock" >&2
        exit 1
    fi
}

while IFS= read -r manifest; do
    relative="${manifest#"$repo_root/"}"
    case "$relative" in
        environment.yml | templates/languages/*/providers/micromamba/environment.yml)
            require_lock_for "$relative" "$(dirname "$relative")/conda-lock.yml"
            ;;
        mise.toml | templates/languages/*/providers/mise/mise.toml)
            require_lock_for "$relative" "$(dirname "$relative")/mise.lock"
            ;;
        package.json | templates/languages/*/providers/mise/package.json)
            require_lock_for "$relative" "$(dirname "$relative")/package-lock.json"
            ;;
        pyproject.toml | templates/languages/*/pyproject.toml)
            require_lock_for "$relative" "$(dirname "$relative")/uv.lock"
            ;;
        .pre-commit-config.yaml | templates/languages/*/.pre-commit-config.yaml)
            require_lock_for "$relative" "$relative"
            ;;
    esac
done < <(find "$repo_root" -type f \( -name environment.yml -o -name mise.toml -o -name package.json -o -name pyproject.toml -o -name .pre-commit-config.yaml \) -not -path "$repo_root/.provider/*" -not -path "$repo_root/.git/*" -print)

echo "Tooling manifest/lockfile drift check passed."
