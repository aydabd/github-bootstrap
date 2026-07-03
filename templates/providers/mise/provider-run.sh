#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MISE_BIN="$ROOT_DIR/.provider/bin/mise"

if [[ ! -x "$MISE_BIN" ]]; then
    bash "$ROOT_DIR/scripts/bootstrap-provider-binary.sh" mise "$MISE_BIN"
fi

"$MISE_BIN" exec -- "$@"
