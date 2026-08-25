#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2218
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/github-setup/gh-common.sh
source "$script_dir/gh-common.sh"

usage() {
    cat >&2 << 'EOF'
Usage:
    github-app-manifest.sh url [app-name] [redirect-url]
    github-app-manifest.sh convert CODE OUTPUT_DIRECTORY

The convert command writes GitHub's returned App private key and metadata to
0600 files in OUTPUT_DIRECTORY. It never prints credentials.
EOF
    exit 2
}

main() {
    command_name="${1:-}"
    case "$command_name" in
        url)
            require_command python3
            python3 - "${2:-github-bootstrap-personal-e2e}" "${3:-https://github.com/settings/apps/new}" << 'PY'
import json
import sys
import urllib.parse

app_name, redirect_url = sys.argv[1:]
manifest = {
    "name": app_name,
    "url": "https://github.com",
    "redirect_url": redirect_url,
    "public": False,
    "default_events": [],
    "default_permissions": {
        "administration": "write",
        "contents": "write",
        "issues": "write",
        "metadata": "read",
    },
}
encoded_manifest = urllib.parse.quote(json.dumps(manifest, separators=(",", ":")), safe="")
print(f"https://github.com/settings/apps/new?manifest={encoded_manifest}")
PY
            ;;
        convert)
            require_command curl
            require_command jq
            code="${2:-}"
            output_dir="${3:-}"
            [ -n "$code" ] && [ -n "$output_dir" ] || usage
            [[ "$code" =~ ^[A-Za-z0-9_-]+$ ]] || {
                echo "invalid App Manifest conversion code" >&2
                exit 1
            }
            mkdir -p "$output_dir"
            chmod 700 "$output_dir"
            response_file="$(mktemp "$output_dir/response.XXXXXX")"
            trap 'rm -f "$response_file"' EXIT
            chmod 600 "$response_file"
            curl --fail --silent --show-error --location \
                --header 'Accept: application/vnd.github+json' \
                --header 'Content-Type: application/json' \
                --data '{}' \
                "https://api.github.com/app-manifests/$code/conversions" > "$response_file"
            jq -e '.pem | type == "string" and length > 0' "$response_file" > /dev/null
            jq -e '.client_id | type == "string" and length > 0' "$response_file" > /dev/null
            jq -e '.client_secret | type == "string" and length > 0' "$response_file" > /dev/null
            jq -r '.pem' "$response_file" > "$output_dir/app-private-key.pem"
            jq -j '.client_id' "$response_file" > "$output_dir/app-client-id"
            jq -j '.client_secret' "$response_file" > "$output_dir/app-client-secret"
            chmod 600 "$output_dir/app-private-key.pem" "$output_dir/app-client-id" "$output_dir/app-client-secret"
            printf 'GitHub App conversion completed; protected metadata written under %s\n' "$output_dir"
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
