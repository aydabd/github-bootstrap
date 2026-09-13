#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
generated_root="$(mktemp -d)"
trap 'rm -rf "$generated_root"' EXIT
mkdir -p "$generated_root/.github"
cp -R "$repo_root/templates/.github/config" "$generated_root/.github/config"

result="$(uv run --with jsonschema==4.25.1 --with rfc8785==0.1.4 \
    "$repo_root/templates/.github/config/audit-tests/test_provenance_collector.py")" || {
    printf '%s\n' "$result"
    exit 1
}
generated_result="$(uv run --with jsonschema==4.25.1 --with rfc8785==0.1.4 \
    "$generated_root/.github/config/audit-tests/test_provenance_collector.py")" || {
    printf '%s\n' "$generated_result"
    exit 1
}
[ "$result" = "$generated_result" ] || {
    printf '{"schema_version":1,"result":"FAIL","error_code":"AUDIT_TEMPLATE_PARITY"}\n'
    exit 1
}
printf '%s\n' "$result"
