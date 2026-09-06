#!/usr/bin/env bash
set -euo pipefail

config_dir="${1:?usage: scripts/regenerate-mise-lock.sh <config-dir> [mise-bin]}"
mise_bin="${2:-${MISE_BIN:-mise}}"

[ -f "$config_dir/mise.toml" ] || {
    echo "missing mise.toml in $config_dir" >&2
    exit 1
}
"$mise_bin" lock --cd "$config_dir" --platform linux-x64,macos-x64,macos-arm64 --yes
[ -f "$config_dir/mise.lock" ] || {
    echo "mise did not create $config_dir/mise.lock" >&2
    exit 1
}
