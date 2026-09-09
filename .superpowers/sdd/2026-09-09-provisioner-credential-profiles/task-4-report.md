# Task 4 Report: Isolate production and E2E provisioner workflows

## Scope

Updated both repository-creation workflows and the generated-repository E2E
workflow to select the explicit `production-provisioner` or `e2e-provisioner`
profile. The workflows now select `production-provisioning` or `e2e-testing`,
use profile-specific credential names, pass generic refresh-token name and
environment inputs to the resolver, and reject unsupported profiles. Direct
workflow dispatches resolve the selected profile's client-ID variable; reusable
workflow calls retain their explicit `client_id` input. The E2E dispatch uses
the E2E profile and E2E provisioner credentials.

## RED

Added the profile, secret-name, environment, and E2E dispatch assertions to the
specified contracts.

Command:

```text
bash scripts/github-setup/test-app-auth-contract.sh && bash scripts/github-setup/test-generated-e2e-concurrency-contract.sh
```

Output:

```text
exit=1
expected 'provisioner_profile:' in .../.github/workflows/create-repository.yml
```

This failed because the creation workflow had no profile input and still used
the shared production credential names.

## GREEN

Command:

```text
bash scripts/github-setup/test-app-auth-contract.sh && bash scripts/github-setup/test-generated-e2e-concurrency-contract.sh && shellcheck scripts/github-setup/test-app-auth-contract.sh scripts/github-setup/test-generated-e2e-concurrency-contract.sh && bash -n scripts/github-setup/test-app-auth-contract.sh scripts/github-setup/test-generated-e2e-concurrency-contract.sh && git diff --check
```

Output:

```text
exit=0
GitHub App auth contract checks passed.
Generated repository E2E concurrency contract passed.
```

Focused workflow lint was also run with actionlint. It reported existing
workflow shellcheck warnings in the large creation workflows and the existing
late-function warning in the E2E workflow, but no new profile expression or
missing-input error.

## Quality

Command:

```text
LINT_MODE=check make quality
```

Result: exit 2. The initial run could not resolve `conda.anaconda.org` in the
sandbox. The elevated retry completed contract tests, Go tests, and most
quality checks, then failed on pre-existing repository issues: workflow asset
sync reported `.github/workflows/commit-policy.yml` out of sync, shfmt wanted
unrelated existing contract files reformatted, markdownlint reported existing
plan/report issues, and the final quality aggregate exited 1. No unrelated
files were changed.

## Concerns

- The repository-wide quality target remains red for the pre-existing issues
  listed above.
- GitHub's 25-input `workflow_dispatch` limit required direct creation runs to
  resolve client IDs from profile-specific repository/environment variables;
  reusable calls continue to accept `client_id` explicitly.

## Fix round 1

Addressed all review findings:

1. Removed `client_id` from both reusable workflow interfaces and removed all
   `inputs.client_id` fallbacks. A validation dependency job now emits one
   approved profile key, and each job maps that key once to a coherent client
   ID, private key, client secret, refresh token, refresh-secret name, and
   environment tuple.
2. Migrated `test-personal-app-e2e.yml` to
   `production-provisioner`, the three explicit production secret names, the
   production client-ID variable, and `production-provisioning` for cleanup.
3. Moved profile validation into a no-environment prerequisite job. Creation
   and cleanup environments consume only its validated output, so unsupported
   values fail before production or E2E environment attachment.
4. Removed the dead generated-E2E `client_id` input and stopped passing a
   provisioner refresh-secret name to the lifecycle resolver. The resolver's
   required generic field is empty for that app-token-only path.
5. Centralized profile credential selection in per-job `PROVISIONER_*` env
   mappings; resolver calls consume those selected values instead of repeating
   independent profile expressions.

### Fix RED

Extended the two contracts for removed reusable `client_id`, validated
pre-environment selection, centralized mapping, personal E2E migration, and
lifecycle resolver behavior.

Command:

