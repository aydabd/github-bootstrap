#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
config="$repo_root/release-please-config.json"
manifest="$repo_root/.release-please-manifest.json"
workflow="$repo_root/.github/workflows/release-please.yml"

fail() {
    echo "root release-please contract: $*" >&2
    exit 1
}

test -f "$config" || fail "root release-please config is missing"
test -f "$manifest" || fail "root release-please manifest is missing"
test -f "$workflow" || fail "root release-please workflow is missing"

jq -e '
    .["release-type"] == "simple" and
    .["include-component-in-tag"] == false and
    .["include-v-in-tag"] == true and
    .packages["."]."changelog-path" == "CHANGELOG.md"
' "$config" > /dev/null || fail "root release-please config is invalid"

jq -e 'type == "object" and (.["."] | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))' "$manifest" > /dev/null ||
    fail "root release-please manifest is invalid"

grep -Fq 'config-file: release-please-config.json' "$workflow" ||
    fail "root workflow does not reference root release config"
grep -Fq 'manifest-file: .release-please-manifest.json' "$workflow" ||
    fail "root workflow does not reference root release manifest"

echo "Root release-please contract checks passed."
