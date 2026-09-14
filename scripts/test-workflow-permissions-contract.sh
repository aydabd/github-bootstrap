#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

assert_job_permissions() {
    local workflow="$1"
    local job="$2"
    local expected="$3"

    awk -v job="$job" -v expected="$expected" '
        $0 == "  " job ":" {
            in_job = 1
            next
        }
        in_job && $0 ~ /^  [A-Za-z0-9_-]+:/ {
            exit found ? 0 : 1
        }
        in_job && $0 ~ /^    permissions: \{\}/ && expected == "{}" {
            found = 1
        }
        in_job && $0 == "    permissions:" && expected == "contents: read" {
            getline
            if ($0 ~ /^      contents: read([[:space:]]|$)/) {
                found = 1
            }
        }
        END {
            if (in_job && found) {
                exit 0
            }
            exit 1
        }
    ' "$repo_root/.github/workflows/$workflow" || {
        echo "$workflow job $job must declare permissions: $expected" >&2
        exit 1
    }
}

assert_job_permissions "delete-repo.yml" "delete-repo" "contents: read"
assert_job_permissions "create-repository.yml" "validate-provisioner" "{}"
assert_job_permissions "terraform-create-repository.yml" "validate-provisioner" "{}"
assert_job_permissions "test-local-setup-scripts.yml" "test-local-setup-scripts" "contents: read"
assert_job_permissions "setup-labels-and-security.yml" "setup-labels-and-security" "contents: read"
assert_job_permissions "setup-agent-instructions.yml" "setup-agent-instructions" "contents: read"
assert_job_permissions "setup-coderabbit.yml" "setup-coderabbit" "contents: read"

echo "Workflow permissions contract checks passed."
