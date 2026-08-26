#!/usr/bin/env bash
set -euo pipefail

if [ -n "$CONFIG_PATH" ]; then
    printf '%s\n' "$TITLE" | mise x node@26.6.0 -- npm exec --yes \
        --package=@commitlint/cli@19.8.1 \
        --package=@commitlint/config-conventional@19.8.1 \
        -- commitlint --config "$CONFIG_PATH"
else
    # shellcheck disable=SC2016
    mise x node@26.6.0 -- npm exec --yes \
        --package=@commitlint/cli@19.8.1 \
        --package=@commitlint/config-conventional@19.8.1 \
        -- bash -euo pipefail -c '
            package_root="$(cd "$(dirname "$(command -v commitlint)")/.." && pwd)"
            printf "%s\\n" "$TITLE" | commitlint --cwd "$package_root" --extends @commitlint/config-conventional
        '
fi

echo "Pull-request title follows the commitlint policy."
