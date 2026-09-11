#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/github-setup/gh-common.sh
source "$script_dir/gh-common.sh"

usage() {
    cat >&2 << 'EOF'
Usage: install-e2e-maintenance-credentials.sh OWNER/github-bootstrap WRITER_DIR REVIEWER_DIR FIXTURE_DIR
EOF
    exit 2
}

[ "$#" -eq 4 ] || usage
repo="$1"
writer_dir="$2"
reviewer_dir="$3"
fixture_dir="$4"
[ -n "${GH_TOKEN:-}" ] || {
    echo "GH_TOKEN must be set before installing E2E maintenance credentials" >&2
    exit 1
}
require_command gh

owner_pattern='[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?'
[[ "$repo" =~ ^${owner_pattern}/github-bootstrap$ ]] || {
    echo "repository must be OWNER/github-bootstrap" >&2
    exit 1
}

require_protected_file() {
    local path="$1" label="$2" mode
    if [ ! -f "$path" ] || [ -L "$path" ]; then
        echo "$label must be a regular file: $path" >&2
        exit 1
    fi
    mode="$(stat -f '%Lp' "$path" 2> /dev/null || stat -c '%a' "$path")"
    [ "$mode" = 600 ] || {
        echo "$label must have mode 600: $path" >&2
        exit 1
    }
}

require_credential_dir() {
    local dir="$1" role="$2"
    if [ ! -d "$dir" ] || [ -L "$dir" ]; then
        echo "$role credential directory must be a real directory: $dir" >&2
        exit 1
    fi
    local mode
    mode="$(stat -f '%Lp' "$dir" 2> /dev/null || stat -c '%a' "$dir")"
    [ "$mode" = 700 ] || {
        echo "$role credential directory must have mode 700: $dir" >&2
        exit 1
    }
    require_protected_file "$dir/app-client-id" "$role client ID file"
    require_protected_file "$dir/app-slug" "$role App slug file"
    require_protected_file "$dir/app-private-key.pem" "$role private key file"
}

require_credential_dir "$writer_dir" Writer
require_credential_dir "$reviewer_dir" Reviewer
require_credential_dir "$fixture_dir" Fixture
require_protected_file "$fixture_dir/app-client-secret" "Fixture App client secret file"
require_protected_file "$fixture_dir/app-user-refresh-token" "Fixture App refresh token file"

for credential_file in "$writer_dir/app-client-id" "$writer_dir/app-slug" \
    "$reviewer_dir/app-client-id" "$reviewer_dir/app-slug" \
    "$fixture_dir/app-client-id" "$fixture_dir/app-client-secret" \
    "$fixture_dir/app-user-refresh-token"; do
    [ -s "$credential_file" ] || {
        echo "credential file is empty: $credential_file" >&2
        exit 1
    }
done

GH_TOKEN="$GH_TOKEN" bash "$script_dir/install-app-secrets.sh" \
    "$repo" e2e-maintenance-writer \
    "$writer_dir/app-client-id" "$writer_dir/app-slug" \
    "$writer_dir/app-private-key.pem"
GH_TOKEN="$GH_TOKEN" bash "$script_dir/install-app-secrets.sh" \
    "$repo" e2e-maintenance-reviewer \
    "$reviewer_dir/app-client-id" "$reviewer_dir/app-slug" \
    "$reviewer_dir/app-private-key.pem"
GH_TOKEN="$GH_TOKEN" bash "$script_dir/install-app-secrets.sh" \
    "$repo" e2e-maintenance-fixture \
    "$fixture_dir/app-client-id" "$fixture_dir/app-slug" \
    "$fixture_dir/app-private-key.pem" "$fixture_dir/app-client-secret" \
    "$fixture_dir/app-user-refresh-token"
printf 'Installed E2E maintenance Writer, Reviewer, and fixture App credentials for %s\n' "$repo"
