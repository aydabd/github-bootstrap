# E2E Maintenance Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable generated E2E repositories to run the complete maintenance PR lifecycle with isolated E2E Writer and Reviewer Apps while leaving production maintenance unchanged.

**Architecture:** Add two E2E maintenance credential profiles and manifests, configure generated repositories through an `e2e-maintenance` Environment, and make maintenance workflow selection explicit. Reuse the existing token resolver, validation helpers, and workflow contracts; no production credential fallback is permitted.

**Tech Stack:** GitHub Actions, GitHub App installation tokens, Bash, jq, JSON manifests, YAML workflows, uv lockfiles, shell contract tests.

**Spec:** `docs/superpowers/specs/2026-09-10-e2e-maintenance-automation-design.md`

## Global Constraints

- Production maintenance workflows and the `production-maintenance` Environment remain unchanged.
- E2E Writer and Reviewer Apps are installed only in the allowlisted disposable E2E owner.
- Generated repositories use the `e2e-maintenance` Environment and never fall back to production credentials.
- Private keys are written only as encrypted Actions Environment secrets; never to repository files, inputs, or logs.
- Writer and Reviewer keys remain separate; no App bypasses rulesets or required reviews.
- Cleanup remains restricted to generated names, the `bootstrap-e2e` topic, and archived repositories.
- Every commit includes a `Signed-off-by` trailer and every commit body line is at most 100 characters.

## File Map

- `docs/github-app-manifests/`: E2E Writer and Reviewer App manifests.
- `scripts/github-setup/app-credential-profiles.json`: canonical profile-to-environment credential names.
- `scripts/github-setup/install-app-secrets.sh`: protected environment credential installer.
- `.github/actions/configure-provisioner-credentials/`: shared generated-repository Environment configuration action.
- `.github/workflows/create-repository.yml` and `terraform-create-repository.yml`: maintenance bundle retention and E2E credential provisioning.
- `templates/.github/workflows/`: maintenance workflow chain shipped to generated repositories.
- `scripts/github-setup/test-*.sh`: static security and workflow contracts.
- `.github/workflows/test-generated-repository-e2e.yml`: live maintenance lifecycle scenario.
- `docs/maintenance-operations.md`: operator setup and rotation instructions.

### Task 1: Define isolated E2E maintenance profiles and manifests

**Files:**

- Modify: `scripts/github-setup/app-credential-profiles.json`
- Modify: `scripts/github-setup/app-credential-profile.sh`
- Create: `docs/github-app-manifests/repository-maintenance-writer-e2e.json`
- Create: `docs/github-app-manifests/repository-maintenance-reviewer-e2e.json`
- Test: `scripts/github-setup/test-app-credential-profile-contract.sh`

**Interfaces:**

- Produces profile IDs `e2e-maintenance-writer` and `e2e-maintenance-reviewer` with Environment `e2e-maintenance`.
- Produces stable client ID, slug, and private-key variable/secret names distinct from production profiles.
- Manifests grant only Writer permissions (`contents`, `issues`, `pull_requests`, `workflows`) and Reviewer permissions (`actions`, `pull_requests`).

- [ ] **Step 1: Add failing assertions** for both profile names, exact environment, credential names, and manifest permissions.
- [ ] **Step 2: Run `bash scripts/github-setup/test-app-credential-profile-contract.sh` and verify it fails for missing profiles.**
- [ ] **Step 3: Add the profiles and manifests using the existing production manifest structure with E2E-specific names.**
- [ ] **Step 4: Run the contract and `jq empty` over both manifests; expect PASS.**
- [ ] **Step 5: Commit with `git commit -s -m "feat: define isolated E2E maintenance Apps"`.**

### Task 2: Add explicit E2E maintenance Environment provisioning

**Files:**

- Modify: `.github/actions/configure-provisioner-credentials/action.yml`
- Modify: `.github/workflows/create-repository.yml`
- Modify: `.github/workflows/terraform-create-repository.yml`
- Modify: `scripts/github-setup/install-app-secrets.sh`
- Test: `scripts/github-setup/test-app-auth-contract.sh`

**Interfaces:**

- The shared action accepts a profile and writes the profile’s client ID/slug variables and private key secret to the named generated-repository Environment.
- The creation workflows pass E2E maintenance profile inputs only for E2E scenarios; production creation continues to use production maintenance configuration.
- No refresh token or client secret is copied to generated repositories.

- [ ] **Step 1: Add contract fixtures proving E2E provisioning targets `e2e-maintenance` and rejects production profile names in E2E mode.**
- [ ] **Step 2: Run `bash scripts/github-setup/test-app-auth-contract.sh` and verify the new assertions fail.**
- [ ] **Step 3: Implement profile-driven variable and encrypted secret writes through the existing shared action.**
- [ ] **Step 4: Add strict validation for repository name, Environment name, profile, and nonempty credential inputs; mask all secret-derived values.**
- [ ] **Step 5: Run `bash scripts/github-setup/test-app-auth-contract.sh` and the installer contract suite; expect PASS.**
- [ ] **Step 6: Commit with `git commit -s -m "feat: provision E2E maintenance credentials"`.**

### Task 3: Make maintenance workflow selection explicit

**Files:**

- Modify: `.github/workflows/create-repository.yml`
- Modify: `.github/workflows/terraform-create-repository.yml`
- Modify: `.github/workflows/test-generated-repository-e2e.yml`
- Test: `scripts/github-setup/test-profile.sh`

**Interfaces:**

- `workflows=maintenance` retains the complete maintenance workflow bundle in a generated repository.
- E2E dispatch requests `quality,maintenance` and configures the generated workflows for `e2e-maintenance`.
- Selected workflow filtering removes every unselected workflow, including maintenance workflows, instead of leaving unknown files behind.

