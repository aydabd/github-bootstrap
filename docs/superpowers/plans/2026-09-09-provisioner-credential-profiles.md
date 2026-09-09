# Provisioner Credential Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make production repository creation and generated E2E execution use distinct, explicitly named GitHub App provisioner credentials with no refresh-token conflict.

**Architecture:** A JSON manifest defines the two provisioner profiles and all credential names. The generic token action accepts profile-selected values and rotates the refresh token into the selected Actions environment. Creation workflows select `production-provisioner` by default for real runs and accept an explicit `e2e-provisioner` selection for generated E2E dispatches; the existing lifecycle App remains separate.

**Tech Stack:** GitHub Actions YAML, composite actions, Bash, `jq`, deterministic shell contracts, GitHub CLI.

**Spec:** `docs/superpowers/specs/2026-09-09-provisioner-credential-profiles-design.md`

## Global Constraints

- Use exactly two provisioner profiles: `production-provisioner` and `e2e-provisioner`.
- Production uses the `production-provisioning` environment; E2E uses `e2e-testing`.
- Never copy or synchronize refresh tokens between profiles.
- Keep `BOOTSTRAP_E2E_APP_*` as the lifecycle App; do not reuse it for provisioning.
- Breaking renames are intentional; do not add legacy aliases or fallback behavior.
- Run focused contracts, ShellCheck, and `LINT_MODE=check make quality` before pushing.

---

### Task 1: Add the credential-profile manifest and profile loader

**Files:**

- Create: `scripts/github-setup/app-credential-profiles.json`
- Create: `scripts/github-setup/app-credential-profile.sh`
- Create: `scripts/github-setup/test-app-credential-profile-contract.sh`
- Modify: `scripts/run-contract-tests.sh`

**Interfaces:**

- Manifest paths are queried with `jq` using profile keys `production-provisioner` and `e2e-provisioner`.
- `app-credential-profile.sh PROFILE FIELD` prints one manifest field and exits nonzero for unknown profiles or fields.

- [ ] **Step 1: Write the failing contract**

Assert that the manifest contains both profiles, distinct environment names, and these exact profile-specific names:

```bash
production_profile="$(bash "$helper" production-provisioner)"
e2e_profile="$(bash "$helper" e2e-provisioner)"
[ "$(jq -r '.environment' <<<"$production_profile")" = production-provisioning ]
[ "$(jq -r '.environment' <<<"$e2e_profile")" = e2e-testing ]
[ "$(jq -r '.refresh_token_secret' <<<"$production_profile")" = BOOTSTRAP_PRODUCTION_PROVISIONER_APP_USER_REFRESH_TOKEN ]
[ "$(jq -r '.refresh_token_secret' <<<"$e2e_profile")" = BOOTSTRAP_E2E_PROVISIONER_APP_USER_REFRESH_TOKEN ]
[ "$(jq -r '.refresh_token_secret' <<<"$production_profile")" != "$(jq -r '.refresh_token_secret' <<<"$e2e_profile")" ]
```

- [ ] **Step 2: Run the contract and verify it fails**

Run: `bash scripts/github-setup/test-app-credential-profile-contract.sh`

Expected: FAIL because the manifest and loader do not exist.

- [ ] **Step 3: Add the manifest, loader, and registration**

Store `client_id_variable`, `private_key_secret`, `client_secret_secret`, `refresh_token_secret`, and `environment` for each profile. Implement the loader with `jq -e` and explicit argument validation; do not return a production profile for an unknown key.

- [ ] **Step 4: Run the contract and ShellCheck**

Run: `bash scripts/github-setup/test-app-credential-profile-contract.sh && shellcheck scripts/github-setup/app-credential-profile.sh scripts/github-setup/test-app-credential-profile-contract.sh`

Expected: PASS with no ShellCheck findings.

- [ ] **Step 5: Commit**

```bash
git add scripts/github-setup/app-credential-profiles.json scripts/github-setup/app-credential-profile.sh scripts/github-setup/test-app-credential-profile-contract.sh scripts/run-contract-tests.sh
git commit -s -m "feat: define provisioner credential profiles"
```

### Task 2: Make installation profile-aware and environment-only

**Files:**

- Modify: `scripts/github-setup/install-app-secrets.sh`
- Modify: `scripts/github-setup/test-install-app-secrets-contract.sh`

**Interfaces:**

