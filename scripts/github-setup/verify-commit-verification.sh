#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: verify-commit-verification.sh OWNER/REPOSITORY COMMIT_SHA" >&2
    exit 2
}

repository="${1:-}"
commit_sha="${2:-}"
if [ -z "$repository" ] || [ -z "$commit_sha" ]; then
    usage
fi
[[ "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || {
    echo "invalid repository: $repository" >&2
    exit 1
}
[[ "$commit_sha" =~ ^[0-9a-fA-F]{40}$ ]] || {
    echo "invalid commit SHA" >&2
    exit 1
}

verification="$(gh api "/repos/$repository/commits/$commit_sha" \
    --jq '[.commit.verification.verified, .commit.verification.reason] | @tsv')"
if [ "$verification" != $'true\tvalid' ]; then
    echo "commit $commit_sha is not verified by GitHub with a valid signature" >&2
    exit 1
fi
