#!/usr/bin/env bash
set -euo pipefail

provider="${1:-}"
target_path="${2:-}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manifest_path="${script_dir}/provider-assets.txt"

if [[ -z "$provider" || -z "$target_path" ]]; then
    echo "Usage: scripts/bootstrap-provider-binary.sh <mise|micromamba> <target-path>" >&2
    exit 1
fi

os_name="$(uname -s)"
arch_name="$(uname -m)"

case "$os_name" in
    Linux) os="linux" ;;
    Darwin) os="macos" ;;
    *)
        echo "Unsupported OS: $os_name" >&2
        exit 1
        ;;
esac

case "$arch_name" in
    x86_64 | amd64) arch="x64" ;;
    arm64 | aarch64) arch="arm64" ;;
    *)
        echo "Unsupported architecture: $arch_name" >&2
        exit 1
        ;;
esac

if [[ ! -f "$manifest_path" ]]; then
    echo "Missing provider asset manifest: $manifest_path" >&2
    exit 1
fi

if ! command -v awk > /dev/null 2>&1; then
    echo "Missing required tool: awk" >&2
    exit 1
fi

if ! asset_line="$(awk -v provider="$provider" -v os="$os" -v arch="$arch" '
    /^[[:space:]]*#/ || NF == 0 { next }
    $1 == provider && $2 == os && $3 == arch { print $4, $5; found = 1; exit }
    END { if (!found) exit 1 }
' "$manifest_path")"; then
    echo "Unsupported provider/OS/arch combination: $provider:$os:$arch" >&2
    exit 1
fi

read -r url sha256 <<< "$asset_line"

if [[ -z "$url" || -z "$sha256" ]]; then
    echo "Malformed provider asset entry for: $provider:$os:$arch" >&2
    exit 1
fi

mkdir -p "$(dirname "$target_path")"

work_file="${target_path}.download"
trap 'rm -f "$work_file"' EXIT

if ! command -v curl > /dev/null 2>&1; then
    echo "Missing required tool: curl" >&2
    exit 1
fi

curl --connect-timeout 15 --max-time 300 -fsSL "$url" -o "$work_file"

if command -v shasum > /dev/null 2>&1; then
    actual_sha256="$(shasum -a 256 "$work_file" | awk '{print $1}')"
elif command -v sha256sum > /dev/null 2>&1; then
    actual_sha256="$(sha256sum "$work_file" | awk '{print $1}')"
else
    echo "Missing checksum utility: install shasum or sha256sum" >&2
    exit 1
fi

if [[ "$actual_sha256" != "$sha256" ]]; then
    echo "Checksum mismatch for $provider binary" >&2
    echo "Expected: $sha256" >&2
    echo "Actual:   $actual_sha256" >&2
    exit 1
fi

mv "$work_file" "$target_path"
chmod +x "$target_path"

echo "Installed verified $provider binary: $target_path"
