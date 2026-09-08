# Centralized Monorepo E2E Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a live, isolated E2E preset that creates a temporary centralized workflow repository and a `languages=all` consumer, validates their contracts, runs consumer quality, and safely cleans up both repositories.

**Architecture:** Extend the existing `test-repository-creation.yml` workflow with a `centralized-monorepo` branch that owns both repository names, seeds the central repository through GitHub Contents API commits, and dispatches the existing API creation workflow with the captured SHA. Keep deterministic assertions in a dedicated contract test and expose the live scenario through `make test-centralized-monorepo`; preserve existing embedded and Terraform scenarios unchanged.

**Tech Stack:** GitHub Actions YAML, Bash, GitHub CLI/API, jq, Make, shell contract tests.

**Spec:** `docs/superpowers/specs/2026-09-08-centralized-monorepo-e2e-design.md`

## Global Constraints

- Central refs passed to consumers must be full 40-character commit SHAs.
- The central seed must contain only reusable `workflow_call` workflows and self-contained setup actions.
- The consumer must use `languages=all` and record the exact central repository and SHA.
- Cleanup may target only generated names accepted by the existing allowlist validators.
- `cleanup_after_test=false` must preserve both repositories after a successful run and print deterministic manual deletion commands.
- Deterministic contract tests must not create or mutate GitHub resources.
- Run `LINT_MODE=check make quality` before claiming completion.

---

### Task 1: Add deterministic contracts for the centralized preset

**Files:**

- Create: `scripts/github-setup/test-centralized-monorepo-e2e-contract.sh`
- Modify: `scripts/run-contract-tests.sh`

**Interfaces:**

- Consumes: the workflow, Make target, seed template, and cleanup validator.
- Produces: executable assertions that prevent regressions in preset wiring,
  immutable-ref handling, seed restrictions, dual cleanup, and preservation
  documentation.

- [ ] **Step 1: Write the failing contract assertions.**

  Assert that the workflow declares the `centralized-monorepo` preset, creates
  two generated repository names, uploads the central seed, resolves a full
  commit SHA, passes `delivery_mode=centralized`, `languages=all`, central
  repository, and SHA to the consumer workflow, validates the seed and
  consumer, polls consumer quality, and carries both names into cleanup.
  Assert that the central workflow rejects push/pull-request/dispatch triggers,
  that the Make target invokes the preset with cleanup disabled by default, and
  that the cleanup validator accepts both generated repository name forms.

- [ ] **Step 2: Run the focused contract and confirm it fails for missing behavior.**

  Run `bash scripts/github-setup/test-centralized-monorepo-e2e-contract.sh`.
  Expected: FAIL because the workflow and Make target do not yet contain the
  centralized-monorepo scenario.

- [ ] **Step 3: Register the contract in the deterministic suite.**

  Add the script path to `scripts/run-contract-tests.sh` beside the existing
  E2E lifecycle contracts, retaining the suite’s no-external-resources rule.

- [ ] **Step 4: Run the contract again and keep it red until implementation exists.**

  Run `bash scripts/github-setup/test-centralized-monorepo-e2e-contract.sh` and
  record the expected missing-preset failure before implementation.

- [ ] **Step 5: Commit the test contract.**

  ```bash
  git add scripts/github-setup/test-centralized-monorepo-e2e-contract.sh scripts/run-contract-tests.sh
  git commit -m "test: specify centralized monorepo e2e contracts"
  ```

### Task 2: Implement central seed and consumer orchestration

**Files:**

- Modify: `.github/workflows/test-repository-creation.yml`

**Interfaces:**

- Consumes: existing workflow inputs, `resolve-gh-token`, `create-repository.yml`,
  GitHub Contents API, and cleanup job outputs.
- Produces: a `centralized-monorepo` preset that emits `central_repo_name`,
  `consumer_repo_name`, `central_repository`, `central_ref`, and cleanup-safe
  outputs.

- [ ] **Step 1: Add the preset and input normalization.**

  Add `centralized-monorepo` to the preset choices. When selected, force
  `create-repository.yml`, `languages=all`, `delivery_mode=centralized`,
  `env_manager=system`, `workflows=all`, and `cleanup_after_test` to remain
  caller-controlled. Validate that only this preset enables dual-repository
  behavior and generate names matching the existing E2E cleanup allowlist.

