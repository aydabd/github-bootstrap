#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
validator="$repo_root/scripts/github-setup/validate-agent-closeout.sh"
template_validator="$repo_root/templates/.github/scripts/validate-agent-closeout.sh"
fixture="$(mktemp)"
invalid="$(mktemp)"
trap 'rm -f "$fixture" "$invalid"' EXIT

fail() {
    echo "agent closeout contract failure: $1" >&2
    exit 1
}

[ -x "$validator" ] || fail "missing executable root closeout validator"
[ -x "$template_validator" ] || fail "missing executable template closeout validator"
cmp -s "$validator" "$template_validator" || fail "root and template validators differ"

cat > "$fixture" << 'JSON'
{
    "schema_version": 1,
    "issue": {
        "number": 267,
        "state": "OPEN",
        "acceptance_complete": true,
        "project_item": true
    },
    "pull_request": {
        "number": 1,
        "state": "OPEN",
        "base": "main",
        "linked_issue": 267
    },
    "project": {
        "item_exists": true,
        "fields": {
            "Status": "In Progress",
            "Priority": "P1",
            "Target release": "Unscheduled",
            "Area": "Process",
            "Work type": "Story",
            "Risk": "Medium",
            "Effort": "M",
            "Parent issue": 280,
            "Sub-issues progress": "2/4"
        }
    },
    "validation": {
        "commands": ["bash scripts/run-contract-tests.sh"],
        "pass_count": 1,
        "fail_count": 0
    },
    "handoff": {
        "schema_version": 1,
        "main_sha": "0123456789abcdef0123456789abcdef01234567",
        "unresolved_failure_classes": []
    },
    "process_refinement": "Require the closeout validator before PR handoff."
}
JSON

result="$($validator --repository OWNER/repository --evidence-file "$fixture")" ||
    fail "complete evidence was rejected"
printf '%s\n' "$result" | jq -e '.schema_version == 1 and .result == "PASS" and .summary.failed == 0 and .summary.skipped == 0' > /dev/null ||
    fail "complete evidence did not produce a passing result"

jq 'del(.pull_request.linked_issue, .issue.number)' "$fixture" > "$invalid"
missing_link_result="$($validator --repository OWNER/repository --evidence-file "$invalid" || true)"
printf '%s\n' "$missing_link_result" | jq -e 'any(.checks[]; (.check | contains("linked-issue")) and .result == "FAIL")' > /dev/null ||
    fail "missing linked issue was not reported as a failed check"

jq 'del(.pull_request.base)' "$fixture" > "$invalid"
missing_base_result="$($validator --repository OWNER/repository --evidence-file "$invalid" || true)"
printf '%s\n' "$missing_base_result" | jq -e 'any(.checks[]; (.check | contains("pull-request-base")) and .result == "FAIL")' > /dev/null ||
    fail "missing pull request base was not reported as a failed check"

jq '.issue.acceptance_complete = false' "$fixture" > "$invalid"
stale_acceptance_result="$($validator --repository OWNER/repository --evidence-file "$invalid" || true)"
printf '%s\n' "$stale_acceptance_result" | jq -e 'any(.checks[]; (.check | contains("acceptance-complete")) and .result == "FAIL")' > /dev/null ||
    fail "incomplete acceptance evidence was not reported as a failed check"

jq 'del(.project.fields.Risk)' "$fixture" > "$invalid"
if "$validator" --repository OWNER/repository --evidence-file "$invalid" > /dev/null 2>&1; then
    fail "missing required Project field was accepted"
fi

jq '.validation.fail_count = 1' "$fixture" > "$invalid"
if "$validator" --repository OWNER/repository --evidence-file "$invalid" > /dev/null 2>&1; then
    fail "failed validation evidence was accepted"
fi

jq '.handoff.secret = "ghp_not-real"' "$fixture" > "$invalid"
if "$validator" --repository OWNER/repository --evidence-file "$invalid" > /dev/null 2>&1; then
    fail "credential-like handoff content was accepted"
fi

echo "Agent closeout contract checks passed."
