#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
validator="$script_dir/validate-copilot-review.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/pr.json" << 'EOF'
{"number":7,"head":{"sha":"current-sha"},"requested_reviewers":[{"login":"copilot-pull-request-reviewer[bot]"}]}
EOF
cat > "$tmp_dir/reviews.json" << 'EOF'
[{"user":{"login":"copilot-pull-request-reviewer[bot]"},"state":"COMMENTED","commit_id":"current-sha"}]
EOF
cat > "$tmp_dir/threads.json" << 'EOF'
[{"isResolved":true,"author_login":"copilot-pull-request-reviewer[bot]"}]
EOF
printf '%s\n' '[]' > "$tmp_dir/empty-reviews.json"

"$validator" "$tmp_dir/pr.json" "$tmp_dir/reviews.json" "$tmp_dir/threads.json" "copilot-pull-request-reviewer[bot]"

cat > "$tmp_dir/no-request.json" << 'EOF'
{"number":7,"head":{"sha":"current-sha"},"requested_reviewers":[]}
EOF
"$validator" "$tmp_dir/no-request.json" "$tmp_dir/reviews.json" "$tmp_dir/threads.json" ""

# The production-root validator retains its existing bot behavior. The template
# maintenance path must validate Copilot evidence for eligible bot PRs.
cat > "$tmp_dir/bot-pr.json" << 'EOF'
{"number":9,"head":{"sha":"current-sha"},"user":{"login":"repository-maintenance-writer[bot]"},"requested_reviewers":[{"login":"copilot-pull-request-reviewer[bot]"}]}
EOF
"$validator" "$tmp_dir/bot-pr.json" "$tmp_dir/empty-reviews.json" "$tmp_dir/threads.json" "copilot-pull-request-reviewer[bot]"

template_validator="$repo_root/templates/.github/scripts/validate-copilot-review.sh"
if "$template_validator" "$tmp_dir/bot-pr.json" "$tmp_dir/empty-reviews.json" \
    "$tmp_dir/threads.json" "copilot-pull-request-reviewer[bot]"; then
    echo "template validator bypassed Copilot review for a bot-authored PR" >&2
    exit 1
fi
"$template_validator" "$tmp_dir/bot-pr.json" "$tmp_dir/reviews.json" \
    "$tmp_dir/threads.json" "copilot-pull-request-reviewer[bot]"
if "$template_validator" "$tmp_dir/bot-pr.json" "$tmp_dir/reviews.json" \
    "$tmp_dir/threads.json" ""; then
    echo "template validator accepted a bot-authored PR without configured Copilot identity" >&2
    exit 1
fi
sed 's/"isResolved":true/"isResolved":false/' "$tmp_dir/threads.json" > \
    "$tmp_dir/unresolved-threads.json"
if "$template_validator" "$tmp_dir/bot-pr.json" "$tmp_dir/reviews.json" \
    "$tmp_dir/unresolved-threads.json" "copilot-pull-request-reviewer[bot]"; then
    echo "template validator accepted unresolved Copilot threads" >&2
    exit 1
fi

if "$validator" "$tmp_dir/no-request.json" "$tmp_dir/empty-reviews.json" "$tmp_dir/threads.json" "copilot-pull-request-reviewer[bot]"; then
    echo "configured Copilot review gate was bypassed" >&2
    exit 1
fi

for mutation in pending stale unresolved; do
    cp "$tmp_dir/pr.json" "$tmp_dir/mutated-pr.json"
    cp "$tmp_dir/reviews.json" "$tmp_dir/mutated-reviews.json"
    cp "$tmp_dir/threads.json" "$tmp_dir/mutated-threads.json"
    case "$mutation" in
        pending) printf '%s\n' '[]' > "$tmp_dir/mutated-reviews.json" ;;
        stale) sed 's/current-sha/old-sha/' "$tmp_dir/reviews.json" > "$tmp_dir/mutated-reviews.json" ;;
        unresolved) sed 's/"isResolved":true/"isResolved":false/' "$tmp_dir/threads.json" > "$tmp_dir/mutated-threads.json" ;;
    esac
    if "$validator" "$tmp_dir/mutated-pr.json" "$tmp_dir/mutated-reviews.json" "$tmp_dir/mutated-threads.json" "copilot-pull-request-reviewer[bot]"; then
        echo "validator accepted invalid Copilot fixture: $mutation" >&2
        exit 1
    fi
done

workflow="$script_dir/../../.github/workflows/approve-automation-workflows.yml"
grep -Fq 'validate-copilot-review.sh' "$workflow"
grep -Fq 'BOOTSTRAP_COPILOT_REVIEWER_LOGIN' "$workflow"
grep -Fq "pulls/\$pr_number/reviews" "$workflow"
grep -Fq 'reviewThreads(first:100)' "$workflow"
grep -Fq 'pageInfo.hasNextPage == false' "$workflow"
grep -Fq 'isResolved' "$workflow"
grep -Fq 'COPILOT_REVIEWER_LOGIN' "$workflow"

echo "Copilot review contract passed."
