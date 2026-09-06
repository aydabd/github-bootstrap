#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <environment.yml> <conda-lock.yml> <platform>" >&2
    exit 2
}

[ "$#" -eq 3 ] || usage
environment_file=$1
lock_file=$2
platform=$3

case "$platform" in
    linux-64 | osx-64 | osx-arm64) ;;
    *)
        echo "unsupported conda platform: $platform" >&2
        exit 2
        ;;
esac

grep -Eq '^name: *[^"{][^[:space:]]*|^name: *"?[A-Za-z0-9_.-]+"?$' "$environment_file" || {
    echo "environment file must have a concrete name before locking: $environment_file" >&2
    exit 1
}
if grep -Eq '\{\{[A-Z0-9_]+\}\}' "$environment_file"; then
    echo "environment file still contains template placeholders: $environment_file" >&2
    exit 1
fi

mkdir -p "$(dirname "$lock_file")"
lock_command=(uvx --from conda-lock==4.0.2 conda-lock lock --no-mamba --file "$environment_file" --platform "$platform")
if [[ "$platform" == osx-* ]]; then
    lock_command+=(--virtual-package-spec conda-lock-virtual-packages.yml)
fi
set +e
"${lock_command[@]}" --lockfile "$lock_file" --strip-auth
lock_rc=$?
set -e

# conda-lock 4.0.2 can return non-zero after writing a valid lock when mamba
# rejects its synthetic virtual-package record. Never accept the file blindly:
# mamba must still parse and validate the complete lockfile.
if [ "$lock_rc" -ne 0 ]; then
    [ -s "$lock_file" ] || {
        echo "conda-lock failed without producing $lock_file" >&2
        exit "$lock_rc"
    }
    mamba_bin="$(command -v micromamba || command -v mamba)"
    "$mamba_bin" create --dry-run --json -n conda-lock-validation -f "$lock_file" > /dev/null
    grep -Fq "platform: $platform" "$lock_file" || {
        echo "conda-lock output is missing platform $platform" >&2
        exit 1
    }
fi
