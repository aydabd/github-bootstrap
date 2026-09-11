#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: verify-agent-project.sh (--metadata-file FILE | --project OWNER/NUMBER) --repository OWNER/REPOSITORY" >&2
    exit 2
}

metadata_file=""
project=""
repository=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --metadata-file | --project | --repository)
            [ "$#" -ge 2 ] || usage
            case "$1" in
                --metadata-file) metadata_file="$2" ;;
                --project) project="$2" ;;
                --repository) repository="$2" ;;
            esac
            shift 2
            ;;
        *) usage ;;
    esac
done

[ -n "$repository" ] || usage
[ -n "$metadata_file" ] || [ -n "$project" ] || usage
[ -z "$metadata_file" ] || [ -z "$project" ] || usage

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
manifest="$repo_root/templates/.github/config/agent-workflow.json"
checks=()

add_check() {
    local result="$1" check="$2" evidence="$3" error_code="${4:-}" remediation="${5:-}"
    checks+=("$(jq -cn --arg result "$result" --arg check "$check" --argjson evidence "$evidence" --arg error_code "$error_code" --arg remediation "$remediation" '{result:$result,check:$check,evidence:$evidence} + (if $error_code != "" then {error_code:$error_code} else {} end) + (if $remediation != "" then {remediation:$remediation} else {} end)')")
}

if [ -n "$metadata_file" ]; then
    metadata="$(cat "$metadata_file")"
else
    owner="${project%/*}"
    number="${project#*/}"
    [[ "$owner" != "$project" && "$number" =~ ^[0-9]+$ ]] || usage
    fields_json="$(gh project field-list "$number" --owner "$owner" --limit 100 --format json)"
    query="query(\$owner:String!,\$number:Int!){user(login:\$owner){projectV2(number:\$number){views(first:20){nodes{name layout filter}}}}organization(login:\$owner){projectV2(number:\$number){views(first:20){nodes{name layout filter}}}}}"
    views_json="$(gh api graphql -f query="$query" -f owner="$owner" -F number="$number" | jq -c '.data.user.projectV2.views.nodes // .data.organization.projectV2.views.nodes // []')"
    metadata="$(jq -cn --argjson fields "$(jq -c '.fields' <<< "$fields_json")" --argjson views "$views_json" '{fields:$fields,views:$views}')"
fi

if ! jq -e '.fields | type == "array"' <<< "$metadata" > /dev/null 2>&1 ||
    ! jq -e '.views | type == "array"' <<< "$metadata" > /dev/null 2>&1; then
    add_check FAIL "project-metadata" '{"valid":false}' "INVALID_PROJECT_DATA" "provide Project field and view metadata"
else
    while IFS=$'\t' read -r field _ options; do
        field_json="$(jq -c --arg name "$field" '.fields[] | select(.name == $name)' <<< "$metadata" | head -n 1)"
        if [ -z "$field_json" ]; then
            add_check FAIL "field:$field" '{"exists":false}' "MISSING_PROJECT_FIELD" "create or configure the required Project field"
            continue
        fi
        missing="$(jq -cn --argjson field "$field_json" --argjson required "$options" '$required - (($field.options // []) | map(if type == "object" then .name else . end))')"
        if [ "$(jq 'length' <<< "$missing")" -eq 0 ]; then
            add_check PASS "field:$field" "$(jq -cn --argjson field "$field_json" '{exists:true,options:(($field.options // []) | map(if type == "object" then .name else . end))}')"
        else
            add_check FAIL "field:$field" "$(jq -cn --arg missing "$missing" '{exists:true,missing_options:$missing}')" "INVALID_PROJECT_FIELD" "add the missing canonical Project field options"
        fi
    done < <(jq -r '.project.fields[] | [.name, (.required | tostring), ((.options // []) | tojson)] | @tsv' "$manifest")

    while IFS=$'\t' read -r view layout; do
        view_json="$(jq -c --arg name "$view" '.views[] | select(.name == $name)' <<< "$metadata" | head -n 1)"
        if [ -z "$view_json" ]; then
            add_check FAIL "view:$view" '{"exists":false}' "MISSING_PROJECT_VIEW" "create the required Project view"
        else
            add_check PASS "view:$view" "$(jq -cn --argjson view "$view_json" --arg layout "$layout" '{exists:true,layout:$layout,configured_layout:($view.layout // null)}')"
        fi
    done < <(jq -r '.project.views[] | [.name, .layout] | @tsv' "$manifest")
fi

checks_json="$(printf '%s\n' "${checks[@]}" | jq -s '.')"
failed="$(jq '[.[] | select(.result == "FAIL")] | length' <<< "$checks_json")"
skipped="$(jq '[.[] | select(.result == "SKIP")] | length' <<< "$checks_json")"
passed="$(jq '[.[] | select(.result == "PASS")] | length' <<< "$checks_json")"
result=PASS
[ "$failed" -eq 0 ] && [ "$skipped" -eq 0 ] || result=FAIL

jq -cn --arg repository "$repository" --arg result "$result" --argjson checks "$checks_json" \
    --argjson passed "$passed" --argjson failed "$failed" --argjson skipped "$skipped" \
    '{schema_version:1,result:$result,repository:$repository,checks:$checks,summary:{passed:$passed,failed:$failed,skipped:$skipped}}'
[ "$result" = PASS ]
