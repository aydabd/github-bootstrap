#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/github-app-manifest.sh"

[ -x "$helper" ] || {
    echo "manifest helper is not executable" >&2
    exit 1
}
grep -Fq "source \"\$script_dir/gh-common.sh\"" "$helper"

grep -Fq '"administration": "write"' "$helper"
grep -Fq '"contents": "write"' "$helper"
grep -Fq '"issues": "write"' "$helper"
grep -Fq '"metadata": "read"' "$helper"
if grep -Fq 'organization-administration' "$helper"; then
    echo "personal manifest must not request organization administration" >&2
    exit 1
fi
grep -Fq 'app-manifests' "$helper"
grep -Fq 'umask 077' "$helper"
grep -Fq 'chmod 600' "$helper"
grep -Fq 'private key' "$helper"
grep -Fq "jq -j '.client_id'" "$helper"
grep -Fq "jq -j '.client_secret'" "$helper"
manifest_url="$("$helper" url 'name" injection' $'https://example.test/callback\nsecond')"
MANIFEST_URL="$manifest_url" python3 - << 'PY'
import json
import os
import urllib.parse

manifest = json.loads(urllib.parse.parse_qs(urllib.parse.urlsplit(os.environ["MANIFEST_URL"]).query)["manifest"][0])
assert manifest["name"] == 'name" injection'
assert manifest["redirect_url"] == "https://example.test/callback\nsecond"
assert manifest["default_permissions"] == {
    "administration": "write",
    "contents": "write",
    "issues": "write",
    "metadata": "read",
}
PY
if grep -Eq 'echo.*(pem|client_secret|private_key)' "$helper"; then
    echo "manifest helper must not print credentials" >&2
    exit 1
fi

echo "GitHub App Manifest contract checks passed."
