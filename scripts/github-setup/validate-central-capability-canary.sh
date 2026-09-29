#!/usr/bin/env bash
set -euo pipefail
usage() { echo "Usage: validate-central-capability-canary.sh --evidence-file FILE" >&2; exit 2; }
evidence_file=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --evidence-file) [ "$#" -ge 2 ] || usage; evidence_file="$2"; shift 2 ;;
        *) usage ;;
    esac
done
[ -n "$evidence_file" ] || usage
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$root/templates/centralized-actions-workflows/.github/centralized-workflows.json"
check() { jq -e "$1" "$evidence_file" >/dev/null 2>&1; }
jq -e . "$evidence_file" >/dev/null 2>&1 || { jq -n '{schema_version:1,result:"FAIL"}'; exit 1; }
check '.schema_version == 1 and .issue == 357 and .operator_gate == true' || exit 1
check '.validation.exact_head_shas | type == "array" and length > 0 and all(.[]; test("^[0-9a-fA-F]{40}$"))' || exit 1
check '.validation.approval_actor | type == "string" and length > 0' || exit 1
check '.validation.merge_actor | type == "string" and length > 0' || exit 1
check '.validation.ruleset_state == "enforced"' || exit 1
check '.validation.cleanup.performed == false and .validation.cleanup.owner_confirmation_required == true' || exit 1
check '.rollback.bootstrap_runtime_ref | type == "string" and length > 0' || exit 1
if jq -e 'tostring | test("refresh.?token|private.?key|client.?secret|bearer"; "i")' "$evidence_file" >/dev/null 2>&1; then exit 1; fi
jq -e '
    ([.capabilities | keys[]] | sort) == ["maintenance-merge","maintenance-safety","release-please","weekly-tooling-updates"] and
    all(.capabilities[]; .enabled_by_default == false and .status == "available") and
    all(.runtime.roles[]; .token_mode == "installation" and .ruleset_bypass == false)
' "$manifest" >/dev/null
jq -n '{schema_version:1,result:"PASS"}'