- New invocation: `install-app-secrets.sh REPOSITORY PROFILE CLIENT_ID_FILE PRIVATE_KEY_FILE CLIENT_SECRET_FILE REFRESH_TOKEN_FILE`.
- The installer resolves names and environment from `app-credential-profile.sh`, then uses `gh variable set ... --env` and `gh secret set ... --env`.

- [ ] **Step 1: Extend the contract with the breaking interface**

Assert the usage has six arguments, profile resolution is called, and every install command uses `--env "$environment"` with manifest-derived names. Assert no old `BOOTSTRAP_PROVISIONER_APP_*` literals remain in the installer.

- [ ] **Step 2: Run the contract and verify it fails**

Run: `bash scripts/github-setup/test-install-app-secrets-contract.sh`

Expected: FAIL because the installer still accepts five arguments and hardcodes the old names.

- [ ] **Step 3: Implement profile-aware installation**

Resolve fields once, validate all input files, sanitize temporary files, and install the client ID as an environment variable plus the three credentials as environment secrets. Reject unknown profiles before any GitHub mutation.

- [ ] **Step 4: Run focused contracts and ShellCheck**

Run: `bash scripts/github-setup/test-install-app-secrets-contract.sh && shellcheck scripts/github-setup/install-app-secrets.sh`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/github-setup/install-app-secrets.sh scripts/github-setup/test-install-app-secrets-contract.sh
git commit -s -m "feat: install profile-scoped App credentials"
```

### Task 3: Select the correct profile in shared token resolution

**Files:**

- Modify: `.github/actions/resolve-gh-token/action.yml`
- Modify: `scripts/github-setup/test-refresh-token-secret-scope-contract.sh`

**Interfaces:**

- Add required input `refresh_token_secret` and optional input `refresh_token_secret_environment`.
- The action writes the rotated token to `gh secret set "$REFRESH_TOKEN_SECRET" --repo "$GITHUB_REPOSITORY" --env "$REFRESH_TOKEN_SECRET_ENVIRONMENT"`.

- [ ] **Step 1: Extend the contract**

Assert the action requires a secret-name input, uses that input rather than a hardcoded shared name, and requires an explicit environment when refreshing a user token.

- [ ] **Step 2: Run the contract and verify it fails**

Run: `bash scripts/github-setup/test-refresh-token-secret-scope-contract.sh`

Expected: FAIL because the action hardcodes the old refresh-token name and only optionally selects an environment.

- [ ] **Step 3: Implement generic scoped rotation**

Replace the hardcoded secret name with the input, reject an empty environment for app-user refresh mode, and retain generic credential-value inputs. The action must not contain either profile-specific secret name.

- [ ] **Step 4: Run focused contract and ShellCheck**

Run: `bash scripts/github-setup/test-refresh-token-secret-scope-contract.sh && shellcheck scripts/github-setup/test-refresh-token-secret-scope-contract.sh`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add .github/actions/resolve-gh-token/action.yml scripts/github-setup/test-refresh-token-secret-scope-contract.sh
git commit -s -m "fix: make refresh-token rotation profile scoped"
```

### Task 4: Update creation workflow interfaces for production and E2E profiles

**Files:**

- Modify: `.github/workflows/create-repository.yml`
- Modify: `.github/workflows/terraform-create-repository.yml`
- Modify: `.github/workflows/test-generated-repository-e2e.yml`
- Modify: `scripts/github-setup/test-app-auth-contract.sh`
- Modify: `scripts/github-setup/test-generated-e2e-concurrency-contract.sh`

**Interfaces:**

- Creation workflow input `provisioner_profile` accepts exactly `production-provisioner` or `e2e-provisioner`, defaulting to `production-provisioner` for manual/direct runs.
- Creation jobs select `production-provisioning` or `e2e-testing` from that input and dynamically select the profile-specific secret/variable names using the manifest-compatible profile key.
- Generated E2E passes `provisioner_profile: e2e-provisioner`, the E2E client ID, and the E2E refresh-token secret/environment to the resolver.

- [ ] **Step 1: Add failing workflow contracts**

Assert both creation workflows declare the profile input, reject any third profile, select the corresponding environment, and reference only profile-specific credential names. Assert the generated E2E dispatch passes `e2e-provisioner` and never passes production credential names.

- [ ] **Step 2: Run contracts and verify they fail**

Run: `bash scripts/github-setup/test-app-auth-contract.sh && bash scripts/github-setup/test-generated-e2e-concurrency-contract.sh`

