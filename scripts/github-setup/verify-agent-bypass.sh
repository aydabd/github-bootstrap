#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
python_bin="$repo_root/.venv/bin/python"

[ -x "$python_bin" ] || {
    printf '{"result":"FAIL","error_code":"AUDIT_GOVERNANCE_TOOL_UNAVAILABLE"}\n'
    exit 1
}
exec "$python_bin" "$repo_root/templates/.github/config/audit/bypass_governance.py" "$@"
