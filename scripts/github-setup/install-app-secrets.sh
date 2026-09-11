#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2218
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/github-setup/gh-common.sh
source "$script_dir/gh-common.sh"

usage() {
    cat >&2 << 'EOF'
Usage: install-app-secrets.sh REPOSITORY PROFILE CLIENT_ID_FILE PRIVATE_KEY_FILE CLIENT_SECRET_FILE REFRESH_TOKEN_FILE
    install-app-secrets.sh REPOSITORY E2E_MAINTENANCE_PROFILE CLIENT_ID_FILE APP_SLUG_FILE PRIVATE_KEY_FILE
    install-app-secrets.sh REPOSITORY e2e-maintenance-fixture CLIENT_ID_FILE APP_SLUG_FILE PRIVATE_KEY_FILE CLIENT_SECRET_FILE REFRESH_TOKEN_FILE

Installs the GitHub App client ID as an environment variable and the
GitHub-generated private key, App client secret, and ghr_-prefixed App refresh
token as environment secrets for the selected profile. The refresh token is
exchanged by workflows at runtime.
EOF
    exit 2
}

repo="${1:-}"
profile="${2:-}"
client_id_file="${3:-}"
[ "$#" -eq 5 ] || [ "$#" -eq 6 ] || [ "$#" -eq 7 ] || usage
if [ -z "${GH_TOKEN:-}" ]; then
    echo "GH_TOKEN must be set before installing App secrets" >&2
    exit 1
fi
profile_loader="$script_dir/app-credential-profile.sh"
client_id_variable="$("$profile_loader" "$profile" client_id_variable)"
private_key_secret="$("$profile_loader" "$profile" private_key_secret)"
environment="$("$profile_loader" "$profile" environment)"
require_command gh
owner_pattern='[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?'
[[ "$repo" =~ ^${owner_pattern}/[A-Za-z0-9._-]+$ ]] || {
    echo "repository must match OWNER/REPOSITORY" >&2
    exit 1
}
require_file "$client_id_file" "client ID file"
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
require_protected_file "$client_id_file" "client ID file"
if [ "$#" -eq 5 ]; then
    case "$profile" in
        e2e-maintenance-writer | e2e-maintenance-reviewer | e2e-maintenance-fixture) ;;
        *)
            echo "five-file installation requires an E2E maintenance profile" >&2
            exit 1
            ;;
    esac
    app_slug_file="${4:-}"
    private_key_file="${5:-}"
    app_slug_variable="$("$profile_loader" "$profile" app_slug_variable)"
    require_protected_file "$app_slug_file" "App slug file"
    require_protected_file "$private_key_file" "private key file"
    client_id="$(tr -d '\r\n' < "$client_id_file")"
    app_slug="$(tr -d '\r\n' < "$app_slug_file")"
    [ -n "$client_id" ] || {
        echo "client ID file is empty" >&2
        exit 1
    }
    [ -n "$app_slug" ] || {
        echo "App slug file is empty" >&2
        exit 1
    }
    pem_first_line="$(sed -n '1p' "$private_key_file" | tr -d '\r')"
    pem_last_line="$(sed '/^[[:space:]]*$/d' "$private_key_file" | tail -n 1 | tr -d '\r')"
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
    sanitized_private_key_file="$(mktemp)"
    chmod 600 "$sanitized_private_key_file"
    trap 'rm -f "$sanitized_private_key_file"' EXIT
    tr -d '\r' < "$private_key_file" > "$sanitized_private_key_file"
    printf '::add-mask::%s\n' "$app_slug"
    printf '::add-mask::%s\n' "$client_id"
    GH_TOKEN="$GH_TOKEN" gh variable set "$client_id_variable" --repo "$repo" --env "$environment" --body "$client_id"
    GH_TOKEN="$GH_TOKEN" gh variable set "$app_slug_variable" --repo "$repo" --env "$environment" --body "$app_slug"
    GH_TOKEN="$GH_TOKEN" gh secret set "$private_key_secret" --repo "$repo" --env "$environment" < "$sanitized_private_key_file"
    printf 'Installed E2E maintenance App credentials for %s\n' "$repo"
    exit 0
