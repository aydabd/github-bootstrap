#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
python_bin="$repo_root/.venv/bin/python"
generated_root="$(mktemp -d)"
trap 'rm -rf "$generated_root"' EXIT
mkdir -p "$generated_root/.github"
cp -R "$repo_root/templates/.github/config" "$generated_root/.github/config"

[ -x "$python_bin" ] || {
    printf '{"schema_version":1,"result":"FAIL","error_code":"AUDIT_TEST_TOOL_UNAVAILABLE"}\n'
    exit 1
}

result="$("$python_bin" "$repo_root/templates/.github/config/audit-tests/test_github_verifier.py")"
generated_result="$("$python_bin" "$generated_root/.github/config/audit-tests/test_github_verifier.py")"
[ "$result" = "$generated_result" ] || {
    printf '{"schema_version":1,"result":"FAIL","error_code":"AUDIT_TEMPLATE_PARITY"}\n'
    exit 1
}
printf '%s\n' "$result"
