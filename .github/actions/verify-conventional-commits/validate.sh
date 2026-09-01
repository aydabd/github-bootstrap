#!/usr/bin/env bash
set -euo pipefail

commits_file="$(mktemp)"
messages_file="$(mktemp)"
export messages_file
trap 'rm -f "$commits_file" "$messages_file"' EXIT

gh api --paginate --slurp \
    "/repos/$REPOSITORY/pulls/$PR_NUMBER/commits?per_page=100" \
    > "$commits_file"
jq -e 'flatten | length > 0' "$commits_file" > /dev/null

# Trusted automation bots author machine-generated commits (for example
# Dependabot's grouped update bodies) whose long reference lines trip the stock
# Conventional Commits body rules even though their headlines are compliant. The
# signed-off-by check exempts the same identities.
jq -jr '
    ["github-actions[bot]", "repository-maintenance-writer[bot]", "dependabot[bot]"] as $trusted_bots
    | flatten[]
    | (.author.login? // "") as $login
    | select($trusted_bots | index($login) | not)
    | .commit.message,"\u0000"' "$commits_file" > "$messages_file"

if [ ! -s "$messages_file" ]; then
    echo "All pull-request commits are authored by a trusted automation bot; commitlint not applicable."
    exit 0
fi

if [ -n "$CONFIG_PATH" ]; then
    # shellcheck disable=SC2016
    mise x node@26.6.0 -- npm exec --yes \
        --package=@commitlint/cli@19.8.1 \
        --package=@commitlint/config-conventional@19.8.1 \
        -- bash -euo pipefail -c '
            while IFS= read -r -d "" message; do
                printf "%s\\n" "$message" | commitlint --config "$CONFIG_PATH"
            done < "$messages_file"
        '
else
    # shellcheck disable=SC2016
    mise x node@26.6.0 -- npm exec --yes \
        --package=@commitlint/cli@19.8.1 \
        --package=@commitlint/config-conventional@19.8.1 \
        -- bash -euo pipefail -c '
            package_root="$(cd "$(dirname "$(command -v commitlint)")/.." && pwd)"
            while IFS= read -r -d "" message; do
                printf "%s\\n" "$message" | commitlint --cwd "$package_root" --extends @commitlint/config-conventional
            done < "$messages_file"
        '
fi

echo "All pull-request commits follow the commitlint policy."
