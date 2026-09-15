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

"$validator" "e2e-owner" "$tmp_dir/recent.json" "e2e-owner/github-bootstrap" "$now_epoch" 0

if "$validator" "e2e-owner" "$tmp_dir/eligible.json" "E2E-OWNER/bootstrap-e2e-123-1-system-embedded-create-repository" "$now_epoch"; then
    echo "case-variant exclusion was ignored" >&2
    exit 1
fi

grep -Fq 'cleanup_archived_e2e_repositories' "$common_script"
grep -Fq "\"\$validator\" \"\$ALLOWED_OWNERS\"" "$common_script"
grep -Fq 'gh api --include --method DELETE' "$common_script"
grep -Fq 'GITHUB_STEP_SUMMARY' "$common_script"
grep -Fq 'HTTP/[0-9.]+ 404' "$common_script"
grep -Fq 'MIN_AGE_DAYS' "$common_script"
grep -Fq 'min_age_days' "$common_script"

# CENTRAL_REPOSITORY has no permanent value yet (the real central-workflows
# repository does not exist until it is bootstrapped); the function must
# still run with it unset instead of failing configuration validation.
fake_bin_dir="$tmp_dir/bin"
mkdir -p "$fake_bin_dir"
cat > "$fake_bin_dir/gh" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "api" ] && [ "$2" = "--paginate" ] && [ "$3" = "--slurp" ]; then
    echo "[[]]"
    exit 0
fi
echo "unexpected gh invocation: $*" >&2
exit 1
EOF
chmod +x "$fake_bin_dir/gh"

(
    # shellcheck disable=SC1090
    source "$common_script"
    PATH="$fake_bin_dir:$PATH"
    E2E_GH_TOKEN=x ALLOWED_OWNERS=e2e-owner APP_OWNER=e2e-owner \
        BOOTSTRAP_REPOSITORY=e2e-owner/github-bootstrap VALIDATOR="$validator" \
        GITHUB_STEP_SUMMARY="$tmp_dir/summary" \
        cleanup_archived_e2e_repositories "/users/e2e-owner/repos"
) || {
    echo "cleanup_archived_e2e_repositories failed with CENTRAL_REPOSITORY unset" >&2
    exit 1
}

echo "E2E cleanup common contract passed."
