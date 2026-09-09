#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2218
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/github-setup/gh-common.sh
source "$script_dir/gh-common.sh"

write_protected_token() {
    local token_value="$1"
    local output_path="$2"
    local output_dir
    local output_base
    local temporary_path

    output_dir="$(dirname "$output_path")"
    output_base="$(basename "$output_path")"
    if [ ! -d "$output_dir" ]; then
        echo "token output directory does not exist: $output_dir" >&2
        exit 1
    fi
    temporary_path="$(mktemp "$output_dir/.$output_base.XXXXXX")"
    chmod 600 "$temporary_path"
    if ! printf '%s' "$token_value" > "$temporary_path"; then
        rm -f "$temporary_path"
        exit 1
    fi
    if ! mv -f "$temporary_path" "$output_path"; then
        rm -f "$temporary_path"
        exit 1
    fi
}

usage() {
    cat >&2 << 'EOF'
Usage:
    github-app-user-token.sh url CLIENT_ID OWNER REDIRECT_URI STATE
    github-app-user-token.sh device-start CLIENT_ID RESPONSE_FILE
    github-app-user-token.sh device-poll CLIENT_ID RESPONSE_FILE OWNER ACCESS_TOKEN_FILE REFRESH_TOKEN_FILE
    APP_CLIENT_SECRET_FILE=... github-app-user-token.sh refresh CLIENT_ID REFRESH_TOKEN_FILE OWNER ACCESS_TOKEN_FILE REFRESH_TOKEN_FILE_OUT
    APP_CLIENT_SECRET_FILE=... APP_REDIRECT_URI=... github-app-user-token.sh exchange CLIENT_ID CODE OWNER ACCESS_TOKEN_FILE REFRESH_TOKEN_FILE
    APP_CLIENT_SECRET_FILE=... APP_REDIRECT_URI=... github-app-user-token.sh exchange-file CLIENT_ID CODE_FILE OWNER ACCESS_TOKEN_FILE REFRESH_TOKEN_FILE

The exchange commands verify the token's /user identity and write protected
access and refresh token files with mode 0600. Credentials are never printed.
EOF
    exit 2
}

refresh_token() {
    require_command curl
    require_command jq
    require_command gh
    client_id="${2:-}"
    refresh_token_file="${3:-}"
    owner="${4:-}"
    access_token_file="${5:-}"
    next_refresh_token_file="${6:-}"
    if [ -z "${APP_CLIENT_SECRET_FILE:-}" ] || [ ! -f "$APP_CLIENT_SECRET_FILE" ]; then
        echo "APP_CLIENT_SECRET_FILE must name a protected App client secret file" >&2
        exit 1
    fi
    if [ -z "$client_id" ] || [ ! -f "$refresh_token_file" ] || [ -z "$owner" ] ||
        [ -z "$access_token_file" ] || [ -z "$next_refresh_token_file" ]; then
        usage
    fi
    response_file="$(mktemp)"
    chmod 600 "$response_file"
    sanitized_secret_file="$(mktemp)"
    chmod 600 "$sanitized_secret_file"
    sanitized_refresh_file="$(mktemp)"
    chmod 600 "$sanitized_refresh_file"
    trap 'rm -f "$response_file" "$sanitized_secret_file" "$sanitized_refresh_file"' EXIT
    tr -d '\r\n' < "$APP_CLIENT_SECRET_FILE" > "$sanitized_secret_file"
    tr -d '\r\n' < "$refresh_token_file" > "$sanitized_refresh_file"
    [ -s "$sanitized_secret_file" ] || {
        echo "App client secret file is empty" >&2
        exit 1
    }
    case "$(cat "$sanitized_refresh_file")" in
        ghr_*) ;;
        *)
            echo "refresh token file must contain a GitHub App refresh token with ghr_ prefix" >&2
            exit 1
            ;;
    esac
    curl --fail --silent --show-error --location \
        --header 'Accept: application/json' \
        --data-urlencode "client_id=$client_id" \
        --data-urlencode "client_secret@$sanitized_secret_file" \
        --data-urlencode "grant_type=refresh_token" \
        --data-urlencode "refresh_token@$sanitized_refresh_file" \
        'https://github.com/login/oauth/access_token' > "$response_file"
    access_token="$(jq -er '.access_token // empty' "$response_file")"
    next_refresh_token="$(jq -er '.refresh_token // empty' "$response_file")"
    case "$access_token" in
        ghu_*) ;;
        *)
            echo "GitHub returned a non-App user access token; refusing to continue." >&2
            exit 1
            ;;
    esac
    case "$next_refresh_token" in
        ghr_*) ;;
        *)
            echo "GitHub returned a non-App refresh token; refusing to continue." >&2
            exit 1
            ;;
    esac
    verify_token_owner "$access_token" "$owner"
    write_protected_token "$access_token" "$access_token_file"
    write_protected_token "$next_refresh_token" "$next_refresh_token_file"
    printf 'Refreshed and verified GitHub App user token for %s; protected files updated.\n' "$owner"
}

