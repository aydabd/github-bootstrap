#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: validate-agent-closeout.sh --repository OWNER/REPOSITORY --evidence-file FILE" >&2
    exit 2
}

repository=""
evidence_file=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --repository | --evidence-file)
            [ "$#" -ge 2 ] || usage
            if [ "$1" = "--repository" ]; then repository="$2"; else evidence_file="$2"; fi
            shift 2
            ;;
        *) usage ;;
    esac
done

if [ -z "$repository" ] || [ -z "$evidence_file" ]; then
    usage
fi
[[ "$repository" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9][A-Za-z0-9._-]{0,99}$ ]] || usage

checks=()
add_check() {
    local result="$1" check="$2" evidence="$3" error_code="${4:-}" remediation="${5:-}"
    checks+=("$(jq -cn --arg result "$result" --arg check "$check" --argjson evidence "$evidence" \
        --arg error_code "$error_code" --arg remediation "$remediation" \
        '{result:$result,check:$check,evidence:$evidence} +
        (if $error_code != "" then {error_code:$error_code} else {} end) +
        (if $remediation != "" then {remediation:$remediation} else {} end)')")
}

if ! evidence="$(cat "$evidence_file" 2> /dev/null)" || ! jq -e . > /dev/null 2>&1 <<< "$evidence"; then
    add_check FAIL "evidence:json" '{"valid":false}' "MALFORMED_EVIDENCE" "provide valid JSON evidence"
else
    if jq -e '.schema_version == 1' <<< "$evidence" > /dev/null; then
        add_check PASS "evidence:schema" '{"schema_version":1}'
    else
        add_check FAIL "evidence:schema" '{"schema_version":null}' "INVALID_EVIDENCE_SCHEMA" "set schema_version to 1"
    fi

    for path in \
        '.issue.number | type == "number" and . > 0' \
        '.issue.acceptance_complete == true' \
        '.issue.project_item == true' \
        '.pull_request.number | type == "number" and . > 0' \
        '.pull_request.base | type == "string" and length > 0' \
        '(.pull_request.linked_issue | type == "number") and (.issue.number | type == "number") and .pull_request.linked_issue == .issue.number' \
        '.project.item_exists == true' \
        '.project.fields | type == "object"' \
        '.validation.commands | type == "array" and length > 0' \
        '.validation.pass_count | type == "number" and . > 0' \
        '.validation.fail_count == 0' \
        '.handoff.schema_version == 1' \
        '.handoff.main_sha | type == "string" and test("^[0-9a-fA-F]{40}$")' \
        '.handoff.unresolved_failure_classes | type == "array" and length == 0' \
        '.process_refinement | type == "string" and length > 0'; do
        if jq -e "$path" <<< "$evidence" > /dev/null 2>&1; then
            add_check PASS "evidence:$(printf '%s' "$path" | sed 's/[^A-Za-z0-9]/-/g')" '{"valid":true}'
        else
            add_check FAIL "evidence:$(printf '%s' "$path" | sed 's/[^A-Za-z0-9]/-/g')" '{"valid":false}' "MISSING_CLOSEOUT_EVIDENCE" "provide the required evidence field"
        fi
    done

    for field in "Status" "Priority" "Target release" "Area" "Work type" "Risk" "Effort" "Parent issue" "Sub-issues progress"; do
        if jq -e --arg field "$field" '.project.fields | has($field) and .[$field] != null and .[$field] != ""' <<< "$evidence" > /dev/null 2>&1; then
            add_check PASS "project-field:$field" '{"present":true}'
        else
            add_check FAIL "project-field:$field" '{"present":false}' "MISSING_PROJECT_FIELD" "provide the Project field value from the live Project"
        fi
    done

    if printf '%s' "$evidence" | grep -Eiq 'gh[opr]_|private[_ -]?key|client[_ -]?secret|refresh[_ -]?token|bearer'; then
        add_check FAIL "handoff:privacy" '{"credential_like_values":true}' "CREDENTIAL_LIKE_OUTPUT" "remove credential-like values from handoff evidence"
    else
        add_check PASS "handoff:privacy" '{"credential_like_values":false}'
    fi
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