Expected: FAIL because workflows currently use shared production names and have no profile input.

- [ ] **Step 3: Implement workflow selection**

Add the profile input and environment selection to both creation workflows, update `workflow_call` secret declarations to the two explicit names, and pass the selected values to the generic resolver. Update E2E dispatch fields and keep matrix serialization.

- [ ] **Step 4: Run focused contracts and YAML/pre-commit checks**

Run: `bash scripts/github-setup/test-app-auth-contract.sh && bash scripts/github-setup/test-generated-e2e-concurrency-contract.sh && LINT_MODE=check make quality`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/create-repository.yml .github/workflows/terraform-create-repository.yml .github/workflows/test-generated-repository-e2e.yml scripts/github-setup/test-app-auth-contract.sh scripts/github-setup/test-generated-e2e-concurrency-contract.sh
git commit -s -m "feat: isolate production and E2E provisioners"
```

### Task 5: Update examples, setup tooling, and operational documentation

**Files:**

- Modify: `README.md`
- Modify: `docs/maintenance-operations.md`
- Modify: `docs/github-app-trust-boundaries.md`
- Modify: `examples/launcher-actions.yml`
- Modify: `examples/launcher-terraform.yml`
- Modify: `terraform/README.md`
- Modify: `scripts/github-setup/test-install-app-secrets-contract.sh`

**Interfaces:**

- Documentation names only `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_*` for real creation and `BOOTSTRAP_E2E_PROVISIONER_APP_*` for E2E.
- Setup commands require `production-provisioner` or `e2e-provisioner` explicitly.

- [ ] **Step 1: Add documentation contract assertions**

Assert examples and docs contain production environment setup, E2E environment setup, and no old shared `BOOTSTRAP_PROVISIONER_APP_` names.

- [ ] **Step 2: Run the documentation contract and verify it fails**

Run: `bash scripts/github-setup/test-install-app-secrets-contract.sh`

Expected: FAIL while old names and five-argument setup instructions remain.

- [ ] **Step 3: Update all operational references**

Document creation of two provisioner GitHub Apps, two environment-scoped credential sets, refresh-token rotation per environment, and the fact that the lifecycle App is separate. Update launcher reusable-workflow examples with profile-specific environment secret mappings.

- [ ] **Step 4: Run all deterministic contracts and search for stale names**

Run: `bash scripts/run-contract-tests.sh && ! rg -n 'BOOTSTRAP_(PRODUCTION|E2E)_PROVISIONER_APP_(CLIENT_ID|PRIVATE_KEY|CLIENT_SECRET|USER_REFRESH_TOKEN)' README.md docs examples terraform scripts .github`

Expected: all contracts pass and the stale-name search returns no matches.

- [ ] **Step 5: Commit**

```bash
git add README.md docs examples terraform/README.md scripts/github-setup/test-install-app-secrets-contract.sh
git commit -s -m "docs: document isolated provisioner Apps"
```

### Task 6: Final verification and live E2E readiness

**Files:**

- Modify: none unless verification identifies a concrete failure.

- [ ] **Step 1: Run the complete local gate**

Run: `LINT_MODE=check make quality`

Expected: exit code 0, all contracts, Go tests, formatters, linters, and pre-commit checks pass.

- [ ] **Step 2: Verify the worktree and commits**

Run: `git status --short --branch && git log --oneline -5`

Expected: clean worktree on `fix/issue-208-e2e`, with signed commits for each completed task.

- [ ] **Step 3: Configure external GitHub state**

Create or authorize the E2E provisioner App, create `production-provisioning` and `e2e-testing`, install each profile through the installer, and verify names with `gh secret list`, `gh secret list --env`, and `gh variable list` without printing values.

- [ ] **Step 4: Run targeted live E2E**

Dispatch `test-generated-repository-e2e.yml` from `fix/issue-208-e2e` with `target_ref=fix/issue-208-e2e`, `creation_workflow=create-repository.yml`, `delivery=embedded`, and the E2E provisioner client ID.

- [ ] **Step 5: Run the full live matrix**

After targeted success, dispatch the same workflow with `creation_workflow=both` and `delivery=both`; verify serialized jobs, successful creation/validation/cleanup, and no unrelated repositories changed.

- [ ] **Step 6: Commit or report any live-only blocker**

If all checks pass, push the final branch and report the PR URL and E2E run URLs. If external App provisioning is not complete, report the exact missing GitHub-side setup without weakening the code contract.
