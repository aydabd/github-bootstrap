#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MICROMAMBA_BIN="$ROOT_DIR/.provider/bin/micromamba"

if [[ $# -eq 0 ]]; then
    echo "Usage: scripts/provider-run.sh <command> [args...]" >&2
    exit 1
fi

if [[ ! -x "$MICROMAMBA_BIN" ]]; then
    bash "$ROOT_DIR/scripts/bootstrap-provider-binary.sh" micromamba "$MICROMAMBA_BIN"
fi

"$MICROMAMBA_BIN" run -n "{{REPOSITORY_NAME}}" -- "$@"
