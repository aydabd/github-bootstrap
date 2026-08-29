# Maintenance Automation Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route weekly tooling, Dependabot, and release-please pull requests through the same verified maintenance lifecycle.

**Architecture:** Add a pure classifier for trusted automation PRs and a pull-request-target labeling workflow using the scoped Maintenance Writer App. Extend the existing safety and merge contracts only where needed, preserving release-please labels and normal ruleset enforcement.

**Tech Stack:** GitHub Actions YAML, Bash, jq, GitHub App tokens, shell contract fixtures.

**Spec:** `docs/superpowers/specs/2026-08-29-maintenance-lifecycle-design.md`

## Global Constraints

- Only same-repository automation PRs from `dependabot[bot]` or release-please automation with `autorelease: pending` are eligible.
- The Writer App labels PRs; the separate Reviewer App approves workflow runs and enables auto-merge.
- No workflow or action change is eligible for automatic workflow approval.
- `autorelease: pending` and existing `dependencies` labels are preserved.
- Rulesets remain authoritative; no bypass actor or administrator merge is introduced.
- `LINT_MODE=check make quality` must pass before completion.

---

### Task 1: Add trusted automation PR classification

**Files:**

- Create: `scripts/github-setup/validate-maintenance-pr.sh`
- Create: `scripts/github-setup/test-maintenance-pr-contract.sh`
- Modify: `scripts/run-contract-tests.sh`

**Interfaces:**

- `validate-maintenance-pr.sh PR_JSON` exits zero only for an open, non-fork PR whose author is `dependabot[bot]`, or whose author is `release-please[bot]`/`github-actions[bot]` and whose labels include `autorelease: pending`.
- On success it prints a tab-separated classification (`dependabot` or `release-please`) and exits non-zero with a stable diagnostic for invalid input.

- [ ] Write fixtures for accepted Dependabot and release-please PRs.
- [ ] Add rejected fixtures for forks, closed/draft PRs, unknown authors, and release PRs without `autorelease: pending`.
- [ ] Run the focused contract and confirm it fails because the validator is absent.
- [ ] Implement the jq-based validator with explicit repository and label checks.
- [ ] Run the focused contract and confirm all accepted and rejected cases pass.
- [ ] Register it in `scripts/run-contract-tests.sh`.
- [ ] Commit: `feat: classify trusted maintenance pull requests`.

### Task 2: Label Dependabot and release-please PRs through the Writer App

**Files:**

- Create: `.github/workflows/classify-maintenance-pr.yml`
- Modify: `.github/actions/resolve-gh-token/action.yml`
- Modify: `docs/github-app-manifests/repository-maintenance-writer.json`
- Modify: `scripts/github-setup/test-app-auth-contract.sh`
- Modify: `scripts/github-setup/test-app-manifest-contract.sh`
- Modify: `docs/github-app-permission-matrix.md`

**Interfaces:**

- The workflow triggers on `pull_request_target` events `opened`, `synchronize`, and `reopened`.
- It resolves the Writer App with a `maintenance-labeling` profile requiring `issues: write` and `pull-requests: read`, validates the PR, then idempotently adds `automation: maintenance` and `automation: validating` while retaining existing labels.

- [ ] Add failing contract assertions for the workflow trigger, scoped profile, validator invocation, and label mutations.
- [ ] Extend the resolver with the least-privilege `maintenance-labeling` profile.
- [ ] Add the profile permission to the Writer App manifest and permission matrix.
- [ ] Implement the workflow with same-repository identity checks and idempotent label application.
- [ ] Run app-auth and manifest contracts.
- [ ] Commit: `feat: route automation pull requests into maintenance gates`.

### Task 3: Extend lifecycle gates and scenarios

**Files:**

- Modify: `scripts/github-setup/validate-workflow-approval.sh`
- Modify: `scripts/github-setup/validate-maintenance-merge.sh`
- Modify: `scripts/github-setup/test-workflow-approval-contract.sh`
- Modify: `scripts/github-setup/test-maintenance-merge-contract.sh`
- Modify: `scripts/github-setup/test-maintenance-safety-contract.sh`
- Modify: `scripts/github-setup/test-app-auth-contract.sh`

- [ ] Add release-please fixtures to workflow approval and merge validation.
- [ ] Assert release labels remain present while common maintenance labels are added.
- [ ] Cover successful, blocked, stale, failed-check, unsafe-workflow, and missing-review cases for both automation sources.
- [ ] Keep reviewer approval mandatory before auto-merge and reject reviewer self-authored PRs.
- [ ] Run all focused lifecycle contracts and the aggregate contract suite.
- [ ] Commit: `test: cover dependabot and release maintenance gates`.

### Task 4: Document and verify the lifecycle

**Files:**

- Modify: `README.md`
- Modify: `docs/github-app-trust-boundaries.md`
- Modify: `.github/pull_request_template.md` only if lifecycle validation wording requires it.

- [ ] Document the three automation sources, label transitions, and separate Writer/Reviewer roles.
- [ ] Run `git diff --check`.
- [ ] Run `bash scripts/run-contract-tests.sh`.
- [ ] Run `LINT_MODE=check make quality`.
- [ ] Inspect generated/template parity and verify no bypass actor or direct merge command was introduced.
- [ ] Commit: `docs: document maintenance automation lifecycle`.
