#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
selector="$script_dir/select-next-work.sh"
fixture="$(mktemp)"
trap 'rm -f "$fixture"' EXIT

cat > "$fixture" << 'JSON'
{"items":[
    {"number":10,"title":"Low priority feature","status":"Spec Ready","priority":"P4","area":"Templates","work_type":"Story","parent_issue":null,"labels":[]},
    {"number":11,"title":"Security gate","status":"Spec Ready","priority":"P2","area":"Security","work_type":"Task","parent_issue":null,"labels":["security"]},
    {"number":12,"title":"Blocked work","status":"Blocked-Needs-Human","priority":"P0","area":"CI","work_type":"Task","parent_issue":null,"labels":[]},
    {"number":13,"title":"In progress structural fix","status":"In Progress","priority":"P3","area":"Repository","work_type":"Task","parent_issue":null,"labels":[]}
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
