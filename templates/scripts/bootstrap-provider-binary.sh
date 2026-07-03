#!/usr/bin/env bash
set -euo pipefail

provider="${1:-}"
target_path="${2:-}"

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

url=""
sha256=""

case "$provider:$os:$arch" in
    mise:linux:x64)
        url="https://github.com/jdx/mise/releases/download/v2026.7.0/mise-v2026.7.0-linux-x64"
        sha256="0744cb3c303baf0d308ff7b112ed41f22abb6029cb5644fd3a8ce74b29f16a68"
        ;;
    mise:linux:arm64)
        url="https://github.com/jdx/mise/releases/download/v2026.7.0/mise-v2026.7.0-linux-arm64"
        sha256="50d3752baf2d6542bf7b8cff1146e0fd9517531c74171b93a1e4b63dcd2d64e8"
        ;;
    mise:macos:x64)
        url="https://github.com/jdx/mise/releases/download/v2026.7.0/mise-v2026.7.0-macos-x64"
        sha256="c0debad068ea3e1e525d6580168e0be4759295cdd9049b6ab1aac37d90e952de"
        ;;
    mise:macos:arm64)
        url="https://github.com/jdx/mise/releases/download/v2026.7.0/mise-v2026.7.0-macos-arm64"
        sha256="cc5a708f75e9a84e007a650c23b127e79e54aacf0e41378d75bb15795e9ed54d"
        ;;

    micromamba:linux:x64)
        url="https://github.com/mamba-org/micromamba-releases/releases/download/2.8.1-0/micromamba-linux-64"
        sha256="9689782d863c05a1bf5d2d371ba527104e7a4eb4310c1637d8653b751aed9c82"
        ;;
    micromamba:linux:arm64)
        url="https://github.com/mamba-org/micromamba-releases/releases/download/2.8.1-0/micromamba-linux-aarch64"
        sha256="e5ba23b5945aa49dfd11022e592a510d2686a8feee810e00140b73c9fdf0ba2a"
        ;;
    micromamba:macos:x64)
        url="https://github.com/mamba-org/micromamba-releases/releases/download/2.8.1-0/micromamba-osx-64"
        sha256="b2bd613791c0a524883d7cb66505d630bf15badd1f492bc93ba78550a3a1a94b"
        ;;
    micromamba:macos:arm64)
        url="https://github.com/mamba-org/micromamba-releases/releases/download/2.8.1-0/micromamba-osx-arm64"
        sha256="de71a646b73af92dd663e6ddc78993a6a4d47ea28b5d8908c3cc2b9c3077e528"
        ;;
    *)
        echo "Unsupported provider/OS/arch combination: $provider:$os:$arch" >&2
        exit 1
        ;;
esac

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
