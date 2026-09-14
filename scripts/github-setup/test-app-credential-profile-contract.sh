#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/app-credential-profile.sh"
manifest="$script_dir/app-credential-profiles.json"

[ -x "$helper" ] || {
    echo "credential profile helper is not executable" >&2
    exit 1
}

jq -e '.role_order == [
    "e2e-fixture",
    "e2e-reviewer",
    "e2e-writer",
    "e2e-provisioner",
    "production-reviewer",
    "production-writer",
    "production-provisioner"
]' "$manifest" > /dev/null || {
    echo "credential profile manifest must contain exactly the seven supported profiles" >&2
    exit 1
}

jq -e '.schema_version == 1 and .repository_owner == "aydabd" and
    ([.role_order[] | .] | length) == 7 and
    ([.profile_metadata[] | select(.owner == "aydabd" and .visibility == "private" and
        .installation_scope == "repository" and .api_method == "POST" and
        (.api_endpoint | endswith("/conversions")) and (.permissions | type == "array") and
        (.events | type == "array") and (.rotation | type == "string") and
        (.cleanup == "exact-role-directory"))] | length) == 7' "$manifest" > /dev/null || {
    echo "profile metadata must define deterministic install and cleanup policy" >&2
    exit 1
}

production_profile="$(bash "$helper" production-provisioner)"
e2e_profile="$(bash "$helper" e2e-provisioner)"
e2e_writer_profile="$(bash "$helper" e2e-writer)"
e2e_reviewer_profile="$(bash "$helper" e2e-reviewer)"
e2e_fixture_profile="$(bash "$helper" e2e-fixture)"
production_writer_profile="$(bash "$helper" production-writer)"
production_reviewer_profile="$(bash "$helper" production-reviewer)"

for maintenance_profile in e2e_writer_profile e2e_reviewer_profile \
    production_writer_profile production_reviewer_profile; do
    jq -e 'keys == [
        "app_slug_variable",
        "client_id_variable",
        "environment",
        "private_key_secret"
    ]' <<< "${!maintenance_profile}" > /dev/null
done
jq -e 'keys == [
    "app_slug_variable",
    "client_id_variable",
    "client_secret_secret",
    "environment",
    "private_key_secret",
    "refresh_token_secret"
]' <<< "$e2e_fixture_profile" > /dev/null
[ "$(jq -r '.client_id_variable' <<< "$e2e_fixture_profile")" = BOOTSTRAP_E2E_FIXTURE_APP_CLIENT_ID ]
[ "$(jq -r '.app_slug_variable' <<< "$e2e_fixture_profile")" = BOOTSTRAP_E2E_FIXTURE_APP_SLUG ]
[ "$(jq -r '.private_key_secret' <<< "$e2e_fixture_profile")" = BOOTSTRAP_E2E_FIXTURE_APP_PRIVATE_KEY ]
[ "$(jq -r '.client_secret_secret' <<< "$e2e_fixture_profile")" = BOOTSTRAP_E2E_FIXTURE_APP_CLIENT_SECRET ]
[ "$(jq -r '.refresh_token_secret' <<< "$e2e_fixture_profile")" = BOOTSTRAP_E2E_FIXTURE_APP_USER_REFRESH_TOKEN ]
[ "$(jq -r '.environment' <<< "$e2e_fixture_profile")" = e2e ]

[ "$(jq -r '.client_id_variable' <<< "$production_profile")" = BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_ID ]
[ "$(jq -r '.private_key_secret' <<< "$production_profile")" = BOOTSTRAP_PRODUCTION_PROVISIONER_APP_PRIVATE_KEY ]
[ "$(jq -r '.client_secret_secret' <<< "$production_profile")" = BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_SECRET ]
[ "$(jq -r '.refresh_token_secret' <<< "$production_profile")" = BOOTSTRAP_PRODUCTION_PROVISIONER_APP_USER_REFRESH_TOKEN ]
[ "$(jq -r '.environment' <<< "$production_profile")" = production-provisioning ]

[ "$(jq -r '.client_id_variable' <<< "$e2e_profile")" = BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_ID ]
[ "$(jq -r '.private_key_secret' <<< "$e2e_profile")" = BOOTSTRAP_E2E_PROVISIONER_APP_PRIVATE_KEY ]
[ "$(jq -r '.client_secret_secret' <<< "$e2e_profile")" = BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_SECRET ]
[ "$(jq -r '.refresh_token_secret' <<< "$e2e_profile")" = BOOTSTRAP_E2E_PROVISIONER_APP_USER_REFRESH_TOKEN ]
[ "$(jq -r '.environment' <<< "$e2e_profile")" = e2e ]

[ "$(jq -r '.environment' <<< "$production_profile")" != "$(jq -r '.environment' <<< "$e2e_profile")" ]
[ "$(jq -r '.refresh_token_secret' <<< "$production_profile")" != "$(jq -r '.refresh_token_secret' <<< "$e2e_profile")" ]
[ "$(bash "$helper" production-provisioner environment)" = production-provisioning ]

