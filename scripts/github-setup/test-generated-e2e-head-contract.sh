#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
validator="$script_dir/validate-generated-e2e-head.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

requested_sha="0123456789abcdef0123456789abcdef01234567"
cat > "$tmp_dir/matching-run.json" << EOF
{"headSha":"$requested_sha"}
EOF
"$validator" "$requested_sha" "$tmp_dir/matching-run.json"

cat > "$tmp_dir/stale-run.json" << 'EOF'
{"head_sha":"fedcba9876543210fedcba9876543210fedcba98"}
EOF
if "$validator" "$requested_sha" "$tmp_dir/stale-run.json"; then
    echo "stale E2E run SHA was accepted" >&2
    exit 1
fi

if "$validator" "" "$tmp_dir/matching-run.json"; then
    echo "empty requested E2E SHA was accepted" >&2
    exit 1
fi

if "$validator" "not-a-sha" "$tmp_dir/matching-run.json"; then
    echo "malformed requested E2E SHA was accepted" >&2
    exit 1
fi

echo "Generated repository E2E head contract passed."