device_start() {
    require_command curl
    require_command jq
    client_id="${2:-}"
    response_file="${3:-}"
    if [ -z "$client_id" ] || [ -z "$response_file" ]; then
        usage
    fi
    curl --fail --silent --show-error --location \
        --header 'Accept: application/json' \
        --data-urlencode "client_id=$client_id" \
        'https://github.com/login/device/code' > "$response_file"
    chmod 600 "$response_file"
    jq -e '.device_code and .user_code and .verification_uri' "$response_file" > /dev/null
    verification_uri="$(jq -r '.verification_uri' "$response_file")"
    user_code="$(jq -r '.user_code' "$response_file")"
    printf 'Open %s and enter user code %s. Protected device response: %s\n' \
        "$verification_uri" "$user_code" "$response_file"
}

verify_token_owner() {
    local token_value="$1"
    local expected_owner="$2"
    local authenticated_user
    local normalized_user
    local normalized_owner

    authenticated_user="$(GH_TOKEN="$token_value" gh api /user --jq '.login')"
    normalized_user="$(printf '%s' "$authenticated_user" | tr '[:upper:]' '[:lower:]')"
    normalized_owner="$(printf '%s' "$expected_owner" | tr '[:upper:]' '[:lower:]')"
    if [ "$normalized_user" != "$normalized_owner" ]; then
        echo "App user token identity does not match the requested personal owner." >&2
        return 1
    fi
}

device_poll() {
    require_command curl
    require_command jq
    require_command gh
    client_id="${2:-}"
    response_file="${3:-}"
    owner="${4:-}"
    token_file="${5:-}"
    refresh_token_file="${6:-}"
    if [ -z "$client_id" ] || [ ! -f "$response_file" ] || [ -z "$owner" ] || [ -z "$token_file" ] || [ -z "$refresh_token_file" ]; then
        usage
    fi
    device_code="$(jq -er '.device_code' "$response_file")"
    interval="$(jq -er '.interval // 5' "$response_file")"
    expires_in="$(jq -er '.expires_in // 900' "$response_file")"
    deadline=$(($(date +%s) + expires_in))
    poll_file="$(mktemp)"
    chmod 600 "$poll_file"
    trap 'rm -f "$poll_file"' EXIT
    while [ "$(date +%s)" -lt "$deadline" ]; do
        curl --fail --silent --show-error --location \
            --header 'Accept: application/json' \
            --data-urlencode "client_id=$client_id" \
            --data-urlencode "device_code=$device_code" \
            --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:device_code' \
            'https://github.com/login/oauth/access_token' > "$poll_file"
        if token="$(jq -er '.access_token // empty' "$poll_file")"; then
            case "$token" in
                ghu_*) ;;
                *)
                    echo "GitHub returned a non-App user token; refusing to continue." >&2
                    exit 1
                    ;;
            esac
            refresh_token_value="$(jq -er '.refresh_token // empty' "$poll_file")"
            case "$refresh_token_value" in
                ghr_*) ;;
                *)
                    echo "GitHub did not return an App refresh token; refusing to continue." >&2
                    exit 1
                    ;;
            esac
            verify_token_owner "$token" "$owner"
            write_protected_token "$token" "$token_file"
            write_protected_token "$refresh_token_value" "$refresh_token_file"
            printf 'Verified GitHub App user token for %s; protected access and refresh files updated.\n' "$owner"
            exit 0
        fi
        oauth_error="$(jq -r '.error // "missing_access_token"' "$poll_file")"
        case "$oauth_error" in
            authorization_pending) sleep "$interval" ;;
            slow_down)
                interval=$((interval + 5))
                sleep "$interval"
                ;;
            *)
                echo "GitHub device authorization failed: $oauth_error" >&2
                exit 1
                ;;
        esac
    done
    echo "GitHub device authorization expired before approval." >&2
    exit 1
}

