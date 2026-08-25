#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/github-setup/gh-common.sh
source "$script_dir/gh-common.sh"

usage() {
    cat >&2 << 'EOF'
Usage: install-app-secrets.sh REPOSITORY CLIENT_ID_FILE PRIVATE_KEY_FILE USER_TOKEN_FILE

Installs the GitHub-generated private key and ghu_-prefixed App user token as
repository secrets, and the client ID as a repository variable. The installer
verifies the token owner identity before writing any repository values.
EOF
    exit 2
}

repo="${1:-}"
client_id_file="${2:-}"
private_key_file="${3:-}"
user_token_file="${4:-}"
[ "$#" -eq 4 ] || usage
require_command gh
owner_pattern='[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?'
[[ "$repo" =~ ^${owner_pattern}/[A-Za-z0-9._-]+$ ]] || {
    echo "repository must match OWNER/REPOSITORY" >&2
    exit 1
}
require_file "$client_id_file" "client ID file"
require_file "$private_key_file" "private key file"
require_file "$user_token_file" "user token file"

pem_first_line="$(sed -n '1p' "$private_key_file" | tr -d '\r')"
pem_last_line="$(tail -n 1 "$private_key_file" | tr -d '\r')"
if [[ "$pem_first_line" =~ ^-----BEGIN\ ([A-Z0-9]+\ )?PRIVATE\ KEY-----$ ]]; then
    pem_label="${BASH_REMATCH[1]}"
    expected_pem_end="-----END ${pem_label}PRIVATE KEY-----"
else
    expected_pem_end=""
fi
if [ -z "$expected_pem_end" ] || [ "$pem_last_line" != "$expected_pem_end" ]; then
    echo "private key file is not a PEM private key returned by GitHub" >&2
    exit 1
fi
client_id="$(tr -d '\r\n' < "$client_id_file")"
token="$(tr -d '\r\n' < "$user_token_file")"
[ -n "$client_id" ] || {
    echo "client ID file is empty" >&2
    exit 1
}
case "$token" in
    ghu_*) ;;
    *)
        echo "user token file must contain a GitHub App user token with ghu_ prefix" >&2
        exit 1
        ;;
esac
repository_owner="${repo%%/*}"
authenticated_user="$(GH_TOKEN="$token" gh api /user --jq '.login')"
normalized_user="$(printf '%s' "$authenticated_user" | tr '[:upper:]' '[:lower:]')"
normalized_owner="$(printf '%s' "$repository_owner" | tr '[:upper:]' '[:lower:]')"
if [ "$normalized_user" != "$normalized_owner" ]; then
    echo "App user token identity does not match repository owner" >&2
    exit 1
fi

sanitized_private_key_file="$(mktemp)"
chmod 600 "$sanitized_private_key_file"
sanitized_token_file="$(mktemp)"
chmod 600 "$sanitized_token_file"
trap 'rm -f "$sanitized_private_key_file" "$sanitized_token_file"' EXIT
tr -d '\r' < "$private_key_file" > "$sanitized_private_key_file"
printf '%s' "$token" > "$sanitized_token_file"

gh variable set BOOTSTRAP_APP_CLIENT_ID --repo "$repo" --body "$client_id"
gh secret set BOOTSTRAP_APP_PRIVATE_KEY --repo "$repo" < "$sanitized_private_key_file"
gh secret set BOOTSTRAP_APP_USER_TOKEN --repo "$repo" < "$sanitized_token_file"
printf 'Installed App client ID configuration and two protected App credentials for %s\n' "$repo"
