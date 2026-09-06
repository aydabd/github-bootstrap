#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

generate_one() {
    local environment_file=$1
    local lock_file=$2
    local language=$3
    local temp_environment="$tmp_root/${language}-environment.yml"
    cp "$environment_file" "$temp_environment"
    if [ "$language" != root ]; then
        sed -i \
            -e 's/{{REPOSITORY_NAME}}/generated-repository/g' \
            -e 's/{{PYTHON_VERSION}}/3.13/g' \
            -e 's/{{NODE_VERSION}}/24/g' \
            -e 's/{{GO_VERSION}}/1.26/g' \
            -e 's/{{JAVA_VERSION}}/25/g' "$temp_environment"
    fi
    local lock_tmp="$tmp_root/$language"
    mkdir -p "$lock_tmp"
    for platform in linux-64 osx-64 osx-arm64; do
        "$repo_root/scripts/generate-conda-lock.sh" \
            "$temp_environment" "$lock_tmp/$platform.yml" "$platform"
    done
    uv run --no-project --with pyyaml==6.0.3 python \
        "$repo_root/scripts/merge-conda-locks.py" "$lock_file" \
        "$lock_tmp/linux-64.yml" "$lock_tmp/osx-64.yml" "$lock_tmp/osx-arm64.yml"
}

generate_one "$repo_root/environment.yml" "$repo_root/conda-lock.yml" root
while IFS= read -r environment_file; do
    language="$(printf '%s' "$environment_file" | cut -d/ -f3)"
    generate_one "$environment_file" \
        "$repo_root/templates/languages/$language/providers/micromamba/conda-lock.yml" \
        "$language"
done < <(find "$repo_root/templates/languages" -path '*/providers/micromamba/environment.yml' -type f | sort)
