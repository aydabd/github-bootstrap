#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
profile_loader="$script_dir/app-credential-profile.sh"

usage() {
    echo "Usage: validate-central-app-installation.sh CENTRAL_ROLE OWNER/REPOSITORY [FORBIDDEN_OWNER/REPOSITORY ...]" >&2
    exit 2
}

fail_usage() {
    echo "$1" >&2
    usage
}

role="${1:-}"
repository="${2:-}"
[ "$#" -ge 2 ] || usage
[[ "$role" == central-* ]] || fail_usage "role must be a central runtime role"
[ -x "$profile_loader" ] || {
    echo "credential profile helper is not executable" >&2
    exit 1
}
owner_pattern='[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?'
repository_pattern="^${owner_pattern}/[A-Za-z0-9._-]+$"
[[ "$repository" =~ $repository_pattern ]] || fail_usage "repository must match OWNER/REPOSITORY"
BOOTSTRAP_APP_OWNER="${repository%%/*}" "$profile_loader" "$role" environment > /dev/null || exit 1

forbidden_repositories=()
for forbidden_repository in "${@:3}"; do
    [[ "$forbidden_repository" =~ $repository_pattern ]] ||
        fail_usage "forbidden repository must match OWNER/REPOSITORY"
    [ "$forbidden_repository" != "$repository" ] ||
        fail_usage "forbidden repository must differ from the target"
    forbidden_repositories+=("$forbidden_repository")
done

if [ -z "${GH_TOKEN:-}" ]; then
    echo "GH_TOKEN must be set to an operator-supplied installation token" >&2
    exit 1
fi

response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT
if ! gh api --paginate --slurp /installation/repositories > "$response_file"; then
    jq -cn --arg role "$role" --arg repository "$repository" \
        '{schema_version:1,result:"FAIL",role:$role,repository:$repository,forbidden_repositories:[],checks:[{result:"FAIL",check:"installation-repositories",error_code:"API_REQUEST_FAILED"}],summary:{passed:0,failed:1,skipped:0}}'
    exit 1
fi

repositories_json="$(jq -c '
    if type == "array" then
        [.[].repositories[]?.full_name]
    else
        [.repositories[]?.full_name]
    end | unique | sort
' "$response_file")"

target_visible=false
if jq -e --arg repository "$repository" 'index($repository) != null' <<< "$repositories_json" > /dev/null; then
    target_visible=true
fi

forbidden_json='[]'
if [ "${#forbidden_repositories[@]}" -gt 0 ]; then
    forbidden_json="$(printf '%s\n' "${forbidden_repositories[@]}" | jq -R . | jq -s .)"
fi
missing_forbidden_json="$(jq -c --argjson forbidden "$forbidden_json" --argjson visible "$repositories_json" \
    '[.[] as $repository | select(($visible | index($repository)) != null)]' <<< "$forbidden_json")"
checks='[]'
result="PASS"
if [ "$target_visible" = true ]; then
    checks="$(jq -c '. + [{result:"PASS",check:"target-visible"}]' <<< "$checks")"
else
    result="FAIL"
    checks="$(jq -c '. + [{result:"FAIL",check:"target-visible",error_code:"TARGET_NOT_VISIBLE"}]' <<< "$checks")"
fi
if [ "$(jq 'length' <<< "$missing_forbidden_json")" -eq 0 ]; then
    checks="$(jq -c '. + [{result:"PASS",check:"forbidden-repositories-hidden"}]' <<< "$checks")"
else
    result="FAIL"
    checks="$(jq -c '. + [{result:"FAIL",check:"forbidden-repositories-hidden",error_code:"FORBIDDEN_REPOSITORY_VISIBLE"}]' <<< "$checks")"
fi

jq -cn --arg result "$result" --arg role "$role" --arg repository "$repository" \
    --argjson forbidden "$forbidden_json" \
    --argjson checks "$checks" \
    '{schema_version:1,result:$result,role:$role,repository:$repository,forbidden_repositories:$forbidden,checks:$checks,summary:{passed:($checks|map(select(.result=="PASS"))|length),failed:($checks|map(select(.result=="FAIL"))|length),skipped:0}}'
[ "$result" = PASS ]
