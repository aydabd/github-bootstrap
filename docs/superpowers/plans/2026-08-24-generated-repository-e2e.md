# Generated Repository E2E Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the credentialed repository-creation E2E workflow verify generated quality behavior across all providers and both embedded and centralized delivery.

**Architecture:** Add a manual scenario matrix. Each scenario creates a real temporary repository through either production creation workflow, verifies generated assets and rulesets, waits for the generated quality workflow to complete successfully, and cleans up the repository. Centralized scenarios receive an existing user-owned central workflow repository and immutable ref as inputs, so the test never creates or mutates a user's central repository.

**Tech Stack:** GitHub Actions, Bash, GitHub CLI, GitHub REST API, jq.

**Spec:** `docs/superpowers/specs/2026-08-23-profiled-reusable-workflows-design.md`

## Global Constraints

- Use the production repository-creation workflows; do not simulate generation locally.
- Run the full matrix manually with credentials because it creates and deletes repositories.
- Require generated `quality.yml` to finish successfully; dispatching it alone is insufficient.
- Verify the forward-only quality contract: `quality` is present and legacy `lint` workflow/assets are absent.
- Clean up temporary repositories on success and failure.

### Task 1: Add scenario matrix inputs and outputs

**Files:**

- Add: `.github/workflows/test-generated-repository-e2e.yml`

- [x] Add a provider/delivery matrix and a creation-workflow choice for focused debugging.
- [x] Pass scenario provider and delivery inputs to either production creation workflow.
- [x] Preserve unique repository names per matrix scenario.

### Task 2: Verify generated repository contracts

**Files:**

- Modify: `.github/workflows/test-generated-repository-e2e.yml`

- [x] Assert embedded repositories contain local quality actions/workflows and no centralized caller.
- [x] Assert centralized repositories contain only the caller and no local quality implementation.
- [x] Assert the caller, profile manifest, and immutable ref contain the requested central source.
- [x] Assert legacy lint workflow files and required-check contexts are absent.
- [x] Assert the profile manifest, signed-off-by workflow, and quality status rule are present as appropriate.

### Task 3: Poll generated quality runs and cleanup

**Files:**

- Modify: `.github/workflows/test-generated-repository-e2e.yml`

- [x] Locate the generated repository's quality workflow run after dispatch using event and creation timestamp.
- [x] Poll until completion and fail on any non-success conclusion.
- [x] Clean up the exact generated repository from an EXIT trap.
- [x] Include scenario and quality-run URLs in the job output.

### Task 4: Validate and document the E2E workflow

**Files:**

- Modify: `.github/workflows/test-generated-repository-e2e.yml`
- Modify: profile and centralized capability contract tests.

- [x] Run actionlint, yamllint, profile validation, and diff checks.
- [x] Document manual invocation inputs and required credentials in the workflow itself.
- [ ] Run the credentialed hosted matrix; this requires a GH_PAT and, for centralized cases, a user-owned central workflow repository/ref.
- [ ] Commit and push the implementation, then inspect hosted E2E results.
