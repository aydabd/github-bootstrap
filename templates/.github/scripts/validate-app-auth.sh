#!/usr/bin/env bash
set -euo pipefail

required_value() {
    local name="$1"
    local value="${!name:-}"
    if [ -z "$value" ]; then
        echo "::error::GitHub App authentication requires $name." >&2
        exit 1
    fi
}

AUTH_MODE="${AUTH_MODE:-app}"
case "$AUTH_MODE" in
    owner-only | app-user) ;;
    app)
        required_value APP_CLIENT_ID
        required_value APP_PRIVATE_KEY
        ;;
    *)
        echo "::error::Unsupported GitHub App authentication mode '$AUTH_MODE'." >&2
        exit 1
        ;;
esac
required_value APP_OWNER
required_value TARGET_OWNER

owner_pattern='^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$'
for owner_name in APP_OWNER TARGET_OWNER; do
    owner_value="${!owner_name}"
    if [[ ! "$owner_value" =~ $owner_pattern ]]; then
        echo "::error::Invalid GitHub owner in $owner_name: '$owner_value'." >&2
        exit 1
    fi
done

normalized_app_owner="$(printf '%s' "$APP_OWNER" | tr '[:upper:]' '[:lower:]')"
normalized_target_owner="$(printf '%s' "$TARGET_OWNER" | tr '[:upper:]' '[:lower:]')"
if [ "$normalized_app_owner" != "$normalized_target_owner" ]; then
    case "$AUTH_MODE" in
        app)
            owner_binding="GitHub App installation owner"
            ;;
        app-user)
            owner_binding="GitHub App user-token owner"
            ;;
        owner-only)
            owner_binding="Configured GitHub App owner"
            ;;
    esac
    echo "::error::$owner_binding '$APP_OWNER' does not match target repository owner '$TARGET_OWNER'." >&2
    exit 1
fi
