#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required_platforms=(linux-64 osx-64 osx-arm64)

environment_files=("$repo_root/environment.yml")
while IFS= read -r environment_file; do
    environment_files+=("$environment_file")
done < <(find "$repo_root/templates/languages" -path '*/providers/micromamba/environment.yml' -type f | sort)

for environment_file in "${environment_files[@]}"; do
    lock_file="${environment_file%/*}/conda-lock.yml"
    [ -f "$lock_file" ] || {
        echo "missing conda lockfile for ${environment_file#"$repo_root/"}" >&2
        exit 1
    }
    grep -Fq 'platforms:' "$lock_file" || {
        echo "missing platforms declaration in ${lock_file#"$repo_root/"}" >&2
        exit 1
    }
    for platform in "${required_platforms[@]}"; do
        grep -Fq -- "- $platform" "$lock_file" || {
            echo "missing $platform lock entries in ${lock_file#"$repo_root/"}" >&2
            exit 1
        }
    done
    if grep -Eq '^\s*pip\s*:' "$environment_file"; then
        echo "pip section is not allowed in ${environment_file#"$repo_root/"}" >&2
        exit 1
    fi
done

echo "Conda lock contract checks passed."
