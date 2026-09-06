#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mise_bin="${MISE_BIN:-mise}"

if ! command -v "$mise_bin" > /dev/null 2>&1 && [ ! -x "$mise_bin" ]; then
    mkdir -p "$repo_root/.provider/bin"
    bash "$repo_root/scripts/bootstrap-provider-binary.sh" mise "$repo_root/.provider/bin/mise"
    mise_bin="$repo_root/.provider/bin/mise"
fi

bash "$repo_root/scripts/regenerate-mise-lock.sh" "$repo_root" "$mise_bin"

cleanup_temp_dir() {
    rm -rf "$temp_dir"
}

while IFS= read -r mise_file; do
    template_dir="$(dirname "$mise_file")"
    temp_dir="$(mktemp -d)"
    trap cleanup_temp_dir EXIT
    sed -e 's/{{PYTHON_VERSION}}/3.13/g' \
        -e 's/{{NODE_VERSION}}/24/g' \
        -e 's/{{GO_VERSION}}/1.26/g' \
        -e 's/{{JAVA_VERSION}}/25/g' \
        "$mise_file" > "$temp_dir/mise.toml"
    bash "$repo_root/scripts/regenerate-mise-lock.sh" "$temp_dir" "$mise_bin"
    cp "$temp_dir/mise.lock" "$template_dir/mise.lock"
    cleanup_temp_dir
    trap - EXIT
done < <(find "$repo_root/templates/languages" -path '*/providers/mise/mise.toml' -type f | sort)
