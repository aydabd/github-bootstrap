#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
verifier="$script_dir/verify-agent-project.sh"
fixture="$(mktemp)"
trap 'rm -f "$fixture"' EXIT

cat > "$fixture" << 'JSON'
{"fields":[
    {"name":"Status","options":[{"name":"Backlog"},{"name":"Spec Needed"},{"name":"Spec Ready"},{"name":"In Progress"},{"name":"Blocked-Needs-Human"},{"name":"Done"}]},
    {"name":"Priority","options":[{"name":"P0"},{"name":"P1"},{"name":"P2"},{"name":"P3"},{"name":"P4"}]},
    {"name":"Target release","options":[{"name":"Unscheduled"}]},
    {"name":"Area","options":[{"name":"Process"},{"name":"Security"},{"name":"Repository"},{"name":"CI"},{"name":"Templates"},{"name":"Tooling"}]},
    {"name":"Work type","options":[{"name":"Epic"},{"name":"Story"},{"name":"Task"},{"name":"Bug"},{"name":"Security"},{"name":"Research"},{"name":"Maintenance"}]},
    {"name":"Risk","options":[{"name":"Low"},{"name":"Medium"},{"name":"High"}]},
    {"name":"Effort","options":[{"name":"XS"},{"name":"S"},{"name":"M"},{"name":"L"},{"name":"XL"}]},
    {"name":"Parent issue"},{"name":"Sub-issues progress"}
],"views":[
    {"name":"Roadmap"},{"name":"Ready to work"},{"name":"Epics"},{"name":"By release"}
]}
JSON

result="$($verifier --metadata-file "$fixture" --repository OWNER/repository)"
printf '%s\n' "$result" | jq -e '
    .schema_version == 1 and
    .result == "PASS" and
    .summary.failed == 0 and
    .summary.skipped == 0 and
    ([.checks[] | select(.result == "PASS")] | length) > 0
' > /dev/null

echo "Agent project verification contract checks passed."
