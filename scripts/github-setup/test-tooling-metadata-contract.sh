#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
validator="$script_dir/validate-tooling-metadata.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

valid="$tmp_dir/valid.json"
cat > "$valid" << 'EOF'
{"schema_version":1,"updates":[{"package":"tool","old_version":"1.2.3","new_version":"1.2.4","update_type":"patch","risk":"low","files":["mise.toml"]}]}
EOF

"$validator" "$valid"

for payload in \
    '{"schema_version":1,"updates":[]}' \
    '{"schema_version":1,"updates":[{"package":"tool","old_version":"1","new_version":"2","update_type":"patch","risk":"low","files":[]}]}' \
    '{"schema_version":1,"updates":[{"package":"tool","old_version":"1","new_version":"2","update_type":"patch","risk":"low"}]}' \
    '{"schema_version":1,"updates":[{"package":"tool","old_version":"1","new_version":"2","update_type":"patch","risk":"high","files":["mise.toml"]}]}' \
    '{"schema_version":1,"updates":[{"package":"tool","old_version":"1","new_version":"2","update_type":"major","risk":"low","files":["mise.toml"]}]}' \
    '{"schema_version":1,"updates":[{"package":"tool","old_version":"1","new_version":"2","update_type":"breaking","risk":"medium","files":["mise.toml"]}]}' \
    '{"schema_version":1,"updates":[{"package":"tool","old_version":"1","new_version":"2","update_type":"unknown","risk":"high","files":["mise.toml"]}]}'; do
    candidate="$tmp_dir/candidate.json"
    printf '%s\n' "$payload" > "$candidate"
    if "$validator" "$candidate"; then
        echo "validator accepted invalid metadata: $payload" >&2
        exit 1
    fi
done

for payload in '' 'not-json' '{"schema_version":2,"updates":[]}' '{"schema_version":1}'; do
    candidate="$tmp_dir/candidate.json"
    printf '%s\n' "$payload" > "$candidate"
    if "$validator" "$candidate"; then
        echo "validator accepted invalid metadata: $payload" >&2
        exit 1
    fi
done

if "$validator" "$tmp_dir/missing.json"; then
    echo "validator accepted missing metadata" >&2
    exit 1
fi

echo "Tooling metadata contract passed."