- [ ] **Step 1: Add failing contract checks for the maintenance bundle, complete removal of unselected workflow files, and E2E selection.**
- [ ] **Step 2: Run `bash scripts/github-setup/test-profile.sh` and confirm the checks fail against the current implementation.**
- [ ] **Step 3: Implement one shared allowlist mapping workflow bundle names to exact files in both creation workflows.**
- [ ] **Step 4: Add a deterministic configuration step that changes only the Environment binding for E2E-generated maintenance workflows.**
- [ ] **Step 5: Run the profile and workflow asset contracts; verify `workflows=quality,maintenance` leaves no unrelated workflow files.**
- [ ] **Step 6: Commit with `git commit -s -m "fix: select maintenance workflows explicitly"`.**

### Task 4: Ship the complete maintenance chain in templates

**Files:**

- Create or modify: `templates/.github/workflows/classify-maintenance-pr.yml`
- Create: `templates/.github/workflows/maintenance-safety.yml`
- Create: `templates/.github/workflows/approve-automation-workflows.yml`
- Create: `templates/.github/workflows/merge-maintenance-pr.yml`
- Modify: `templates/.github/workflows/release-please.yml`
- Modify: `templates/.github/linters/.yaml-lint-ignore` only if generated lock metadata requires it
- Test: `scripts/test-action-lint-contract.sh`, `scripts/github-setup/test-app-auth-contract.sh`

**Interfaces:**

- Every workflow uses the configured maintenance Environment and explicit Writer/Reviewer variables and secrets.
- Classification labels only trusted Dependabot and Release Please PRs.
- Approval requires successful required checks, valid Copilot review state, and resolved review threads.
- Merge uses Reviewer approval plus Writer auto-merge authority; Release Please uses the Writer identity.

- [ ] **Step 1: Add failing template contract assertions for all four workflow roles, identity checks, and no default-token writes.**
- [ ] **Step 2: Run `bash scripts/test-action-lint-contract.sh` and `bash scripts/github-setup/test-app-auth-contract.sh`; confirm failure.**
- [ ] **Step 3: Port the existing dogfooding workflow behavior into template workflows, replacing repository-specific paths with shipped template paths.**
- [ ] **Step 4: Add an explicit Environment-name substitution performed only during E2E generation; production templates retain `production-maintenance`.**
- [ ] **Step 5: Run actionlint/zizmor contracts and generated-template asset checks.**
- [ ] **Step 6: Commit with `git commit -s -m "feat: ship maintenance automation in templates"`.**

### Task 5: Add deterministic E2E maintenance lifecycle coverage

**Files:**

- Modify: `.github/workflows/test-generated-repository-e2e.yml`
- Create or modify: `scripts/github-setup/test-generated-maintenance-contract.sh`
- Modify: `docs/maintenance-operations.md`
- Test: `scripts/github-setup/test-generated-maintenance-contract.sh`

**Interfaces:**

- The E2E workflow creates one generated repository with `quality,maintenance`, dispatches a controlled Dependabot-style maintenance PR, and observes the workflow chain.
- The scenario validates labels, quality completion, Copilot review validation, Reviewer approval, Writer auto-merge, and final merged/released state.
- Cleanup archives the exact generated repository and never deletes production repositories.

- [ ] **Step 1: Add a contract fixture defining the required workflow names, E2E Environment, App identity checks, and cleanup assertions.**
- [ ] **Step 2: Run the contract and verify it fails before wiring the live scenario.**
- [ ] **Step 3: Implement bounded polling with explicit timeout and failure diagnostics for each lifecycle transition.**
- [ ] **Step 4: Ensure the cleanup trap runs on success, failure, and cancellation, while preserving the existing name/topic/archive guards.**
- [ ] **Step 5: Run all static contracts and `LINT_MODE=check make quality`.**
- [ ] **Step 6: Commit with `git commit -s -m "test: cover isolated E2E maintenance lifecycle"`.**

### Task 6: Document operator setup and execute live verification

**Files:**

- Modify: `docs/maintenance-operations.md`
- Modify: `README.md`
- Test: live GitHub Actions workflows and generated E2E repository

**Interfaces:**

- Operators receive commands to create both E2E Apps from manifests, install them only in the disposable owner, and store credentials in `e2e-maintenance` without exposing secrets.
- The runbook clearly distinguishes production maintenance from E2E maintenance and documents key rotation/reinstallation.

- [ ] **Step 1: Add the exact non-secret setup commands and safe prompts for private-key/client-secret entry; never print secret values.**
- [ ] **Step 2: Run documentation lint and verify all credential names match `app-credential-profiles.json`.**
- [ ] **Step 3: Manually create/install the E2E Writer and Reviewer Apps and configure the E2E Environment.**
- [ ] **Step 4: Dispatch the focused E2E maintenance workflow from `feat/e2e-maintenance-apps` and capture each generated workflow URL.**
- [ ] **Step 5: Verify the full chain and archived cleanup, then run `gh run view` on the parent workflow with conclusion `success`.**
- [ ] **Step 6: Commit documentation updates with `git commit -s -m "docs: document E2E maintenance App setup"`.**

## Final Verification

- [ ] `bash scripts/run-contract-tests.sh`
- [ ] `LINT_MODE=check make quality`
- [ ] `git diff --check`
- [ ] No production maintenance secret or variable is referenced by E2E workflow paths.
- [ ] One live E2E generated repository completes the maintenance lifecycle and is archived.
- [ ] The worktree is clean and all commits are signed off.
