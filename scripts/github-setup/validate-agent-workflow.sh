#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: validate-agent-workflow.sh --repository OWNER/REPOSITORY" >&2
    exit 2
}

repository="local/repository"
while [ "$#" -gt 0 ]; do
    case "$1" in
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
manifest="$repo_root/templates/.github/config/agent-workflow.json"
checks=()

add_check() {
    local result="$1" check="$2" evidence="$3" error_code="${4:-}" remediation="${5:-}"
    checks+=("$(jq -cn --arg result "$result" --arg check "$check" --argjson evidence "$evidence" --arg error_code "$error_code" --arg remediation "$remediation" '{result:$result,check:$check,evidence:$evidence} + (if $error_code != "" then {error_code:$error_code} else {} end) + (if $remediation != "" then {remediation:$remediation} else {} end)')")
}

check_file() {
    local relative="$1"
    if [ -f "$repo_root/$relative" ]; then
        add_check PASS "file:$relative" '{"exists":true}'
    else
        add_check FAIL "file:$relative" '{"exists":false}' "MISSING_CONFIGURATION" "add the required generated workflow asset"
    fi
}

if [ ! -f "$manifest" ]; then
    add_check FAIL "manifest" '{"exists":false}' "MISSING_CONFIGURATION" "add templates/.github/config/agent-workflow.json"
else
    if jq -e '.schema_version == 1 and .required_plugins.superpowers.required == true' "$manifest" > /dev/null 2>&1; then
        add_check PASS "manifest" '{"schema_version":1,"superpowers_required":true}'
    else
        add_check FAIL "manifest" '{"schema_version":null,"superpowers_required":false}' "INVALID_CONFIGURATION" "declare the required Superpowers plugin in the manifest"
    fi
fi

check_file "templates/AGENTS.md"
check_file "templates/.github/instructions/project.instructions.md"
check_file "templates/.github/skills/agent-operating-loop/SKILL.md"
check_file "templates/.github/skills/backlog-breakdown/SKILL.md"
check_file "templates/.github/skills/roadmap-prioritization/SKILL.md"
check_file "templates/.github/skills/tracker-setup/SKILL.md"
check_file "templates/.github/skills/tracker-views/SKILL.md"

for template in epic.yml story.yml task.yml bug.yml security.yml config.yml; do
    check_file "templates/.github/ISSUE_TEMPLATE/$template"
done

if [ -d "$repo_root/templates/.github/ISSUE_TEMPLATE" ] &&
    find "$repo_root/templates/.github/ISSUE_TEMPLATE" -maxdepth 1 -type f -name '*.md' | grep -q .; then
    add_check FAIL "issue-templates:no-markdown" '{"markdown_files":true}' "UNSUPPORTED_CONFIGURATION" "use YAML issue forms instead of markdown planning templates"
else
    add_check PASS "issue-templates:no-markdown" '{"markdown_files":false}'
fi

if rg -n -i 'ghp_|gho_|ghr_|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|client_secret|refresh_token|bearer' \
    "$manifest" > /dev/null 2>&1; then
    add_check FAIL "manifest:no-secrets" '{"credential_like_values":true}' "SECRET_EXPOSURE" "remove credential material from the manifest"
else
    add_check PASS "manifest:no-secrets" '{"credential_like_values":false}'
fi

checks_json="$(printf '%s\n' "${checks[@]}" | jq -s '.')"
failed="$(printf '%s' "$checks_json" | jq '[.[] | select(.result == "FAIL")] | length')"
skipped="$(printf '%s' "$checks_json" | jq '[.[] | select(.result == "SKIP")] | length')"
passed="$(printf '%s' "$checks_json" | jq '[.[] | select(.result == "PASS")] | length')"
result=PASS
[ "$failed" -eq 0 ] && [ "$skipped" -eq 0 ] || result=FAIL

jq -cn \
    --arg repository "$repository" \
    --arg result "$result" \
    --argjson checks "$checks_json" \
    --argjson passed "$passed" \
    --argjson failed "$failed" \
    --argjson skipped "$skipped" \
    '{schema_version:1,result:$result,repository:$repository,checks:$checks,summary:{passed:$passed,failed:$failed,skipped:$skipped}}'

[ "$result" = PASS ]
