#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
validator="$repo_root/scripts/github-setup/validate-e2e-archive-target.sh"
workflow="$repo_root/.github/workflows/test-generated-repository-e2e.yml"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/valid-topics.json" << 'EOF'
{"names":["bootstrap-e2e"]}
EOF
"$validator" "aydabd" "aydabd/bootstrap-e2e-123-1-system-embedded-create-repository" "$tmp_dir/valid-topics.json"

if "$validator" "aydabd" "aydabd/e2e-123-1-system-embedded-create-repository" "$tmp_dir/valid-topics.json"; then
    echo "non-E2E repository target was accepted" >&2
    exit 1
fi
if "$validator" "aydabd" "other-owner/bootstrap-e2e-123-1-system-embedded-create-repository" "$tmp_dir/valid-topics.json"; then
    echo "wrong-owner archive target was accepted" >&2
    exit 1
fi

cat > "$tmp_dir/missing-topic.json" << 'EOF'
{"names":["unrelated"]}
EOF
if "$validator" "aydabd" "aydabd/bootstrap-e2e-123-1-system-embedded-create-repository" "$tmp_dir/missing-topic.json"; then
    echo "unmarked archive target was accepted" >&2
    exit 1
fi

grep -q 'visibility=public' "$workflow"
grep -q 'bootstrap-e2e' "$workflow"
grep -q 'trap cleanup EXIT' "$workflow"
grep -q 'archived=true' "$workflow"
grep -q 'validate-e2e-archive-target.sh' "$workflow"
grep -q 'return 1' "$workflow"
grep -q 'permission_profile: e2e-lifecycle' "$workflow"
grep -q 'BOOTSTRAP_E2E_APP_PRIVATE_KEY' "$workflow"
grep -q 'E2E_GH_TOKEN' "$workflow"
grep -Fq 'HTTP/[0-9.]+ 404' "$workflow"
grep -Fq 'names[]=bootstrap-e2e' "$workflow"

echo "E2E archive contract passed."