```text
bash scripts/github-setup/test-app-auth-contract.sh && bash scripts/github-setup/test-generated-e2e-concurrency-contract.sh
```

Output:

```text
exit=1
expected 'needs.validate-provisioner.outputs.profile' in .../.github/workflows/create-repository.yml
```

### Fix GREEN

Command:

```text
bash scripts/github-setup/test-app-auth-contract.sh && bash scripts/github-setup/test-generated-e2e-concurrency-contract.sh && shellcheck scripts/github-setup/test-app-auth-contract.sh scripts/github-setup/test-generated-e2e-concurrency-contract.sh && bash -n scripts/github-setup/test-app-auth-contract.sh scripts/github-setup/test-generated-e2e-concurrency-contract.sh && git diff --check
```

Output:

```text
exit=0
GitHub App auth contract checks passed.
Generated repository E2E concurrency contract passed.
```

Focused actionlint command:

```text
.provider/bin/micromamba run -n github-bootstrap actionlint .github/workflows/create-repository.yml .github/workflows/terraform-create-repository.yml .github/workflows/test-generated-repository-e2e.yml .github/workflows/test-personal-app-e2e.yml
```

It exited 1 only for pre-existing shellcheck warnings (SC2129/SC2086 in the
creation workflows and SC2218 in the E2E workflow); it reported no new
workflow schema, expression, or required-input errors from this fix round.

## Final verification fix

The auth contract already had all three helper declarations above its first
assertion on this branch. Added a focused source-order regression guard so a
future assertion cannot be introduced before `assert_contains`,
`assert_not_contains`, or `assert_not_line` is defined.

Verification:

```text
bash scripts/github-setup/test-app-auth-contract.sh
GitHub App auth contract checks passed.

shellcheck scripts/github-setup/test-app-auth-contract.sh
exit=0

bash -n scripts/github-setup/test-app-auth-contract.sh
exit=0

git diff --check
exit=0
```

## Final whole-branch review fix

### Changes

1. Audited every `.github/workflows` caller of `resolve-gh-token`. App-user
   provisioner callers pass the validated profile refresh-secret name and
   environment; installation-token callers explicitly pass
   `refresh_token_secret: ""`.
2. Replaced profile-sensitive `condition && E2E || PRODUCTION` mappings in both
   creation workflows with validated outputs for the environment and manifest
   credential keys. Cleanup jobs now also depend directly on the validation job
   before attaching an environment.
3. Extended the auth contract to require the input for every caller, require
   explicit empties for installation callers, require indexed validated
   mappings, and reject profile fallback expressions.

### TDD evidence

The extended auth contract failed before implementation with:

```text
expected 'environment: ${{ needs.validate-provisioner.outputs.environment }}' in .../.github/workflows/create-repository.yml
```

After implementation, these focused contracts passed:

```text
bash scripts/github-setup/test-app-auth-contract.sh
bash scripts/github-setup/test-generated-e2e-concurrency-contract.sh
bash scripts/github-setup/test-refresh-token-secret-scope-contract.sh
bash scripts/github-setup/test-app-credential-profile-contract.sh
bash scripts/github-setup/test-install-app-secrets-contract.sh
```

ShellCheck and Bash syntax checks passed for the changed contracts, and
`git diff --check` passed. `actionlint` reported only the pre-existing
SC2129/SC2086 warnings in the creation workflows.

## Final fix round 2

The source-order regression guard now detects assertion invocations with
optional leading whitespace while excluding `assert_*() {` function
definitions.

Regression checks:

```text
indented assertion before definition: detected
definition before indented assertion: ignored as a definition
```

Verification:

```text
bash scripts/github-setup/test-app-auth-contract.sh
GitHub App auth contract checks passed.

shellcheck scripts/github-setup/test-app-auth-contract.sh
exit=0

bash -n scripts/github-setup/test-app-auth-contract.sh
exit=0

git diff --check
exit=0
```
