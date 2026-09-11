# Maintenance Credential Isolation Implementation Plan

<!-- markdownlint-disable MD013 -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure production and E2E generated repositories receive only their own maintenance App credentials, while E2E fixture setup is explicit and fail-closed.

**Architecture:** Extend the canonical App profile registry with production maintenance Writer/Reviewer profiles and a dedicated E2E fixture App profile. Reuse one validated composite action from both repository-creation workflows to copy the selected maintenance profile into the matching target Environment. Add one operator script for source E2E fixture setup and preflight checks, keeping the fixture App credentials out of generated repositories.

**Tech Stack:** GitHub Actions YAML, Bash, JSON profile registry, shell contract tests, GitHub CLI.

**Spec:** `docs/superpowers/specs/2026-09-10-e2e-maintenance-automation-design.md`

## Global Constraints

- Production uses only `production-maintenance`; E2E uses only `e2e-maintenance`.
- No credential fallback, compatibility alias, or cross-environment secret read is allowed.
- Private keys, client secrets, and refresh tokens must be read from protected files/stdin and never appear in arguments or logs.
- Production maintenance credentials may be copied to generated production repositories; the E2E fixture App credentials must remain only in the source E2E environment. Runtime fixture access tokens must be short-lived App user tokens.
- App installation is operator-created and must produce an explicit preflight error when unavailable.
- Keep App names, variable names, secret names, and environments in one canonical profile source.

### Task 1: Add canonical production maintenance profiles

**Files:**

- Modify: `scripts/github-setup/app-credential-profiles.json`
- Modify: `scripts/github-setup/app-credential-profile.sh`
- Test: `scripts/github-setup/test-app-credential-profile-contract.sh`
- Test: `scripts/github-setup/test-profile.sh`

- [ ] Add `production-maintenance-writer` and `production-maintenance-reviewer` entries with the existing production variable/secret names and `production-maintenance` environment.
- [ ] Extend the profile loader validation so all four maintenance profiles expose the same role-specific fields.
- [ ] Add failing assertions for profile/environment/name isolation, then run the contract tests and observe failure.
- [ ] Implement the registry/loader changes and rerun the focused contracts.

### Task 2: Reuse one maintenance credential configuration action

**Files:**

- Modify: `.github/actions/configure-provisioner-credentials/action.yml`
- Modify: `.github/workflows/create-repository.yml`
- Modify: `.github/workflows/terraform-create-repository.yml`
- Test: `scripts/github-setup/test-app-auth-contract.sh`
- Test: `scripts/github-setup/test-generated-maintenance-contract.sh`

- [ ] Add failing contract assertions that production create and Terraform create configure both production maintenance profiles, while E2E paths configure only E2E profiles.
- [ ] Generalize the action input validation to accept the four canonical maintenance profiles and require the profile-selected environment.
- [ ] Add production maintenance secret forwarding to reusable workflow interfaces and configure the target repository only on production-provisioner runs.
- [ ] Keep E2E maintenance forwarding conditional on e2e-provisioner and preserve its existing environment guard.
- [ ] Add explicit App-installation preflight calls against the generated repository, with role/profile-specific errors and no fallback.
- [ ] Run focused contract tests after each green implementation step.

### Task 3: Standardize complete source E2E setup

**Files:**

- Create: `scripts/github-setup/install-e2e-maintenance-credentials.sh`
- Modify: `scripts/github-setup/install-app-secrets.sh`
- Modify: `docs/maintenance-operations.md`
- Modify: `README.md`
- Test: `scripts/github-setup/test-generated-maintenance-contract.sh`

- [ ] Add failing tests requiring the setup script to validate Writer/Reviewer/fixture App credential directories, the fixed `e2e-maintenance` environment, and the exact secret/variable names.
- [ ] Implement protected-file validation and idempotent writes for both E2E maintenance Apps plus the fixture App's `ghr_` refresh token.
- [ ] Ensure the script checks the target owner/repository scope and emits a remediation URL for missing App installation without printing secret values.
- [ ] Replace duplicated runbook setup commands with the single script, retaining a separate production runbook.
- [ ] Run shellcheck and the focused setup contracts.

### Task 4: Add production/E2E end-to-end contract coverage

**Files:**

- Modify: `scripts/github-setup/test-app-auth-contract.sh`
- Modify: `scripts/github-setup/test-profile.sh`
- Modify: `scripts/github-setup/test-generated-maintenance-contract.sh`
- Modify: `docs/maintenance-operations.md`

- [ ] Add fixtures proving production generated workflows reference only production maintenance names and E2E generated workflows reference only E2E names.
- [ ] Add assertions that production never references the fixture App and E2E never references production maintenance credentials.
- [ ] Add assertions that both create workflows fail on missing installation and that the generated repository receives its matching Environment credentials.
- [ ] Document account-wide App installation for both owners and the exact manual preflight sequence.

### Task 5: Verify, update PR, and run live preflight

**Files:**

- Modify: `docs/superpowers/plans/2026-09-10-maintenance-credential-isolation.md`
- Modify: PR 212 description if needed

- [x] Run the focused contracts and `git diff --check`.
- [ ] `bash scripts/run-contract-tests.sh` is blocked at the localhost manifest fixture (exit 1: `PermissionError: [Errno 1] Operation not permitted`).
- [ ] `LINT_MODE=check ENV_MANAGER=system make quality` is not lint-complete: the exact command exits 2 during uv cache setup; with a temporary writable cache it stops at the same manifest fixture before linting.
- [x] Inspect the final diff for cross-environment references and secret output.
- [x] Commit local plan/report documentation with a signed-off trailer.
- [ ] Push the PR branch (intentionally deferred; external GitHub state is out of scope).
- [x] Verify source environment names and secret/variable names without reading values.
- [ ] Run production/E2E dry preflights (intentionally deferred; this local-only pass does not access external GitHub state).
- [ ] Dispatch live E2E and record generated-repository evidence in the PR (intentionally deferred; prohibited by task scope).
