#!/usr/bin/env bash
set -euo pipefail

pr_file="${1:-}"
full_repository="${FULL_REPOSITORY:-}"

if [ -z "$pr_file" ] || [ ! -s "$pr_file" ] || [ -z "$full_repository" ]; then
    echo "maintenance PR validation inputs are incomplete" >&2
    exit 1
fi

classification="$(jq -r --arg full_repository "$full_repository" '
    if .state != "open" then ""
    elif .draft == true then ""
    elif .base.ref != "main" then ""
    elif .base.repo.full_name != $full_repository or .head.repo.full_name != $full_repository then ""
    elif .user.login == "dependabot[bot]" then "dependabot"
    elif (.user.login == "release-please[bot]" or .user.login == "github-actions[bot]") and
        any(.labels[]?; .name == "autorelease: pending") then "release-please"
    else ""
    end
' "$pr_file")"

case "$classification" in
    dependabot | release-please)
        printf '%s\n' "$classification"
        ;;
    *)
        echo "pull request is not an eligible maintenance automation PR" >&2
        exit 1
        ;;
esac
