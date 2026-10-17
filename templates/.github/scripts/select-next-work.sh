#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: select-next-work.sh (--items-file FILE | --project OWNER/NUMBER) --repository OWNER/REPOSITORY" >&2
    exit 2
}

items_file=""
project=""
repository=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --items-file)
            [ "$#" -ge 2 ] || usage
            items_file="$2"
            shift 2
            ;;
        --project)
            [ "$#" -ge 2 ] || usage
            project="$2"
            shift 2
            ;;
        --repository)
            [ "$#" -ge 2 ] || usage
            repository="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$repository" ] || usage
[ -n "$items_file" ] || [ -n "$project" ] || usage
[ -z "$items_file" ] || [ -z "$project" ] || usage

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
if [ -f "$repo_root/templates/.github/config/agent-workflow.json" ]; then
    manifest="$repo_root/templates/.github/config/agent-workflow.json"
else
    manifest="$repo_root/.github/config/agent-workflow.json"
fi
policy="$(jq -c '.selection' "$manifest")"

if [ -n "$items_file" ]; then
    items_json="$(cat "$items_file")"
else
    owner="${project%/*}"
    number="${project#*/}"
    [[ "$owner" != "$project" && "$number" =~ ^[0-9]+$ ]] || usage
    items_json="$(gh project item-list "$number" --owner "$owner" --limit 200 --format json)"

    enriched_items="$(mktemp)"
    trap 'rm -f "$enriched_items"' EXIT
    printf '%s' "$items_json" | jq -c '.items[]' | while IFS= read -r item; do
        issue_number="$(printf '%s' "$item" | jq -r '.content.number // .number')"
        issue_data="$(gh issue view "$issue_number" --repo "$repository" --json state,parent,subIssuesSummary)"
        printf '%s' "$item" | jq -c --argjson issue_data "$issue_data" '
            . + {
                issue_state: $issue_data.state,
                parent_issue: ($issue_data.parent.number // null),
                sub_issues_progress: (
                    ($issue_data.subIssuesSummary.completed // 0 | tostring) + "/" +
                    ($issue_data.subIssuesSummary.total // 0 | tostring)
                )
            }
        ' >> "$enriched_items"
    done
    items_json="$(jq -cn --slurpfile items "$enriched_items" '{items:$items}')"
fi

if ! printf '%s' "$items_json" | jq -e '.items | type == "array"' > /dev/null 2>&1; then
    jq -cn --arg repository "$repository" \
        '{schema_version:1,result:"FAIL",repository:$repository,checks:[{result:"FAIL",check:"project-items",evidence:{valid:false},error_code:"INVALID_PROJECT_DATA",remediation:"provide GitHub Project JSON with an items array"}],summary:{passed:0,failed:1,skipped:0}}'
    exit 1
fi

items_json="$(printf '%s' "$items_json" | jq -c '
    {
        items: [
            .items[] | {
                number: (.number // .content.number),
                title: (.title // .content.title),
                issue_state: (.issue_state // "OPEN"),
                status,
                priority,
                target_release: (.target_release // .["target release"]),
                area,
                work_type: (.work_type // .["work type"]),
                risk,
                effort,
                parent_issue: (.parent_issue // .["parent issue"]),
                sub_issues_progress: (.sub_issues_progress // .["sub-issues progress"]),
                labels
            }
        ]
    }
')"

invalid_items="$(printf '%s' "$items_json" | jq -c --argjson policy "$policy" '
    def missing_fields:
        ([
            {name:"status", value:.status},
            {name:"priority", value:.priority},
            {name:"target_release", value:.target_release},
            {name:"area", value:.area},
            {name:"work_type", value:.work_type},
            {name:"risk", value:.risk},
            {name:"effort", value:.effort},
            {name:"sub_issues_progress", value:.sub_issues_progress}
        ] | map(select(.value == null or .value == "") | .name)) +
        (if .work_type != "Epic" and (.parent_issue == null or .parent_issue == "")
            then ["parent_issue"] else [] end) +
        (if .issue_state == "CLOSED" and .status != "Done"
            then ["status_not_done_for_closed_issue"] else [] end);
    [.items[]
        | .status as $status
        | select((($policy.actionable_statuses + $policy.blocked_statuses) | index($status)) != null)
        | {number, title, status, missing: missing_fields}
        | select((.missing | length) > 0)
    ]
')"

if [ "$(printf '%s' "$invalid_items" | jq 'length')" -gt 0 ]; then
    jq -cn \
        --arg repository "$repository" \
        --argjson invalid "$invalid_items" \
        '{schema_version:1,result:"FAIL",repository:$repository,checks:[{result:"FAIL",check:"project-tracking",evidence:{invalid_items:$invalid},error_code:"INCOMPLETE_PROJECT_TRACKING",remediation:"populate every required Project field and establish parent links before selecting work"}],summary:{passed:0,failed:1,skipped:0}}'
    exit 1
fi

candidates="$(printf '%s' "$items_json" | jq -c --argjson policy "$policy" '
    def priority_rank: .priority as $priority | ($policy.priority_order | index($priority)) // 99;
    def status_rank: .status as $status | (["In Progress", "Spec Ready"] | index($status)) // 99;
    def security_rank:
        (.labels // []) as $labels
        | if any($labels[]; . as $label | ($policy.security_labels | index($label)) != null) then 0 else 1 end;
    [.items[]
        | .status as $status
        | select(.issue_state == "OPEN")
        | select(($policy.actionable_statuses | index($status)) != null)
        | {number, title, status, priority, target_release, area, work_type, risk, effort, parent_issue, sub_issues_progress, labels}
        | . + {rank: [security_rank, priority_rank, status_rank, (.number // 999999)]}
    ] | sort_by(.rank) | map(del(.rank))
')"

candidate_count="$(printf '%s' "$candidates" | jq 'length')"
if [ "$candidate_count" -eq 0 ]; then
    jq -cn --arg repository "$repository" \
        '{schema_version:1,result:"PASS",repository:$repository,selection:null,candidates:[],parallelization:{result:"NOT_APPLICABLE",reason:"no actionable issues"},summary:{selected:0,candidates:0,failed:0,skipped:0}}'
    exit 0
fi

selection="$(printf '%s' "$candidates" | jq '.[0]')"
if [ "$candidate_count" -gt 1 ]; then
    parallel_result="REVIEW_REQUIRED"
    parallel_reason="check issue dependencies and actual file or module overlap before parallel execution"
else
    parallel_result="NOT_APPLICABLE"
    parallel_reason="only one actionable issue"
fi

jq -cn \
    --arg repository "$repository" \
    --argjson selection "$selection" \
    --argjson candidates "$candidates" \
    --arg parallel_result "$parallel_result" \
    --arg parallel_reason "$parallel_reason" \
    '{schema_version:1,result:"PASS",repository:$repository,selection:$selection,candidates:$candidates,parallelization:{result:$parallel_result,reason:$parallel_reason},summary:{selected:1,candidates:($candidates|length),failed:0,skipped:0}}'
