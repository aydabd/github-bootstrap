#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"

shared_assets=(
    ".github/workflows/commit-policy.yml"
    ".github/actions/verify-conventional-commits/action.yml"
    ".github/actions/verify-conventional-commits/validate.sh"
    ".github/actions/verify-pull-request-title/action.yml"
    ".github/actions/verify-pull-request-title/validate.sh"
    ".github/actions/verify-signed-off-by/action.yml"
)

mode="${1:-sync}"
case "$mode" in
    sync | --check) ;;
    *)
        echo "Usage: $0 [--check]" >&2
        exit 2
        ;;
esac

errors=0
for relative_path in "${shared_assets[@]}"; do
    source_path="$root_dir/$relative_path"
    template_path="$root_dir/templates/$relative_path"

    if [ ! -s "$source_path" ]; then
        echo "MISSING_OR_EMPTY: $source_path" >&2
        errors=$((errors + 1))
        continue
    fi

    if [ "$mode" = "--check" ]; then
        if ! cmp -s "$source_path" "$template_path" 2> /dev/null; then
            echo "OUT_OF_SYNC: $relative_path differs between root and templates" >&2
            errors=$((errors + 1))
        fi
        continue
    fi

    mkdir -p "$(dirname "$template_path")"
    cp "$source_path" "$template_path"
    echo "SYNCED: $relative_path"
done

if [ "$errors" -ne 0 ]; then
    if [ "$mode" = "--check" ]; then
        echo "Workflow asset sync check failed." >&2
    fi
    exit 1
fi

if [ "$mode" = "--check" ]; then
    echo "Workflow asset sync check passed."
fi