- [ ] **Step 2: Create the central repository and seed it through API commits.**

  Add a step before consumer dispatch that creates the central public
  repository, enumerates files under `templates/centralized-actions-workflows`,
  creates blobs, creates a tree and commit, updates the default branch, and
  writes the full commit SHA plus `owner/name` to `$GITHUB_OUTPUT`. Reject any
  seed workflow containing event triggers other than `workflow_call` before
  publishing it.

- [ ] **Step 3: Dispatch and correlate consumer creation.**

  Extend the existing trigger step to pass `delivery_mode=centralized`,
  `central_repository`, `central_ref`, and `languages=all`. Keep the existing
  actor/time/ref correlation and set `cleanup_on_failure=true`.

- [ ] **Step 4: Validate central and consumer repository contracts.**

  Add explicit API checks for seed files and reusable-only workflows; consumer
  caller workflow and exact pinned SHA; absent embedded quality workflows/actions;
  profile delivery metadata; all monorepo language configs and capabilities;
  existing settings, ruleset, permissions, and required checks. Fail with the
  repository and assertion name for every mismatch.

- [ ] **Step 5: Dispatch and poll consumer quality.**

  Trigger the consumer’s `quality.yml` workflow using the existing token and
  poll by workflow ID/run timestamp until completion. Require a successful
  conclusion and include the run URL in the job summary.

- [ ] **Step 6: Add dual-repository outputs and cleanup wiring.**

  Emit both names from the test job, make cleanup run on failure or when
  `cleanup_after_test=true`, delete each repository independently, and tolerate
  already-missing repositories. On successful preservation, print exact
  `gh repo delete OWNER/REPO --yes` commands for both repositories.

- [ ] **Step 7: Run the focused contract and fix only implementation failures.**

  Run `bash scripts/github-setup/test-centralized-monorepo-e2e-contract.sh`.
  Expected: PASS with no warnings or missing assertions.

### Task 3: Add the developer entrypoint and documentation

**Files:**

- Modify: `make/test.mk`
- Modify: `scripts/github-setup/README.md`
- Modify: `.github/workflows/test-repository-creation.yml`

**Interfaces:**

- Consumes: the new workflow preset and cleanup outputs.
- Produces: a documented `make test-centralized-monorepo` command and a
  workflow summary that explains preservation and deterministic manual cleanup.

- [ ] **Step 1: Add the Make target.**

  Define `test-centralized-monorepo` to dispatch `test-repository-creation.yml`
  with `preset=centralized-monorepo`, `languages=all`, and
  `cleanup_after_test=false`, while allowing the existing test owner/app inputs
  to be supplied by the workflow’s required configuration.

- [ ] **Step 2: Document live execution and cleanup.**

  Document the preset’s two-repository behavior, required App/owner context,
  `cleanup_after_test` tradeoff, retained-repository inspection commands, and
  exact manual cleanup commands. State that cleanup is restricted to generated
  E2E names and that failed runs still use the guarded cleanup path.

- [ ] **Step 3: Run all deterministic contract tests.**

  Run `bash scripts/run-contract-tests.sh`. Expected: all deterministic
  contracts pass; any pre-existing environment-only socket limitation must be
  rerun with the approved elevated path and reported separately.

### Task 4: Verify the complete change

**Files:**

- No new files; inspect all files changed by Tasks 1–3.

- [ ] **Step 1: Run formatting and repository quality checks.**

  Run `LINT_MODE=check make quality` and resolve only failures caused by this
  change.

- [ ] **Step 2: Validate workflow syntax and shell syntax.**

  Run the repository’s actionlint/format checks plus `bash -n` on every changed
  shell script. Confirm the contract suite still passes after formatting.

- [ ] **Step 3: Review the final diff against the spec.**

  Confirm every spec contract has an assertion or live workflow step, no
  existing embedded/Terraform path changed unintentionally, and cleanup cannot
  delete arbitrary repositories.

- [ ] **Step 4: Commit the implementation.**

  ```bash
  git add .github/workflows/test-repository-creation.yml make/test.mk scripts/github-setup/test-centralized-monorepo-e2e-contract.sh scripts/run-contract-tests.sh scripts/github-setup/README.md
  git commit -m "feat: add centralized monorepo e2e scenario"
  ```
