#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/github-app-manifest.sh"
manifest_dir="$(cd "$script_dir/../../docs/github-app-manifests" 2> /dev/null && pwd)"
trust_boundary_doc="$manifest_dir/../github-app-trust-boundaries.md"

[ -x "$helper" ] || {
    echo "manifest helper is not executable" >&2
    exit 1
}
grep -Fq "source \"\$script_dir/gh-common.sh\"" "$helper"

grep -Fq 'app-manifests' "$helper"
grep -Fq 'start ROLE' "$helper"
grep -Fq 'url ROLE' "$helper"
grep -Fq 'umask 077' "$helper"
grep -Fq 'chmod 600' "$helper"
grep -Fq 'private key' "$helper"
grep -Fq "jq -j '.client_id'" "$helper"
grep -Fq "jq -j '.client_secret'" "$helper"
manifest_url="$("$helper" url repository-bootstrap-provisioner $'https://example.test/callback\nsecond')"
MANIFEST_URL="$manifest_url" python3 - << 'PY'
import json
import os
import urllib.parse

manifest = json.loads(urllib.parse.parse_qs(urllib.parse.urlsplit(os.environ["MANIFEST_URL"]).query)["manifest"][0])
assert manifest["name"] == "Repository Bootstrap Provisioner"
assert manifest["redirect_url"] == "https://example.test/callback\nsecond"
assert manifest["default_permissions"] == {
    "administration": "write",
    "contents": "write",
    "issues": "write",
    "metadata": "read",
}
PY

writer_manifest_url="$($helper start repository-maintenance-writer 'https://example.test/callback')"
MANIFEST_URL="$writer_manifest_url" python3 - << 'PY'
import json
import os
import urllib.parse

manifest = json.loads(urllib.parse.parse_qs(urllib.parse.urlsplit(os.environ["MANIFEST_URL"]).query)["manifest"][0])
assert manifest["name"] == "Repository Maintenance Writer"
assert manifest["redirect_url"] == "https://example.test/callback"
assert manifest["default_permissions"] == {
    "contents": "write",
    "metadata": "read",
    "pull_requests": "write",
}
PY
if grep -Eq 'echo.*(pem|client_secret|private_key)' "$helper"; then
    echo "manifest helper must not print credentials" >&2
    exit 1
fi

MANIFEST_DIR="$manifest_dir" python3 - << 'PY'
import json
import os
from pathlib import Path

manifest_dir = Path(os.environ["MANIFEST_DIR"])
expected = {
    "bootstrap-e2e-admin.json": {
        "name": "Bootstrap E2E Admin",
        "default_permissions": {
            "administration": "write",
            "metadata": "read",
            "organization_administration": "write",
        },
    },
    "repository-bootstrap-provisioner.json": {
        "name": "Repository Bootstrap Provisioner",
        "default_permissions": {
            "administration": "write",
            "contents": "write",
            "issues": "write",
            "metadata": "read",
        },
    },
    "repository-maintenance-writer.json": {
        "name": "Repository Maintenance Writer",
        "default_permissions": {
            "contents": "write",
            "metadata": "read",
            "pull_requests": "write",
        },
    },
    "repository-maintenance-reviewer.json": {
        "name": "Repository Maintenance Reviewer",
        "default_permissions": {
            "actions": "write",
            "metadata": "read",
            "pull_requests": "write",
        },
    },
}

assert set(path.name for path in manifest_dir.glob("*.json")) == set(expected)
for filename, contract in expected.items():
    payload = json.loads((manifest_dir / filename).read_text())
    assert payload["name"] == contract["name"]
    assert payload["default_permissions"] == contract["default_permissions"]
    assert payload["default_events"] == []
    assert payload["public"] is False
    assert "bypass_actors" not in payload
    assert "deletion" not in payload["default_permissions"]
    assert "workflows" not in payload["default_permissions"]
PY

for required_text in \
    "Bootstrap E2E Admin" \
    "Repository Bootstrap Provisioner" \
    "Repository Maintenance Writer" \
    "Repository Maintenance Reviewer" \
    "No App is a ruleset bypass actor" \
    "\`administration: write\` permission includes repository deletion capability" \
    "must never delete arbitrary or" \
    "BOOTSTRAP_APP_PRIVATE_KEY" \
    "E2E"; do
    grep -Fq "$required_text" "$trust_boundary_doc" || {
        echo "expected '$required_text' in $trust_boundary_doc" >&2
        exit 1
    }
done

echo "GitHub App Manifest contract checks passed."
