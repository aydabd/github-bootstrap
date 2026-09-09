#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/app-credential-profile.sh"
manifest="$script_dir/app-credential-profiles.json"

[ -x "$helper" ] || {
    echo "credential profile helper is not executable" >&2
    exit 1
}

jq -e 'keys == ["e2e-provisioner", "production-provisioner"]' "$manifest" > /dev/null || {
    echo "credential profile manifest must contain exactly the two supported profiles" >&2
    exit 1
}

production_profile="$(bash "$helper" production-provisioner)"
e2e_profile="$(bash "$helper" e2e-provisioner)"

[ "$(jq -r '.client_id_variable' <<< "$production_profile")" = BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_ID ]
[ "$(jq -r '.private_key_secret' <<< "$production_profile")" = BOOTSTRAP_PRODUCTION_PROVISIONER_APP_PRIVATE_KEY ]
[ "$(jq -r '.client_secret_secret' <<< "$production_profile")" = BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_SECRET ]
[ "$(jq -r '.refresh_token_secret' <<< "$production_profile")" = BOOTSTRAP_PRODUCTION_PROVISIONER_APP_USER_REFRESH_TOKEN ]
[ "$(jq -r '.environment' <<< "$production_profile")" = production-provisioning ]

[ "$(jq -r '.client_id_variable' <<< "$e2e_profile")" = BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_ID ]
[ "$(jq -r '.private_key_secret' <<< "$e2e_profile")" = BOOTSTRAP_E2E_PROVISIONER_APP_PRIVATE_KEY ]
[ "$(jq -r '.client_secret_secret' <<< "$e2e_profile")" = BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_SECRET ]
[ "$(jq -r '.refresh_token_secret' <<< "$e2e_profile")" = BOOTSTRAP_E2E_PROVISIONER_APP_USER_REFRESH_TOKEN ]
[ "$(jq -r '.environment' <<< "$e2e_profile")" = e2e-testing ]

[ "$(jq -r '.environment' <<< "$production_profile")" != "$(jq -r '.environment' <<< "$e2e_profile")" ]
[ "$(jq -r '.refresh_token_secret' <<< "$production_profile")" != "$(jq -r '.refresh_token_secret' <<< "$e2e_profile")" ]
[ "$(bash "$helper" production-provisioner environment)" = production-provisioning ]

if bash "$helper" unknown-profile > /dev/null 2>&1; then
    echo "credential profile helper must reject unknown profiles" >&2
    exit 1
fi
if bash "$helper" production-provisioner unknown-field > /dev/null 2>&1; then
    echo "credential profile helper must reject unknown fields" >&2
    exit 1
fi
if bash "$helper" production-provisioner '' > /dev/null 2>&1; then
    echo "credential profile helper must reject an empty field" >&2
    exit 1
fi
if bash "$helper" > /dev/null 2>&1 || bash "$helper" production-provisioner environment extra > /dev/null 2>&1; then
    echo "credential profile helper must validate its arguments" >&2
    exit 1
fi

echo "App credential profile contract checks passed."
