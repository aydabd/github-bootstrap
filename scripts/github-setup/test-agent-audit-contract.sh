#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
source_config="$repo_root/templates/.github/config"
python_bin="$repo_root/.venv/bin/python"

fail() {
    printf '{"schema_version":1,"result":"FAIL","error_code":"%s"}\n' "$1"
    exit 1
}

generated_root="$(mktemp -d 2> /dev/null)" || fail AUDIT_TEST_SETUP
trap 'rm -r "$generated_root" 2>/dev/null' EXIT
mkdir -p "$generated_root/.github" 2> /dev/null || fail AUDIT_TEST_SETUP
cp -R "$source_config" "$generated_root/.github/config" 2> /dev/null || fail AUDIT_TEST_SETUP
[ -x "$python_bin" ] || fail AUDIT_TEST_TOOL_UNAVAILABLE

root_result="$("$python_bin" "$source_config/audit-tests/test_contract.py" 2> /dev/null)" || {
    [ -n "$root_result" ] || fail AUDIT_TEST_TOOL_UNAVAILABLE
    printf '%s\n' "$root_result"
    exit 1
}
generated_result="$("$python_bin" "$generated_root/.github/config/audit-tests/test_contract.py" 2> /dev/null)" || {
    [ -n "$generated_result" ] || fail AUDIT_TEST_TOOL_UNAVAILABLE
    printf '%s\n' "$generated_result"
    exit 1
}
if [ "$root_result" != "$generated_result" ]; then
    fail AUDIT_TEMPLATE_PARITY
fi
rm -r "$generated_root" 2> /dev/null || fail AUDIT_TEST_CLEANUP
trap - EXIT
printf '%s\n' "$root_result"
