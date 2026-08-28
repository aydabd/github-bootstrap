#!/usr/bin/env bash
set -euo pipefail

requested_sha="${1:-}"
run_file="${2:-}"

if ! [[ "$requested_sha" =~ ^[0-9a-fA-F]{40}$ ]] || [ ! -s "$run_file" ]; then
    echo "generated E2E head validation inputs are incomplete" >&2
    exit 1
fi

jq -e --arg requested_sha "$requested_sha" '(.head_sha // .headSha) == $requested_sha' "$run_file" > /dev/null || {
    echo "generated E2E run head SHA does not match requested SHA" >&2
    exit 1
}
