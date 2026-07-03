#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MICROMAMBA_BIN="$ROOT_DIR/.provider/bin/micromamba"

if [[ ! -x "$MICROMAMBA_BIN" ]]; then
    bash "$ROOT_DIR/scripts/bootstrap-provider-binary.sh" micromamba "$MICROMAMBA_BIN"
fi

"$MICROMAMBA_BIN" run -n "{{REPOSITORY_NAME}}" -- "$@"
