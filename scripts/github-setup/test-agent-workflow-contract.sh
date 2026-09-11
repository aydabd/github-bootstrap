#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
manifest="$repo_root/templates/.github/config/agent-workflow.json"
validator="$repo_root/scripts/github-setup/validate-agent-workflow.sh"
project_verifier="$repo_root/scripts/github-setup/verify-agent-project.sh"

fail() {
    echo "agent workflow contract failure: $1" >&2
    exit 1
}

[ -f "$manifest" ] || fail "missing workflow manifest"
[ -x "$validator" ] || fail "missing executable workflow validator"
[ -x "$project_verifier" ] || fail "missing executable project verifier"

jq -e '
    .schema_version == 1 and
    .required_plugins.superpowers.required == true and
    (.required_plugins.superpowers.skills | length) > 0 and
    (.project.fields | map(.name) | index("Status")) != null and
    (.project.fields | map(.name) | index("Priority")) != null and
    (.project.fields | map(.name) | index("Parent issue")) != null and
    (.project.views | map(.name) | index("Ready to work")) != null and
    (.issue_templates | map(.name) | index("Epic")) != null and
    (.issue_templates | map(.name) | index("Task")) != null and
    (.lifecycle | map(.gate) | index("select-next-work")) != null
' "$manifest" >/dev/null || fail "manifest schema or required values are invalid"

result="$($validator --repository "$repo_root")"
printf '%s\n' "$result" | jq -e '
    .schema_version == 1 and
    .result == "PASS" and
    (.checks | type == "array" and length > 0) and
    (.summary.failed == 0) and
    (.summary.skipped == 0)
' >/dev/null || fail "validator did not produce a passing deterministic JSON result"

if printf '%s\n' "$result" | rg -i 'private[_ -]?key|client[_ -]?secret|refresh[_ -]?token|bearer|gho_|ghp_|ghr_' >/dev/null; then
    fail "validator output contains credential-like material"
fi

grep -Fq 'desired_status="Spec Needed"' "$repo_root/templates/.github/workflows/project-status-sync.yml" ||
    fail "project status sync does not use Spec Needed"
grep -Fq 'desired_status="In Progress"' "$repo_root/templates/.github/workflows/project-status-sync.yml" ||
    fail "project status sync does not use In Progress"
if rg -n 'Needs plan|In progress|In review' "$repo_root/templates/.github/workflows/project-status-sync.yml" >/dev/null; then
    fail "project status sync contains non-canonical status names"
fi

for template in epic.yml story.yml task.yml bug.yml security.yml config.yml; do
    [ -f "$repo_root/.github/ISSUE_TEMPLATE/$template" ] || fail "missing root issue form: $template"
done
if find "$repo_root/.github/ISSUE_TEMPLATE" -maxdepth 1 -type f -name '*.md' | grep -q .; then
    fail "root issue templates still contain markdown files"
fi

for workflow in .github/workflows/create-repository.yml .github/workflows/terraform-create-repository.yml; do
    grep -Fq 'cp templates/AGENTS.md new-repo/AGENTS.md' "$repo_root/$workflow" ||
        fail "$workflow does not install the generic AGENTS.md template"
    grep -Fq 'default: "github-planning"' "$repo_root/$workflow" ||
        fail "$workflow does not enable GitHub planning by default"
done

grep -Fq 'cp "$bootstrap_root/templates/AGENTS.md" AGENTS.md' \
    "$repo_root/.github/actions/apply-agent-instructions/action.yml" ||
    fail "existing-repository setup does not install the generic AGENTS.md template"
grep -Fq 'default: true' "$repo_root/.github/workflows/setup-existing-repository.yml" ||
    fail "existing-repository setup does not enable GitHub planning by default"

echo "Agent workflow contract checks passed."
