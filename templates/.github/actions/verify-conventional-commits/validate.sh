#!/usr/bin/env bash
set -euo pipefail

commits_file="$(mktemp)"
trap 'rm -f "$commits_file" "$messages_file"' EXIT
gh api --paginate --slurp \
    "/repos/$REPOSITORY/pulls/$PR_NUMBER/commits?per_page=100" \
    > "$commits_file"
jq -e 'flatten | length > 0' "$commits_file" > /dev/null

messages_file="$(mktemp)"
export messages_file
trap 'rm -f "$messages_file"' EXIT
jq -jr 'flatten[] | .commit.message, "\u0000"' "$commits_file" > "$messages_file"

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
