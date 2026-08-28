#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# These tests are deterministic and do not create or mutate external resources.
# test-local-setup-scripts.sh is deliberately excluded: it is a live E2E test
# that requires an explicitly supplied repository and cleanup authorization.
contract_tests=(
    "$script_dir/test-action-lint-contract.sh"
    "$script_dir/test-quality-contract.sh"
    "$script_dir/check-commit-policy-fixtures.sh"
    "$script_dir/github-setup/test-app-auth-contract.sh"
    "$script_dir/github-setup/test-app-manifest-contract.sh"
    "$script_dir/github-setup/test-app-user-token-contract.sh"
    "$script_dir/github-setup/test-commit-verification-contract.sh"
    "$script_dir/github-setup/test-tooling-metadata-contract.sh"
    "$script_dir/github-setup/test-generated-e2e-head-contract.sh"
    "$script_dir/github-setup/test-e2e-archive-contract.sh"
    "$script_dir/github-setup/test-e2e-cleanup-contract.sh"
    "$script_dir/github-setup/test-workflow-approval-contract.sh"
    "$script_dir/github-setup/test-install-app-secrets-contract.sh"
    "$script_dir/github-setup/test-payloads.sh"
    "$script_dir/github-setup/test-personal-app-e2e-contract.sh"
    "$script_dir/github-setup/test-profile.sh"
)

for test_script in "${contract_tests[@]}"; do
    [ -f "$test_script" ] || {
        echo "contract test is missing: $test_script" >&2
        exit 1
    }
    echo "==> $test_script"
    bash "$test_script"
done

echo "All deterministic contract tests passed."