[ "$(jq -r '.client_id_variable' <<< "$e2e_writer_profile")" = BOOTSTRAP_E2E_WRITER_APP_CLIENT_ID ]
[ "$(jq -r '.app_slug_variable' <<< "$e2e_writer_profile")" = BOOTSTRAP_E2E_WRITER_APP_SLUG ]
[ "$(jq -r '.private_key_secret' <<< "$e2e_writer_profile")" = BOOTSTRAP_E2E_WRITER_APP_PRIVATE_KEY ]
[ "$(jq -r '.environment' <<< "$e2e_writer_profile")" = e2e ]
[ "$(jq -r '.client_id_variable' <<< "$e2e_reviewer_profile")" = BOOTSTRAP_E2E_REVIEWER_APP_CLIENT_ID ]
[ "$(jq -r '.app_slug_variable' <<< "$e2e_reviewer_profile")" = BOOTSTRAP_E2E_REVIEWER_APP_SLUG ]
[ "$(jq -r '.private_key_secret' <<< "$e2e_reviewer_profile")" = BOOTSTRAP_E2E_REVIEWER_APP_PRIVATE_KEY ]
[ "$(jq -r '.environment' <<< "$e2e_reviewer_profile")" = e2e ]

[ "$(jq -r '.client_id_variable' <<< "$production_writer_profile")" = BOOTSTRAP_PRODUCTION_WRITER_APP_CLIENT_ID ]
[ "$(jq -r '.app_slug_variable' <<< "$production_writer_profile")" = BOOTSTRAP_PRODUCTION_WRITER_APP_SLUG ]
[ "$(jq -r '.private_key_secret' <<< "$production_writer_profile")" = BOOTSTRAP_PRODUCTION_WRITER_APP_PRIVATE_KEY ]
[ "$(jq -r '.environment' <<< "$production_writer_profile")" = production ]
[ "$(jq -r '.client_id_variable' <<< "$production_reviewer_profile")" = BOOTSTRAP_PRODUCTION_REVIEWER_APP_CLIENT_ID ]
[ "$(jq -r '.app_slug_variable' <<< "$production_reviewer_profile")" = BOOTSTRAP_PRODUCTION_REVIEWER_APP_SLUG ]
[ "$(jq -r '.private_key_secret' <<< "$production_reviewer_profile")" = BOOTSTRAP_PRODUCTION_REVIEWER_APP_PRIVATE_KEY ]
[ "$(jq -r '.environment' <<< "$production_reviewer_profile")" = production ]

[ "$(jq -r '.environment' <<< "$production_writer_profile")" != "$(jq -r '.environment' <<< "$e2e_writer_profile")" ]
[ "$(jq -r '.environment' <<< "$production_reviewer_profile")" != "$(jq -r '.environment' <<< "$e2e_reviewer_profile")" ]
[ "$(jq -r '.client_id_variable' <<< "$production_writer_profile")" != "$(jq -r '.client_id_variable' <<< "$production_reviewer_profile")" ]
[ "$(jq -r '.app_slug_variable' <<< "$production_writer_profile")" != "$(jq -r '.app_slug_variable' <<< "$production_reviewer_profile")" ]
[ "$(jq -r '.private_key_secret' <<< "$production_writer_profile")" != "$(jq -r '.private_key_secret' <<< "$production_reviewer_profile")" ]
[ "$(jq -r '.client_id_variable' <<< "$production_writer_profile")" != "$(jq -r '.client_id_variable' <<< "$e2e_writer_profile")" ]
[ "$(jq -r '.private_key_secret' <<< "$production_reviewer_profile")" != "$(jq -r '.private_key_secret' <<< "$e2e_reviewer_profile")" ]

[ "$(jq -r '.client_id_variable' <<< "$e2e_writer_profile")" != "$(jq -r '.client_id_variable' <<< "$e2e_reviewer_profile")" ]
[ "$(jq -r '.app_slug_variable' <<< "$e2e_writer_profile")" != "$(jq -r '.app_slug_variable' <<< "$e2e_reviewer_profile")" ]
[ "$(jq -r '.private_key_secret' <<< "$e2e_writer_profile")" != "$(jq -r '.private_key_secret' <<< "$e2e_reviewer_profile")" ]
[ "$(jq -r '.client_id_variable' <<< "$e2e_writer_profile")" != "$(jq -r '.client_id_variable' <<< "$production_profile")" ]
[ "$(jq -r '.private_key_secret' <<< "$e2e_reviewer_profile")" != "$(jq -r '.private_key_secret' <<< "$production_profile")" ]

writer_manifest="$script_dir/../../docs/github-app-manifests/bootstrap-e2e-writer.json"
reviewer_manifest="$script_dir/../../docs/github-app-manifests/bootstrap-e2e-reviewer.json"
jq -e '.name == "Bootstrap E2E Writer" and
    .default_permissions == {
        "contents": "write",
        "issues": "write",
        "pull_requests": "write",
        "workflows": "write"
    }' "$writer_manifest" > /dev/null
jq -e '.name == "Bootstrap E2E Reviewer" and
    .default_permissions == {
        "actions": "write",
        "pull_requests": "write"
    }' "$reviewer_manifest" > /dev/null

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
