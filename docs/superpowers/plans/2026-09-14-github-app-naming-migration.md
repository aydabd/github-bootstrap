# GitHub App Naming Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate Issue #214 to consistent production/E2E App names and bindings without deleting existing credentials before verification.

**Architecture:** Keep production maintenance, production provisioning, and all E2E credentials in distinct namespaces. Rename role/profile identifiers and workflow entry points in the repository, use `production` for generated production maintenance, use `e2e` for every disposable E2E job, and make the E2E dispatcher fail closed if production references appear.

**Tech Stack:** GitHub Actions, Bash, jq, JSON manifests, GitHub App environments, shell contract tests.

**Spec:** `docs/superpowers/specs/2026-09-14-github-app-naming-migration-design.md`

## Global Constraints

- Never delete or overwrite an existing App, environment secret, or variable during repository implementation.
- Production generated repositories use only `production` maintenance credentials.
- All disposable E2E workflows use only `e2e` credentials.
- `production-provisioning` remains separate from `production`.
- Private keys, client secrets, and refresh tokens never enter source control, workflow inputs, or logs.
- Every changed shell file passes ShellCheck and shfmt.
- The exact gate is `LINT_MODE=check make quality`.

### Task 1: Rename canonical profiles and manifests

**Files:**

- Modify: `scripts/github-setup/app-credential-profiles.json`
- Modify: `scripts/github-setup/app-credential-profile.sh`
- Modify: `scripts/github-setup/manage-app-setup.sh`
- Modify: `scripts/github-setup/install-app-secrets.sh`
- Rename/create: `docs/github-app-manifests/bootstrap-*.json`
- Test: `scripts/github-setup/test-app-credential-profile-contract.sh`

- [ ] Rename role IDs to the canonical production/e2e names and set environments to `production`, `production-provisioning`, or `e2e`.
- [ ] Rename credential namespaces to `BOOTSTRAP_PRODUCTION_*` and `BOOTSTRAP_E2E_*`.
- [ ] Give each production and E2E App its own manifest name and preserve least-privilege permissions.
- [ ] Update the orchestrator role order, isolation checks, install, rotation, and cleanup allowlists.
- [ ] Extend the profile contract to reject legacy role IDs and verify all canonical metadata.
- [ ] Run the profile and manifest contracts.

### Task 2: Rename workflow entry points and enforce environment separation

**Files:**

- Rename: `.github/workflows/dispatch-e2e.yml`
- Modify: `.github/workflows/create-repository.yml`
- Modify: `.github/workflows/terraform-create-repository.yml`
- Modify: `.github/workflows/test-generated-repository-e2e.yml`
- Modify: `.github/workflows/test-repository-creation.yml`
- Modify: `scripts/select-generated-workflows.sh`
- Modify: `.github/actions/configure-provisioner-credentials/action.yml`
- Test: `scripts/github-setup/test-dispatch-e2e-contract.sh`
- Test: `scripts/github-setup/test-profile.sh`

- [ ] Bind normal generated maintenance workflows to `production`.
- [ ] Bind every E2E creation, maintenance, fixture, and cleanup job to `e2e`.
- [ ] Make `Dispatch E2E` resolve only the E2E Reviewer and E2E provisioner identifiers.
- [ ] Remove production references from the E2E dispatcher and assert their absence.
- [ ] Rename generated workflow job IDs and compatibility entry points to `e2e` terminology.
- [ ] Run workflow/profile/auth contracts and inspect rendered generated workflows.

### Task 3: Rename compatibility scripts and documentation

**Files:**

- Rename: `scripts/github-setup/install-e2e-credentials.sh`
- Modify: `scripts/github-setup/README.md`
- Modify: `README.md`
- Modify: `docs/maintenance-operations.md`
- Modify: `docs/github-app-trust-boundaries.md`
- Modify: `docs/github-app-e2e-plan.md`
- Test: `scripts/github-setup/test-generated-maintenance-contract.sh`
- Test: `scripts/github-setup/test-install-app-secrets-contract.sh`

- [ ] Document the canonical App names, environments, profile IDs, and old-to-new migration map.
- [ ] Document that old Apps remain until additive verification completes.
- [ ] Replace old dispatcher and installer names in operator commands and contracts.
- [ ] State explicitly that production has no fixture or dispatch App.
- [ ] Run documentation and generated-maintenance contracts.

### Task 4: Verify, commit, and hand off operator provisioning

- [ ] Run `scripts/run-contract-tests.sh` and `LINT_MODE=check make quality`.
- [ ] Verify the worktree is clean and commit with a signed-off message.
- [ ] Update PR #238 and Issue #214 with the canonical naming map and the list of new GitHub Apps requiring operator provisioning.
- [ ] Do not remove old Apps or secrets; report the exact post-merge cleanup list and verification commands.
