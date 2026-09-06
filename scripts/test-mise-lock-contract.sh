#!/usr/bin/env bash
set -euo pipefail

# Contract: every mise provider has reproducible mise and npm lock inputs, and
# installation never falls back to a global npm package install.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

status=0
fail() {
    echo "mise-lock contract: $1" >&2
    status=1
}

check_provider() {
    local provider_dir="$1"
    local mise_file="$provider_dir/mise.toml"
    local mise_lock="$provider_dir/mise.lock"
    local package_file="$provider_dir/package.json"
    local npm_lock="$provider_dir/package-lock.json"

    for required in "$mise_file" "$mise_lock" "$package_file" "$npm_lock"; do
        [ -f "$required" ] || fail "missing mise lock input: $required"
    done
    if [ -f "$mise_file" ]; then
        grep -Eq 'npm ci --ignore-scripts --no-audit --no-fund' "$mise_file" ||
            fail "$mise_file does not run locked npm ci"
        if grep -Eq 'npm install -g' "$mise_file"; then
            fail "$mise_file still uses global npm installation"
        fi
    fi
    make_file="$provider_dir/Makefile"
    if [ -f "$make_file" ] && [ "$provider_dir" != "$repo_root" ]; then
        grep -Fq 'install --locked' "$make_file" ||
            fail "$make_file does not install mise with --locked"
    fi
    if [ -f "$package_file" ]; then
        grep -Eq '"prettier": "[0-9]+\.[0-9]+\.[0-9]+"' "$package_file" ||
            fail "$package_file does not pin prettier exactly"
        grep -Eq '"markdownlint-cli": "[0-9]+\.[0-9]+\.[0-9]+"' "$package_file" ||
            fail "$package_file does not pin markdownlint-cli exactly"
    fi
    if [ -f "$npm_lock" ]; then
        grep -q '"lockfileVersion":' "$npm_lock" || fail "$npm_lock is not an npm lockfile"
        grep -q '"integrity":' "$npm_lock" || fail "$npm_lock has no integrity data"
    fi
}

check_provider "$repo_root"
while IFS= read -r mise_file; do
    check_provider "$(dirname "$mise_file")"
done < <(find "$repo_root/templates/languages" -path '*/providers/mise/mise.toml' -type f | sort)

grep -Fq 'install --locked' "$repo_root/make/env.mk" ||
    fail "root environment setup does not install mise with --locked"
grep -Fq 'node_modules/.bin' "$repo_root/make/common.mk" ||
    fail "root mise execution path does not include local npm binaries"
grep -Fq 'node_modules/.bin' "$repo_root/templates/providers/mise/provider-run.sh" ||
    fail "generated mise provider runner does not include local npm binaries"
while IFS= read -r make_file; do
    grep -Fq 'node_modules/.bin' "$make_file" ||
        fail "$make_file does not include local npm binaries in mise execution"
done < <(find "$repo_root/templates/languages" -path '*/providers/mise/Makefile' -type f | sort)

configure_action="$repo_root/.github/actions/configure-provider-tooling-files/action.yml"
for file in mise.toml mise.lock package.json package-lock.json; do
    grep -Fq "PROVIDER_DIR/$file" "$configure_action" ||
        fail "generated repository action does not copy $file"
done

weekly_workflow="$repo_root/.github/workflows/weekly-tooling-updates.yml"
grep -Fq 'scripts/regenerate-tooling-locks.sh' "$weekly_workflow" ||
    fail "weekly tooling workflow does not regenerate mise locks"

if [ "$status" -ne 0 ]; then
    echo "mise lock contract failed" >&2
    exit 1
fi
echo "mise lock contract checks passed."
