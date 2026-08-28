#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
validator="$script_dir/validate-workflow-approval.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

run_file="$tmp_dir/run.json"
pr_file="$tmp_dir/pr.json"
files_file="$tmp_dir/files.txt"

cat > "$run_file" << 'EOF'
{"id":123,"name":"Quality","path":".github/workflows/quality.yml","event":"pull_request","status":"completed","conclusion":"action_required","head_sha":"abc123","repository":{"full_name":"acme/project"},"head_repository":{"full_name":"acme/project"},"pull_requests":[{"number":7}]}
EOF
cat > "$pr_file" << 'EOF'
{"number":7,"state":"open","user":{"login":"dependabot[bot]"},"head":{"sha":"abc123","repo":{"full_name":"acme/project"}},"base":{"repo":{"full_name":"acme/project"}}}
EOF
printf '%s\n' README.md > "$files_file"

OWNER=acme REPOSITORY=project WRITER_APP_SLUG=maintenance-writer \
    "$validator" "$run_file" "$pr_file" "$files_file"

sed 's/dependabot\[bot\]/maintenance-writer[bot]/' "$pr_file" > "$tmp_dir/writer-pr.json"
OWNER=acme REPOSITORY=project WRITER_APP_SLUG=maintenance-writer \
    "$validator" "$run_file" "$tmp_dir/writer-pr.json" "$files_file"

for mutation in conclusion fork sha author workflow workflow-name event repository pr-number stale workflow-change; do
    cp "$run_file" "$tmp_dir/mutated-run.json"
    cp "$pr_file" "$tmp_dir/mutated-pr.json"
    cp "$files_file" "$tmp_dir/mutated-files.txt"
    case "$mutation" in
        conclusion) sed 's/action_required/success/' "$run_file" > "$tmp_dir/mutated-run.json" ;;
        fork) sed 's#acme/project#external/project#g' "$run_file" > "$tmp_dir/mutated-run.json" ;;
        sha) sed 's/abc123/stale456/g' "$run_file" > "$tmp_dir/mutated-run.json" ;;
        author) sed 's/dependabot\[bot\]/unknown[bot]/' "$pr_file" > "$tmp_dir/mutated-pr.json" ;;
        workflow) sed 's#quality.yml#unexpected.yml#' "$run_file" > "$tmp_dir/mutated-run.json" ;;
        workflow-name) sed 's/"name":"Quality"/"name":"Unexpected"/' "$run_file" > "$tmp_dir/mutated-run.json" ;;
        event) sed 's/pull_request/push/' "$run_file" > "$tmp_dir/mutated-run.json" ;;
        repository) sed 's#acme/project#other/project#g' "$run_file" > "$tmp_dir/mutated-run.json" ;;
        pr-number) sed 's/"number":7/"number":8/g' "$run_file" > "$tmp_dir/mutated-run.json" ;;
        stale) sed 's/"state":"open"/"state":"closed"/' "$pr_file" > "$tmp_dir/mutated-pr.json" ;;
        workflow-change) printf '%s\n' .github/workflows/quality.yml > "$tmp_dir/mutated-files.txt" ;;
    esac
    if env OWNER=acme REPOSITORY=project WRITER_APP_SLUG=maintenance-writer \
        "$validator" "$tmp_dir/mutated-run.json" "$tmp_dir/mutated-pr.json" "$tmp_dir/mutated-files.txt"; then
        echo "validator accepted invalid fixture: $mutation" >&2
        exit 1
    fi
done

echo "Workflow approval contract passed."
