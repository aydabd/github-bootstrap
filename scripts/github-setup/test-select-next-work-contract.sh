#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
selector="$script_dir/select-next-work.sh"
fixture="$(mktemp)"
trap 'rm -f "$fixture"' EXIT

fail() {
    echo "next-work selection contract failure: $1" >&2
    exit 1
}

cat > "$fixture" << 'JSON'
{"items":[
    {"number":10,"title":"Low priority feature","status":"Spec Ready","priority":"P4","target_release":"Unscheduled","area":"Templates","work_type":"Story","risk":"Low","effort":"S","parent_issue":20,"sub_issues_progress":"0/0","labels":[]},
    {"number":11,"title":"Security gate","status":"Spec Ready","priority":"P2","target_release":"Production readiness (v1)","area":"Security","work_type":"Task","risk":"High","effort":"M","parent_issue":20,"sub_issues_progress":"0/0","labels":["security"]},
    {"number":12,"title":"Blocked work","status":"Blocked-Needs-Human","priority":"P0","target_release":"Unscheduled","area":"CI","work_type":"Task","risk":"Medium","effort":"S","parent_issue":20,"sub_issues_progress":"0/0","labels":[]},
    {"number":13,"title":"In progress structural fix","status":"In Progress","priority":"P3","target_release":"Unscheduled","area":"Repository","work_type":"Task","risk":"Medium","effort":"S","parent_issue":20,"sub_issues_progress":"0/0","labels":[]}
]}
JSON

result="$($selector --items-file "$fixture" --repository OWNER/repository)"
printf '%s\n' "$result" | jq -e '
    .schema_version == 1 and
    .result == "PASS" and
    .selection.number == 11 and
    (.candidates | length) == 3 and
    (.candidates | map(select(.number == 12)) | length) == 0 and
    .parallelization.result == "REVIEW_REQUIRED" and
    (.summary.selected == 1)
' > /dev/null

echo "Next-work selection contract checks passed."

cat > "$fixture" << 'JSON'
{"items":[
    {"number":20,"title":"Epic","status":"In Progress","priority":"P1","target_release":"Production readiness (v1)","area":"Process","work_type":"Epic","risk":"High","effort":"L","parent_issue":null,"sub_issues_progress":"0/1","labels":[]},
    {"number":21,"title":"Untracked child","status":"Spec Ready","priority":"P1","target_release":"Production readiness (v1)","area":"Process","work_type":"Story","risk":"High","effort":"M","parent_issue":null,"sub_issues_progress":"0/0","labels":[]}
]}
JSON

if "$selector" --items-file "$fixture" --repository OWNER/repository > /dev/null; then
    fail "selector accepted an actionable child without a parent issue"
fi

echo "Next-work metadata guard contract checks passed."

cat > "$fixture" << 'JSON'
{"items":[
    {"number":30,"title":"Closed stale item","status":"In Progress","priority":"P1","target_release":"Production readiness (v1)","area":"Process","work_type":"Task","risk":"High","effort":"S","parent_issue":20,"sub_issues_progress":"0/0","issue_state":"CLOSED","labels":[]}
]}
JSON

if "$selector" --items-file "$fixture" --repository OWNER/repository > /dev/null; then
    fail "selector accepted a closed issue with an active Project status"
fi

echo "Next-work issue-state guard contract checks passed."
