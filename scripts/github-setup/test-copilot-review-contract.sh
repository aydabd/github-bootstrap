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

# Trusted automation PRs do not require Copilot evidence because Copilot cannot
# review pull requests opened by GitHub Apps or bots.
cat > "$tmp_dir/bot.json" << 'EOF'
{"number":9,"head":{"sha":"current-sha"},"user":{"login":"bootstrap-writer[bot]"},"requested_reviewers":[{"login":"copilot-pull-request-reviewer[bot]"}]}
EOF
template_validator="$repo_root/templates/.github/scripts/validate-copilot-review.sh"
for validator_path in "$validator" "$template_validator"; do
    for require_copilot_review in false true; do
        if REQUIRE_COPILOT_REVIEW="$require_copilot_review" "$validator_path" \
            "$tmp_dir/bot.json" "$tmp_dir/empty-reviews.json" \
            "$tmp_dir/threads.json" "copilot-pull-request-reviewer[bot]"; then
            :
        else
            echo "bot-authored pull request required Copilot evidence in $validator_path" >&2
            exit 1
        fi
    done
done
sed 's/"isResolved":true/"isResolved":false/' "$tmp_dir/threads.json" > \
    "$tmp_dir/unresolved-threads.json"
for human_validator in "$validator" "$template_validator"; do
    if "$human_validator" "$tmp_dir/pr.json" "$tmp_dir/reviews.json" \
        "$tmp_dir/unresolved-threads.json" "copilot-pull-request-reviewer[bot]"; then
        echo "validator accepted unresolved Copilot threads in $human_validator" >&2
        exit 1
    fi
done

if REQUIRE_COPILOT_REVIEW=true "$validator" "$tmp_dir/no-request.json" \
    "$tmp_dir/empty-reviews.json" "$tmp_dir/threads.json" "copilot-pull-request-reviewer[bot]"; then
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
