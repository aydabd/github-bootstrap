#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lint_file="$repo_root/make/lint.mk"

grep -Fq 'scripts/run-contract-tests.sh' "$lint_file" || {
    echo "quality must run the deterministic contract-test suite" >&2
    exit 1
}

grep -Fq 'quality-contract-tests' "$lint_file" || {
    echo "quality must depend on the contract-test target" >&2
    exit 1
}

grep -Fq 'test-local-setup-scripts.sh' "$lint_file" || {
    echo "quality documentation must identify the live E2E test boundary" >&2
    exit 1
}

grep -Fq 'quality-go-tests' "$lint_file" || {
    echo "quality must run Go tests unconditionally" >&2
    exit 1
}

grep -Fq 'check-commit-policy-fixtures.sh' "$repo_root/scripts/run-contract-tests.sh" || {
    echo "quality contract suite must include commit-policy fixtures" >&2
    exit 1
}

echo "Quality contract checks passed."
