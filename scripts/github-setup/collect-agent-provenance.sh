#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
python_bin="${AUDIT_PYTHON:-$repo_root/.venv/bin/python}"

[ -x "$python_bin" ] || {
    printf '{"schema_version":1,"result":"FAIL","error_code":"AUDIT_TEST_TOOL_UNAVAILABLE"}\n'
    exit 1
}
exec "$python_bin" "$repo_root/templates/.github/config/audit/collector.py" "$@"
