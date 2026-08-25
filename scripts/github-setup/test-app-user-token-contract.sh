#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/github-app-user-token.sh"

[ -x "$helper" ] || {
    echo "user-token helper is not executable" >&2
    exit 1
}
grep -Fq "source \"\$script_dir/gh-common.sh\"" "$helper"
grep -Fq 'login/oauth/authorize' "$helper"
grep -Fq 'login/oauth/access_token' "$helper"
grep -Fq 'ghu_' "$helper"
grep -Fq 'GH_TOKEN=' "$helper"
grep -Fq 'gh api /user' "$helper"
grep -Fq 'require_command gh' "$helper"
grep -Fq 'APP_CLIENT_SECRET_FILE' "$helper"
grep -Fq 'exchange-file' "$helper"
grep -Fq 'code_field="@' "$helper"
grep -Fq 'APP_REDIRECT_URI' "$helper"
grep -Fq 'login/device/code' "$helper"
grep -Fq 'device-start' "$helper"
grep -Fq 'device-poll' "$helper"
grep -Fq 'grant_type=urn:ietf:params:oauth:grant-type:device_code' "$helper"
grep -Fq 'umask 077' "$helper"
grep -Fq 'chmod 600' "$helper"
grep -Fq "poll_file=\"\$(mktemp)\"" "$helper"
grep -Fq "sanitized_secret_file=\"\$(mktemp)\"" "$helper"
grep -Fq "tr -d '\\r\\n' < \"\$APP_CLIENT_SECRET_FILE\"" "$helper"
grep -Fq "client_secret@\$sanitized_secret_file" "$helper"
grep -Fq "sanitized_code_file=\"\$(mktemp)\"" "$helper"
grep -Fq "tr -d '\\r\\n' < \"\$code_or_file\"" "$helper"
grep -Fq "code_field=\"@\$sanitized_code_file\"" "$helper"
grep -Fq "if [ -n \"\$sanitized_code_file\" ]; then rm -f \"\$sanitized_code_file\"; fi" "$helper"
if grep -Fq "code_field=\"@\$code_or_file\"" "$helper"; then
    echo "exchange-file must not send unsanitized authorization code file contents" >&2
    exit 1
fi
grep -Fq 'write_protected_token()' "$helper"
grep -Fq "if [ ! -d \"\$output_dir\" ]; then" "$helper"
grep -Fq "temporary_path=\"\$(mktemp \"\$output_dir/.\$output_base.XXXXXX\")\"" "$helper"
grep -Fq "mv -f \"\$temporary_path\" \"\$output_path\"" "$helper"
if grep -Fq "printf '%s' \"\$token\" > \"\$token_file\"" "$helper"; then
    echo "user-token helper must not write directly to caller paths" >&2
    exit 1
fi
if grep -Fq "client_secret=\$APP_CLIENT_SECRET" "$helper"; then
    echo "user-token helper must not place the client secret in curl arguments" >&2
    exit 1
fi
if grep -Eq 'GH_PAT|gh_token|refresh_token' "$helper"; then
    echo "user-token helper must not implement PAT or refresh-token fallback" >&2
    exit 1
fi
if grep -Fq "echo \"\$token\"" "$helper" || grep -Fq "echo \"\$APP_CLIENT_SECRET\"" "$helper" || grep -Fq "echo \"\$access_token\"" "$helper"; then
    echo "user-token helper must not print credentials" >&2
    exit 1
fi

echo "GitHub App user-token contract checks passed."
