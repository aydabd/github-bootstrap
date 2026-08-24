#!/usr/bin/env bash
set -euo pipefail

profile_file=""
profile_name=""
delivery_mode="embedded"

usage() {
    cat << 'USAGE'
Usage: validate-profile.sh --profile-file PATH --profile NAME --delivery-mode embedded|centralized
USAGE
}

require_option_value() {
    local option="$1"
    if [ "$#" -lt 2 ] || [ -z "${2:-}" ] || [[ "$2" == --* ]]; then
        echo "$option requires a value" >&2
        usage >&2
        exit 1
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --profile-file)
            require_option_value "$@"
            profile_file="$2"
            shift 2
            ;;
        --profile)
            require_option_value "$@"
            profile_name="$2"
            shift 2
            ;;
        --delivery-mode)
            require_option_value "$@"
            delivery_mode="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

command -v jq > /dev/null 2>&1 || {
    echo "jq is required to validate bootstrap profiles" >&2
    exit 1
}
if [ -z "$profile_file" ] || [ ! -f "$profile_file" ]; then
    echo "profile file is missing: $profile_file" >&2
    exit 1
fi
if [ -z "$profile_name" ]; then
    echo "profile name is required" >&2
    exit 1
fi

jq -e --arg profile "$profile_name" --arg mode "$delivery_mode" '
    . as $root |
    ($root.profiles[$profile]) as $selected |
    ($root.capabilities | map(.id)) as $capability_ids |
    ($root.bundles | keys) as $bundle_ids |
    type == "object" and
    (.schema_version | type == "number") and
    ($selected | type == "object" and
        (.capabilities | type == "array" and length > 0) and
        (all(.capabilities[]; . as $id | ($id | type == "string" and length > 0) and ($capability_ids | index($id)) != null)) and
        (.bundles | type == "array") and
        (all(.bundles[]; . as $bundle | ($bundle | type == "string" and length > 0) and ($bundle_ids | index($bundle)) != null))
    ) and
    ($mode == "embedded" or $mode == "centralized") and
    (.delivery_modes[$mode] | type == "object") and
    (.bundles | type == "object" and
        all(to_entries[];
            (.value | type == "object") and
            (.value.enabled_by_default | type == "boolean") and
            (.value.assets | type == "array" and
                all(.[]; type == "string" and length > 0)))) and
    ([.capabilities[].id] | length == (unique | length)) and
    ([.capabilities[].check] | length == (unique | length)) and
    (all(.capabilities[];
        (.id | type == "string" and length > 0) and
        ((.classification == "baseline" or .classification == "provider-specific") or
        ((.classification | startswith("optional:")) and
        ((.classification | sub("^optional:"; "")) as $bundle |
        ($bundle | length > 0) and ($bundle_ids | index($bundle)) != null))) and
        (.owned_paths | type == "array" and length > 0 and
            all(.[]; type == "string" and length > 0)) and
        (.workflow | type == "string" and length > 0) and
        (.check | type == "string" and length > 0) and
        (.enabled_by_default | type == "boolean") and
        (.providers | type == "array" and length > 0 and
            all(.[]; type == "string" and length > 0)))) and
    (all(.assets[];
        (.path | type == "string" and length > 0) and
        ((.classification == "baseline" or .classification == "provider-specific") or
        ((.classification | startswith("optional:")) and
        ((.classification | sub("^optional:"; "")) as $bundle |
        ($bundle | length > 0) and ($bundle_ids | index($bundle)) != null))) and
        (.owned | type == "boolean"))) and
    (if $mode == "centralized" then
        (.delivery_modes.centralized.requires_repository == true and
        .delivery_modes.centralized.requires_ref == true and
        (.delivery_modes.centralized.repository | type == "string" and length > 0) and
        (.delivery_modes.centralized.ref | type == "string" and length > 0))
    else true end)
' "$profile_file" > /dev/null || {
    echo "invalid profile '$profile_name' or delivery mode '$delivery_mode' in $profile_file" >&2
    exit 1
}

echo "profile '$profile_name' validated for $delivery_mode delivery"
