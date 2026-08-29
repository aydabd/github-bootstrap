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
    github-app-manifest.sh url ROLE [redirect-url]
    github-app-manifest.sh start ROLE [redirect-url]
    github-app-manifest.sh convert CODE OUTPUT_DIRECTORY

The start command prints a temporary local URL for a POST form that submits
the checked-in role manifest to GitHub without printing credentials.
The convert command writes GitHub's returned App private key and metadata to
0600 files in OUTPUT_DIRECTORY. It never prints credentials.
EOF
    exit 2
}

main() {
    command_name="${1:-}"
    case "$command_name" in
        url | start)
            require_command python3
            role="${2:-}"
            redirect_url="${3:-https://github.com/settings/apps/new}"
            case "$role" in
                bootstrap-e2e-admin | repository-bootstrap-provisioner | repository-maintenance-writer | repository-maintenance-reviewer) ;;
                *)
                    echo "unsupported App manifest role: ${role:-missing}" >&2
                    exit 2
                    ;;
            esac
            manifest_file="$script_dir/../../docs/github-app-manifests/$role.json"
            [ -f "$manifest_file" ] || {
                echo "missing App manifest: $manifest_file" >&2
                exit 1
            }
            if [ "$command_name" = "start" ]; then
                python3 - "$manifest_file" "$redirect_url" << 'PY'
import html
import json
import pathlib
import secrets
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

manifest_path, redirect_url = sys.argv[1:]
manifest = json.loads(pathlib.Path(manifest_path).read_text())
manifest["redirect_url"] = redirect_url
manifest_json = json.dumps(manifest, separators=(",", ":"))
manifest_script = manifest_json.replace("<", "\\u003c")
state = secrets.token_urlsafe(24)


class ManifestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/":
            self.send_error(404)
            return
        body = f'''<!doctype html>
<html><body>
<form method="post" action="https://github.com/settings/apps/new?state={state}">
<label for="manifest">GitHub App Manifest</label>
<input type="text" name="manifest" id="manifest">
<input type="submit" value="Continue to GitHub">
</form>
<script>
const input = document.getElementById("manifest");
input.value = JSON.stringify({manifest_script});
</script></body></html>'''.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        threading.Thread(target=self.server.shutdown, daemon=True).start()

    def log_message(self, format, *args):
        pass


server = HTTPServer(("127.0.0.1", 0), ManifestHandler)
print(f"http://127.0.0.1:{server.server_port}/", flush=True)
server.serve_forever()
PY
            else
                python3 - "$manifest_file" "$redirect_url" << 'PY'
import json
import pathlib
import sys
import urllib.parse

manifest_path, redirect_url = sys.argv[1:]
manifest = json.loads(pathlib.Path(manifest_path).read_text())
manifest["redirect_url"] = redirect_url
encoded_manifest = urllib.parse.quote(json.dumps(manifest, separators=(",", ":")), safe="")
print(f"https://github.com/settings/apps/new?manifest={encoded_manifest}")
PY
            fi
            ;;
        convert)
            require_command curl
            require_command jq
            code="${2:-}"
            output_dir="${3:-}"
            if [ -z "$code" ] || [ -z "$output_dir" ]; then
                usage
            fi
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
