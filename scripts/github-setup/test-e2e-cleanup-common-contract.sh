#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
validator="$script_dir/validate-e2e-cleanup-candidate.sh"
common_script="$script_dir/cleanup-e2e-repositories-common.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

if now_epoch="$(date -u -d '2026-08-28T00:00:00Z' '+%s' 2> /dev/null)"; then
    :
else
    now_epoch="$(date -j -f '%Y-%m-%dT%H:%M:%SZ' '2026-08-28T00:00:00Z' '+%s')"
fi
cat > "$tmp_dir/eligible.json" << 'EOF'
{"owner":{"login":"e2e-owner"},"name":"bootstrap-e2e-123-1-system-embedded-create-repository","visibility":"public","archived":true,"topics":["bootstrap-e2e"],"updated_at":"2026-05-01T00:00:00Z"}
EOF
"$validator" "e2e-owner" "$tmp_dir/eligible.json" "e2e-owner/github-bootstrap,e2e-owner/central-workflows" "$now_epoch"

sed 's/create-repository/central-workflows/' "$tmp_dir/eligible.json" > "$tmp_dir/central-workflows.json"
"$validator" "e2e-owner" "$tmp_dir/central-workflows.json" "e2e-owner/github-bootstrap" "$now_epoch"

for fixture in wrong-owner wrong-name unarchived unmarked recent excluded; do
    excluded_names="e2e-owner/github-bootstrap,e2e-owner/central-workflows"
    case "$fixture" in
        wrong-owner) sed 's/e2e-owner/other-owner/' "$tmp_dir/eligible.json" > "$tmp_dir/$fixture.json" ;;
        wrong-name) sed 's/bootstrap-e2e-/e2e-/' "$tmp_dir/eligible.json" > "$tmp_dir/$fixture.json" ;;
        unarchived) sed 's/"archived":true/"archived":false/' "$tmp_dir/eligible.json" > "$tmp_dir/$fixture.json" ;;
        unmarked) sed 's/"bootstrap-e2e"/"unrelated"/' "$tmp_dir/eligible.json" > "$tmp_dir/$fixture.json" ;;
        recent) sed 's/2026-05-01/2026-08-01/' "$tmp_dir/eligible.json" > "$tmp_dir/$fixture.json" ;;
        excluded)
            excluded_names="e2e-owner/bootstrap-e2e-123-1-system-embedded-create-repository"
            cp "$tmp_dir/eligible.json" "$tmp_dir/$fixture.json"
            ;;
    esac
    if "$validator" "e2e-owner" "$tmp_dir/$fixture.json" "$excluded_names" "$now_epoch"; then
        echo "$fixture cleanup candidate was accepted" >&2
        exit 1
    fi
done

if "$validator" "e2e-owner" "$tmp_dir/eligible.json" "E2E-OWNER/bootstrap-e2e-123-1-system-embedded-create-repository" "$now_epoch"; then
    echo "case-variant exclusion was ignored" >&2
    exit 1
fi

grep -Fq 'cleanup_archived_e2e_repositories' "$common_script"
grep -Fq "\"\$validator\" \"\$ALLOWED_OWNERS\"" "$common_script"
grep -Fq 'gh api --include --method DELETE' "$common_script"
grep -Fq 'GITHUB_STEP_SUMMARY' "$common_script"
grep -Fq 'HTTP/[0-9.]+ 404' "$common_script"

echo "E2E cleanup common contract passed."
