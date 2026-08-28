#!/usr/bin/env bash
set -euo pipefail

allowed_owner="${1:-}"
repository_full="${2:-}"
topics_file="${3:-}"

if [ -z "$allowed_owner" ] || [ -z "$repository_full" ] || [ ! -s "$topics_file" ]; then
    echo "E2E archive target inputs are incomplete" >&2
    exit 1
fi

target_owner="${repository_full%%/*}"
target_repository="${repository_full#*/}"
if [ "$target_owner" = "$repository_full" ] || [ "$target_repository" = "$repository_full" ] || [ "$target_owner" != "$allowed_owner" ]; then
    echo "E2E archive target owner is not allowed" >&2
    exit 1
fi
if ! [[ "$target_repository" =~ ^bootstrap-e2e-[0-9]+-[0-9]+-(micromamba|mise|system)-(embedded|centralized)-(create-repository|terraform-create-repository)$ ]]; then
    echo "E2E archive target name is not allowed" >&2
    exit 1
fi

jq -e '(.names | type == "array") and (.names | index("bootstrap-e2e") != null)' "$topics_file" > /dev/null || {
    echo "E2E archive target marker topic is missing" >&2
    exit 1
}