print_url() {
    require_command python3
    client_id="${2:-}"
    owner="${3:-}"
    redirect_uri="${4:-}"
    state="${5:-}"
    if [ -z "$client_id" ] || [ -z "$owner" ] || [ -z "$redirect_uri" ] || [ -z "$state" ]; then
        usage
    fi
    python3 - "$client_id" "$owner" "$redirect_uri" "$state" << 'PY'
import sys
import urllib.parse

client_id, owner, redirect_uri, state = sys.argv[1:]
query = urllib.parse.urlencode({
    "client_id": client_id,
    "login": owner,
    "redirect_uri": redirect_uri,
    "state": state,
})
print(f"https://github.com/login/oauth/authorize?{query}")
PY
}

exchange_token() {
    command_name="$1"
    require_command curl
    require_command jq
    require_command gh
    client_id="${2:-}"
    code_or_file="${3:-}"
    owner="${4:-}"
    token_file="${5:-}"
    refresh_token_file="${6:-}"
    redirect_uri="${7:-${APP_REDIRECT_URI:-}}"
    if [ "$command_name" = exchange-file ] && [ ! -f "$code_or_file" ]; then
        echo "OAuth authorization code file is missing" >&2
        exit 1
    fi
    if [ -z "${APP_CLIENT_SECRET_FILE:-}" ] || [ ! -f "$APP_CLIENT_SECRET_FILE" ]; then
        echo "APP_CLIENT_SECRET_FILE must name a protected App client secret file" >&2
        exit 1
    fi
    if [ -z "$client_id" ] || [ -z "$code_or_file" ] || [ -z "$owner" ] || [ -z "$token_file" ] || [ -z "$refresh_token_file" ] || [ -z "$redirect_uri" ]; then
        usage
    fi
    response_file="$(mktemp)"
    chmod 600 "$response_file"
    sanitized_code_file=""
    sanitized_secret_file="$(mktemp)"
    chmod 600 "$sanitized_secret_file"
    trap 'rm -f "$response_file"; if [ -n "$sanitized_code_file" ]; then rm -f "$sanitized_code_file"; fi; rm -f "$sanitized_secret_file"' EXIT
    tr -d '\r\n' < "$APP_CLIENT_SECRET_FILE" > "$sanitized_secret_file"
    [ -s "$sanitized_secret_file" ] || {
        echo "App client secret file is empty" >&2
        exit 1
    }
    if [ "$command_name" = exchange-file ]; then
        sanitized_code_file="$(mktemp)"
        chmod 600 "$sanitized_code_file"
        sanitized_code="$(tr -d '\r\n' < "$code_or_file")"
        if [[ ! "$sanitized_code" =~ ^[A-Za-z0-9_-]+$ ]]; then
            echo "invalid OAuth authorization code file" >&2
            exit 1
        fi
        printf '%s' "$sanitized_code" > "$sanitized_code_file"
        code_field="@$sanitized_code_file"
    else
        if [[ ! "$code_or_file" =~ ^[A-Za-z0-9_-]+$ ]]; then
            echo "invalid OAuth authorization code" >&2
            exit 1
        fi
        code_field="=$code_or_file"
    fi
    curl --fail --silent --show-error --location \
        --header 'Accept: application/json' \
        --data-urlencode "client_id=$client_id" \
        --data-urlencode "client_secret@$sanitized_secret_file" \
        --data-urlencode "redirect_uri=$redirect_uri" \
        --data-urlencode "code$code_field" \
        'https://github.com/login/oauth/access_token' > "$response_file"
    if ! token="$(jq -er '.access_token // empty' "$response_file")"; then
        oauth_error="$(jq -r '.error // "missing_access_token"' "$response_file")"
        echo "GitHub OAuth exchange failed: $oauth_error" >&2
        exit 1
    fi
    refresh_token_value="$(jq -er '.refresh_token // empty' "$response_file")"
    case "$token" in
        ghu_*) ;;
        *)
            echo "GitHub returned a non-App user token; refusing to continue." >&2
            exit 1
            ;;
    esac
    verify_token_owner "$token" "$owner"
    write_protected_token "$token" "$token_file"
    case "$refresh_token_value" in
        ghr_*) ;;
        *)
            echo "GitHub did not return an App refresh token; refusing to continue." >&2
            exit 1
            ;;
    esac
    write_protected_token "$refresh_token_value" "$refresh_token_file"
    printf 'Verified GitHub App user token for %s; protected access and refresh files updated.\n' "$owner"
}

main() {
    case "${1:-}" in
        refresh) refresh_token "$@" ;;
        device-start) device_start "$@" ;;
        device-poll) device_poll "$@" ;;
        url) print_url "$@" ;;
        exchange | exchange-file) exchange_token "$@" ;;
        *) usage ;;
    esac
}

main "$@"
