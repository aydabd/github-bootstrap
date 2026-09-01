#!/usr/bin/env bash
set -euo pipefail

pr_file="${1:-}"
full_repository="${FULL_REPOSITORY:-}"
# release-please runs under the Maintenance Writer App (see release-please.yml),
# so its release PR is authored by "<writer-app-slug>[bot]" rather than
# "release-please[bot]". Accept that identity too when it carries the
# "autorelease: pending" label.
writer_app_slug="${WRITER_APP_SLUG:-}"

if [ -z "$pr_file" ] || [ ! -s "$pr_file" ] || [ -z "$full_repository" ]; then
    echo "maintenance PR validation inputs are incomplete" >&2
    exit 1
fi

classification="$(jq -r \
    --arg full_repository "$full_repository" \
    --arg writer_bot "${writer_app_slug:+${writer_app_slug}[bot]}" '
    if .state != "open" then ""
    elif .draft == true then ""
    elif .base.ref != "main" then ""
    elif .base.repo.full_name != $full_repository or .head.repo.full_name != $full_repository then ""
    elif .user.login == "dependabot[bot]" then "dependabot"
    elif (.user.login == "release-please[bot]"
            or .user.login == "github-actions[bot]"
            or ($writer_bot != "" and .user.login == $writer_bot)) and
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
