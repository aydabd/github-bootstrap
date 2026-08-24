# Profiled Reusable Workflows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the generated repository's monolithic `lint` contract with a manifest-driven quality profile that supports embedded composite actions/reusable workflows and user-owned centralized workflow repositories.

**Architecture:** Store profile and capability metadata in a template JSON manifest. Render embedded capability workflows/actions from the manifest and render centralized callers that reference a user-supplied repository/ref. Derive ruleset checks from validated installed profile entries, with `quality` and `Signed-off-by trailers` as the stable baseline contract.

**Tech Stack:** GitHub Actions YAML, composite actions, Bash, jq, Go contract tests, Terraform workflow inputs, release-please Conventional Commits.

**Spec:** `docs/superpowers/specs/2026-08-23-profiled-reusable-workflows-design.md`

## Global Constraints

- The old `lint` workflow and `lint` required check are removed; no compatibility alias is retained.
- Baseline assets are installed by default; the `planning` bundle is disabled unless selected.
- Every generated asset is classified as `baseline`, `optional:<bundle>`, or `provider-specific`.
- Embedded mode must work without another repository; centralized mode references a user-owned repository at an explicit immutable ref.
- Existing repositories are not automatically migrated or modified.
- Generated workflows and actions use SHA-pinned third-party actions and least-privilege permissions.
- Release metadata must use a `feat!` commit and `BREAKING CHANGE:` footer so release-please emits a major release.
- `LINT_MODE=check make lint` must pass before completion.

---

### Task 1: Add the profile manifest and validation contract

**Files:**

- Create: `templates/.github/config/bootstrap-profile.json`
- Create: `scripts/github-setup/validate-profile.sh`
- Create: `scripts/github-setup/test-profile.sh`
- Modify: `scripts/github-setup/README.md`
- Test: `scripts/github-setup/test-profile.sh`

**Interfaces:**

- Manifest top-level keys: `schema_version`, `profiles`, `capabilities`, `bundles`, `delivery_modes`.
- Capability entries expose `id`, `classification`, `owned_paths`, `workflow`, `check`, `enabled_by_default`, and `providers`.
- `validate-profile.sh --profile-file PATH --profile NAME --delivery-mode embedded|centralized` exits non-zero for unknown classifications, duplicate IDs/checks, missing owned paths, missing workflow/check metadata, or a centralized profile without repository/ref settings.

- [ ] Write failing shell assertions for baseline defaults, disabled planning, all nine capability IDs, classification completeness, duplicate-check rejection, and centralized-mode input validation.
- [ ] Run `bash scripts/github-setup/test-profile.sh`; verify it fails because the manifest and validator do not exist.
- [ ] Add the JSON manifest with baseline, `planning`, `embedded`, and `centralized` metadata and stable checks `Signed-off-by trailers` and `quality`.
- [ ] Implement POSIX/Bash validation using `jq`, with errors naming the invalid profile path and value.
- [ ] Run the focused test and verify it passes, then run the script twice to prove validation is repeatable.
- [ ] Document profile fields and examples in `scripts/github-setup/README.md`.
- [ ] Commit: `feat: add manifest-driven bootstrap profiles`.

### Task 2: Replace lint with reusable capability actions and workflows

**Files:**

- Create: `templates/.github/actions/quality/run-capability/action.yml`
- Create: `templates/.github/actions/quality/run-quality/action.yml`
- Create: `templates/.github/workflows/quality.yml`
- Create: `templates/.github/workflows/quality-capability.yml`
- Delete: `templates/.github/workflows/lint.yml`
- Delete: `templates/.github/workflows/providers/lint-micromamba.yml`
- Delete: `templates/.github/workflows/providers/lint-mise.yml`
- Delete: `templates/.github/workflows/providers/lint-system.yml`
- Modify: `templates/README.md`
- Modify: `templates/CONTRIBUTING.md`
- Test: `tools/internal/workflowcontract/generated_files_snapshot_test.go`

**Interfaces:**

- `run-capability` inputs: `capability`, `working-directory`, `environment-manager`; it returns a failure for unknown capabilities and runs the selected pinned tool command.
- `run-quality` inputs: `capabilities`, `environment-manager`; it executes the selected capabilities and returns one stable `quality` job/check.
- `quality.yml` supports `workflow_call` inputs `capabilities` and `environment-manager`, plus push, pull request, and manual triggers for embedded repositories.
- `quality-capability.yml` supports `workflow_call` input `capability` for centralized reuse.

- [ ] Add contract tests that assert no generated path contains `lint.yml`, provider lint workflows, or a required check named `lint`, and that `quality.yml`/composite actions expose `workflow_call`/input metadata.
- [ ] Run the contract tests and verify they fail against the current monolithic templates.
- [ ] Implement the generic composite actions with explicit capability dispatch for markdown, JSON, YAML, actions (`actionlint` and `zizmor --pedantic`), shell, Python, Terraform, formatting, and tests.
- [ ] Implement the stable aggregate reusable workflow and capability reusable workflow with `permissions: contents: read`.
- [ ] Update generated README/contributing references from `lint` to `quality`.
- [ ] Run Go workflow-contract tests and static YAML checks; verify the new contract passes.
- [ ] Commit: `feat!: replace monolithic lint with reusable quality capabilities` with a `BREAKING CHANGE:` footer stating that generated repositories must adopt `quality`.

### Task 3: Add embedded/centralized rendering and central-repository examples

**Files:**

