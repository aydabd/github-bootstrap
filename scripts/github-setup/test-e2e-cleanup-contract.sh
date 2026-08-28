#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
validator="$script_dir/validate-e2e-cleanup-candidate.sh"
workflow="$script_dir/../../.github/workflows/cleanup-archived-e2e.yml"
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

grep -q 'visibility' "$validator"
grep -q 'bootstrap-e2e' "$validator"
grep -q 'trap cleanup EXIT' "$workflow"
grep -q 'archived' "$workflow"
grep -q 'validate-e2e-cleanup-candidate.sh' "$workflow"
grep -q 'permission_profile: e2e-lifecycle' "$workflow"
grep -q 'BOOTSTRAP_E2E_APP_PRIVATE_KEY' "$workflow"
grep -q 'E2E_GH_TOKEN' "$workflow"
grep -Fq 'HTTP/[0-9.]+ 404' "$workflow"
grep -Fq 'BOOTSTRAP_E2E_ALLOWED_OWNERS' "$workflow"
grep -Fq 'BOOTSTRAP_E2E_CENTRAL_REPOSITORY' "$workflow"
grep -Fq 'gh api --include --method DELETE' "$workflow"
grep -Fq "gh api --include \\" "$workflow"
grep -Fq 're-fetch E2E repository' "$workflow"
grep -Fq 'GITHUB_STEP_SUMMARY' "$workflow"

echo "E2E cleanup contract passed."
