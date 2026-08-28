#!/usr/bin/env bash
set -euo pipefail

allowed_owners="${1:-}"
repository_file="${2:-}"
excluded_names="${3:-}"
now_epoch="${4:-}"

if [ -z "$allowed_owners" ] || [ ! -s "$repository_file" ] || ! [[ "$now_epoch" =~ ^[0-9]+$ ]]; then
    echo "E2E cleanup candidate inputs are incomplete" >&2
    exit 1
fi

cutoff_epoch=$((now_epoch - 90 * 24 * 60 * 60))
jq -e \
    --arg allowed_owners "$allowed_owners" \
    --arg excluded_names "$excluded_names" \
    --argjson cutoff_epoch "$cutoff_epoch" '
    (.owner.login | ascii_downcase) as $owner |
    .name as $name |
    ($allowed_owners | split(",") | map(gsub("^\\s+|\\s+$"; "") | ascii_downcase)) as $owners |
    ($excluded_names | split(",") | map(gsub("^\\s+|\\s+$"; "") | ascii_downcase)) as $excluded |
    ($name | test("^bootstrap-e2e-[0-9]+-[0-9]+-(micromamba|mise|system)-(embedded|centralized)-(create-repository|terraform-create-repository)$")) and
    ($owners | index($owner) != null) and
    ($excluded | index("\($owner)/\($name)" | ascii_downcase) == null) and
    (.visibility == "public") and
    (.archived == true) and
    (.topics | type == "array" and index("bootstrap-e2e") != null) and
    ((.updated_at | fromdateiso8601) <= $cutoff_epoch)
    ' "$repository_file" > /dev/null || {
    echo "E2E repository is not eligible for cleanup" >&2
    exit 1
}
