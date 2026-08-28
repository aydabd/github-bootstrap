#!/usr/bin/env bash
set -euo pipefail

metadata_file="${1:-}"
[ -n "$metadata_file" ] || {
    echo "tooling metadata file is required" >&2
    exit 1
}
[ -s "$metadata_file" ] || {
    echo "tooling update metadata is missing or empty" >&2
    exit 1
}

jq -e '.schema_version == 1 and (.updates | type == "array" and length > 0) and all(.updates[]; (.package | type == "string" and length > 0) and (.old_version | type == "string" and length > 0) and (.new_version | type == "string" and length > 0) and (.files | type == "array" and length > 0 and all(.[]; type == "string" and length > 0)) and ((.update_type == "patch" and .risk == "low") or (.update_type == "minor" and .risk == "medium") or (.update_type == "major" and .risk == "high") or (.update_type == "breaking" and .risk == "high") or (.update_type == "unknown" and .risk == "unknown")))' "$metadata_file" > /dev/null || {
    echo "tooling update metadata is invalid" >&2
    exit 1
}