fi
if [ "$#" -eq 7 ]; then
    [ "$profile" = e2e-maintenance-fixture ] || {
        echo "seven-file installation requires the E2E maintenance fixture profile" >&2
        exit 1
    }
    app_slug_file="$4"
    private_key_file="$5"
    client_secret_file="$6"
    refresh_token_file="$7"
    app_slug_variable="$($profile_loader "$profile" app_slug_variable)"
    client_secret_secret="$($profile_loader "$profile" client_secret_secret)"
    refresh_token_secret="$($profile_loader "$profile" refresh_token_secret)"
    require_protected_file "$app_slug_file" "App slug file"
    require_protected_file "$private_key_file" "private key file"
    require_protected_file "$client_secret_file" "client secret file"
    require_protected_file "$refresh_token_file" "refresh token file"
    client_id="$(tr -d '\r\n' < "$client_id_file")"
    app_slug="$(tr -d '\r\n' < "$app_slug_file")"
    refresh_token="$(tr -d '\r\n' < "$refresh_token_file")"
    if [ -z "$client_id" ] || [ -z "$app_slug" ]; then
        echo "fixture App identity file is empty" >&2
        exit 1
    fi
    case "$refresh_token" in
        ghr_*) ;;
        *)
            echo "refresh token file must contain a GitHub App refresh token with ghr_ prefix" >&2
            exit 1
            ;;
    esac
    sanitized_private_key_file="$(mktemp)"
    sanitized_client_secret_file="$(mktemp)"
    sanitized_refresh_token_file="$(mktemp)"
    chmod 600 "$sanitized_private_key_file" "$sanitized_client_secret_file" "$sanitized_refresh_token_file"
    trap 'rm -f "$sanitized_private_key_file" "$sanitized_client_secret_file" "$sanitized_refresh_token_file"' EXIT
    tr -d '\r' < "$private_key_file" > "$sanitized_private_key_file"
    tr -d '\r\n' < "$client_secret_file" > "$sanitized_client_secret_file"
    printf '%s' "$refresh_token" > "$sanitized_refresh_token_file"
    GH_TOKEN="$GH_TOKEN" gh variable set "$client_id_variable" --repo "$repo" --env "$environment" --body "$client_id"
    GH_TOKEN="$GH_TOKEN" gh variable set "$app_slug_variable" --repo "$repo" --env "$environment" --body "$app_slug"
    GH_TOKEN="$GH_TOKEN" gh secret set "$private_key_secret" --repo "$repo" --env "$environment" < "$sanitized_private_key_file"
    GH_TOKEN="$GH_TOKEN" gh secret set "$client_secret_secret" --repo "$repo" --env "$environment" < "$sanitized_client_secret_file"
    GH_TOKEN="$GH_TOKEN" gh secret set "$refresh_token_secret" --repo "$repo" --env "$environment" < "$sanitized_refresh_token_file"
    printf 'Installed E2E maintenance fixture App credentials for %s\n' "$repo"
    exit 0
fi
private_key_file="${4:-}"
client_secret_file="${5:-}"
refresh_token_file="${6:-}"
client_secret_secret="$("$profile_loader" "$profile" client_secret_secret)"
refresh_token_secret="$("$profile_loader" "$profile" refresh_token_secret)"
require_protected_file "$private_key_file" "private key file"
require_protected_file "$client_secret_file" "client secret file"
require_protected_file "$refresh_token_file" "refresh token file"

pem_first_line="$(sed -n '1p' "$private_key_file" | tr -d '\r')"
pem_last_line="$(sed '/^[[:space:]]*$/d' "$private_key_file" | tail -n 1 | tr -d '\r')"
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
[ -n "$client_id" ] || {
    echo "client ID file is empty" >&2
    exit 1
}
refresh_token="$(tr -d '\r\n' < "$refresh_token_file")"
case "$refresh_token" in
    ghr_*) ;;
    *)
        echo "refresh token file must contain a GitHub App refresh token with ghr_ prefix" >&2
        exit 1
        ;;
esac

sanitized_private_key_file="$(mktemp)"
chmod 600 "$sanitized_private_key_file"
sanitized_client_secret_file="$(mktemp)"
chmod 600 "$sanitized_client_secret_file"
sanitized_token_file="$(mktemp)"
chmod 600 "$sanitized_token_file"
trap 'rm -f "$sanitized_private_key_file" "$sanitized_client_secret_file" "$sanitized_token_file"' EXIT
tr -d '\r' < "$private_key_file" > "$sanitized_private_key_file"
tr -d '\r\n' < "$client_secret_file" > "$sanitized_client_secret_file"
printf '%s' "$refresh_token" > "$sanitized_token_file"

GH_TOKEN="$GH_TOKEN" gh variable set "$client_id_variable" --repo "$repo" --env "$environment" --body "$client_id"
GH_TOKEN="$GH_TOKEN" gh secret set "$private_key_secret" --repo "$repo" --env "$environment" < "$sanitized_private_key_file"
GH_TOKEN="$GH_TOKEN" gh secret set "$client_secret_secret" --repo "$repo" --env "$environment" < "$sanitized_client_secret_file"
GH_TOKEN="$GH_TOKEN" gh secret set "$refresh_token_secret" --repo "$repo" --env "$environment" < "$sanitized_token_file"
printf 'Installed App client ID configuration and three protected App credentials for %s\n' "$repo"
