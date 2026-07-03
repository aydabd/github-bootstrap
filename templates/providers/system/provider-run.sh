#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "Usage: scripts/provider-run.sh <command> [args...]" >&2
    exit 1
fi

exec "$@"