- Create: `templates/.github/workflows/centralized-quality.yml`
- Create: `templates/centralized-actions-workflows/README.md`
- Create: `templates/centralized-actions-workflows/.github/workflows/release.yml`
- Create: `templates/centralized-actions-workflows/examples/consumer-quality.yml`
- Create: `templates/centralized-actions-workflows/.github/actions/quality/action.yml`
- Modify: `.github/actions/configure-provider-tooling-files/action.yml`
- Modify: `.github/actions/apply-agent-instructions/action.yml`
- Modify: `scripts/github-setup/README.md`
- Test: `scripts/github-setup/test-profile.sh`

**Interfaces:**

- Centralized caller inputs: `central_repository`, `central_ref`, `capabilities`, and `environment_manager`.
- A centralized caller uses `uses: OWNER/REPO/.github/workflows/quality-capability.yml@REF` and passes only profile configuration; it never copies implementation files.
- Central repository examples show both `workflow_call` consumption and direct composite-action use.

- [ ] Add failing assertions for embedded mode copying local actions/workflows, centralized mode emitting only callers/profile metadata, missing central repository/ref rejection, and no planning workflow unless enabled.
- [ ] Run the focused test and verify it fails before renderer changes.
- [ ] Update the setup actions to select profile assets from the manifest instead of ad-hoc planning file lists, preserving worktree/stack assets.
- [ ] Add the centralized repository seed layout, release workflow, consumer example, pinning guidance, and manual migration instructions.
- [ ] Run profile tests twice and verify identical output for repeat application.
- [ ] Commit: `feat: support embedded and centralized workflow delivery`.

### Task 4: Thread profile selection through repository creation and existing setup

**Files:**

- Modify: `.github/workflows/create-repository.yml`
- Modify: `.github/workflows/setup-existing-repository.yml`
- Modify: `.github/actions/apply-agent-instructions/action.yml`
- Modify: `.github/actions/apply-repository-ruleset/action.yml`
- Modify: `.github/workflows/terraform-create-repository.yml`
- Modify: `terraform/variables.tf`
- Modify: `terraform/main.tf`
- Modify: `terraform/README.md`
- Test: `tools/internal/workflowcontract/input_validation_test.go`

**Interfaces:**

- Workflow inputs: `profile` (default `baseline`), `planning_bundle` (default `false`), `delivery_mode` (default `embedded`), `central_repository`, and `central_ref`.
- Existing `workflows` filtering is replaced by profile capability selection; unknown capability IDs fail validation.
- Terraform variables mirror profile and delivery mode without creating a second asset-selection implementation.

- [ ] Add failing input-validation tests for defaults, invalid profile/mode, missing centralized settings, disabled planning, and removal of `lint` from valid workflow names.
- [ ] Run the focused Go tests and verify the expected failures.
- [ ] Add the inputs to workflow dispatch and workflow-call declarations, validate them before repository creation, and pass them to the profile application step.
- [ ] Remove the old `lint` selection/removal branches and ensure no skipped workflow creates a required check.
- [ ] Thread the same values through Terraform launcher inputs and documentation.
- [ ] Run all workflow-contract tests and verify generated input validation passes.
- [ ] Commit: `feat: expose quality profiles in repository creation`.

### Task 5: Derive and validate ruleset checks from installed profiles

**Files:**

- Modify: `.github/actions/apply-repository-ruleset/action.yml`
- Modify: `scripts/github-setup/setup-ruleset.sh`
- Modify: `.github/config/ruleset-default.json`
- Modify: `.github/config/ruleset-minimal.json`
- Modify: `.github/config/ruleset-coderabbit.json`
- Modify: `scripts/github-setup/test-local-setup-scripts.sh`
- Test: `scripts/github-setup/test-local-setup-scripts.sh`

**Interfaces:**

- Ruleset application consumes `--profile-file PATH --profile NAME --installed-root PATH` and derives checks from manifest entries whose workflow and owned files exist.
- The baseline output contains `Signed-off-by trailers` and `quality`; optional checks are included only when enabled and validated.
- An absent or unknown check produces a hard error before API mutation.

- [ ] Add shell tests proving baseline rulesets contain `quality`, never `lint`, and omit disabled planning checks.
- [ ] Run the test to verify failure against hard-coded `lint` payloads/defaults.
- [ ] Implement manifest-driven check derivation and preserve idempotent create/update behavior.
- [ ] Update action inputs/outputs and setup workflow wiring to pass profile metadata.
- [ ] Run local setup tests twice and verify identical ruleset payloads and no duplicate checks.
- [ ] Commit: `fix: derive ruleset checks from installed profiles`.

### Task 6: Add release notes, examples, and full verification

**Files:**

- Modify: `CHANGELOG.md`
- Modify: `README.md`
- Modify: `templates/SECURITY.md`
- Modify: `.github/workflows/test-repository-creation.yml`
- Modify: `scripts/check-github-workflow-assets.sh`
- Test: `go test ./...` from `tools/`
- Test: `LINT_MODE=check make lint`

- [ ] Add migration guidance stating that existing repositories are not changed automatically and that the old `lint` contract is removed.
- [ ] Add embedded/centralized usage examples and central repository ownership/versioning guidance.
- [ ] Add a release note with the exact breaking change and `quality` replacement.
- [ ] Run generated-file, workflow-asset, shell, API contract, and Terraform tests.
- [ ] Run `go test ./...` from `tools/` and `LINT_MODE=check make lint`.
- [ ] Verify `git diff --check`, no `lint` workflow/check references remain in generated contracts, and release-please sees the breaking commit metadata.
- [ ] Commit: `docs: document profiled workflow delivery and breaking migration`.
