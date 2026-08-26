# Commit Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a clean, reusable commit-policy workflow for the dogfooding repository, generated repositories, and monorepos.

**Architecture:** The template `.github` assets are canonical; root assets are byte-identical dogfooding copies validated by the asset checker. A thin `commit-policy.yml` workflow delegates to independent composite actions for sign-off trailers, conventional commit messages, and pull-request titles. Commitlint uses the centralized conventional default when a repository has no local configuration, while explicit inputs allow monorepo overrides.

**Tech Stack:** GitHub Actions, composite actions, GitHub CLI, `jq`, mise, commitlint, YAML, Bash.

**Spec:** `docs/superpowers/specs/2026-08-26-commit-policy-design.md`

## Global Constraints

- The canonical policy assets live under `templates/.github/`.
- Root `.github/` assets are dogfooding copies and must remain byte-identical to their template counterparts.
- Each action has one responsibility and communicates through explicit inputs.
- Generated repositories receive local copies and do not depend on this repository at runtime.
- Sign-off validation uses `gh api --paginate --slurp` and `jq`.
- A repository without commitlint configuration uses `@commitlint/config-conventional`.
- Repository-specific rules are local overrides and must not modify the canonical shared action.
- Third-party actions and tooling versions are pinned according to repository policy.

---

### Task 1: Define reusable policy action interfaces

**Files:**
- Create: `templates/.github/actions/verify-conventional-commits/action.yml`
- Create: `.github/actions/verify-conventional-commits/action.yml`
- Create: `templates/.github/actions/verify-pull-request-title/action.yml`
- Create: `.github/actions/verify-pull-request-title/action.yml`
- Modify: existing sign-off action files to retain the finalized `gh`/`jq` implementation

**Interfaces:**
- Conventional-commit action consumes `token`, `repository`, `pull-request-number`, and optional `config-path`; it checks every PR commit and uses `@commitlint/config-conventional` when `config-path` is absent.
- PR-title action consumes `title` and optional `config-path`; it validates the supplied title using the repository’s commitlint configuration or centralized conventional default.
- Sign-off action continues to consume `token`, `repository`, and `pull-request-number` and remains independent of commitlint.

- [ ] **Step 1: Add failing fixture checks**

  Add representative valid and invalid commit/title inputs to the action test command or repository validation script, including a repository with no local commitlint configuration.

- [ ] **Step 2: Run the fixture checks and verify failure**

  Run `bash scripts/check-github-workflow-assets.sh` and the focused policy fixture command; expect failure until the new actions and parity assets exist.

- [ ] **Step 3: Implement the actions**

  Use pinned `mise` and commitlint packages for commit-message/title validation. Keep the sign-off action’s `gh api --paginate --slurp` and `jq` implementation unchanged except for required interface cleanup.

- [ ] **Step 4: Run focused validation**

  Run `bash scripts/check-github-workflow-assets.sh`, YAML validation, `git diff --check`, and all valid/invalid fixtures; expect valid inputs to pass and invalid inputs to fail.

- [ ] **Step 5: Commit**

  `git add .github/actions templates/.github/actions scripts && git commit -s -m "feat: add reusable commit policy actions"`

### Task 2: Add the thin commit-policy workflow

**Files:**
- Create: `templates/.github/workflows/commit-policy.yml`
- Create: `.github/workflows/commit-policy.yml`
- Remove: `.github/workflows/signed-off-by.yml`
- Remove: `templates/.github/workflows/signed-off-by.yml`

**Interfaces:**
- The workflow invokes the three independent local actions and passes only event context and explicit policy inputs.
- Each policy responsibility is an independent job with its own check name, timeout, permissions, and failure result.

- [ ] **Step 1: Write workflow structure validation**

  Extend the asset validation script to require both `commit-policy.yml` files and to reject the obsolete standalone sign-off workflow.

- [ ] **Step 2: Run validation and verify failure**

  Run `bash scripts/check-github-workflow-assets.sh`; expect failure while the new workflow is absent.

- [ ] **Step 3: Implement the workflow**

  Use `pull_request` against `main`, `permissions: {}`, pinned checkout with `persist-credentials: false`, `timeout-minutes: 5`, and separate jobs for sign-off, conventional commits, and PR title. Keep the local checkout on the PR revision so local actions exist.

- [ ] **Step 4: Verify workflow parity**

  Run the asset checker, YAML validation, and `cmp -s .github/workflows/commit-policy.yml templates/.github/workflows/commit-policy.yml`.

- [ ] **Step 5: Commit**

  `git add .github/workflows templates/.github/workflows scripts && git commit -s -m "ci: centralize commit policy workflow"`

### Task 3: Support default and monorepo-specific commitlint configuration

**Files:**
- Modify: `templates/.github/actions/verify-conventional-commits/action.yml`
- Modify: `.github/actions/verify-conventional-commits/action.yml`
- Modify: `templates/.github/workflows/commit-policy.yml`
- Modify: `.github/workflows/commit-policy.yml`
- Document: `templates/CONTRIBUTING.md` and `CONTRIBUTING.md`

**Interfaces:**
- Default mode installs and invokes `@commitlint/config-conventional` without requiring a repository config file.
- Override mode accepts a repository-local config path and invokes it without changing the shared action implementation.
- Monorepo callers can select the working directory/config path while retaining the same policy action.

- [ ] **Step 1: Add default/override fixtures**

  Test one valid conventional commit and one invalid commit with no config, then repeat with a temporary local config that adds a repository-specific rule.

- [ ] **Step 2: Run fixtures and verify failure**

  Run the focused action fixture command; expect the override fixture to fail until config-path and working-directory inputs are wired.

- [ ] **Step 3: Implement explicit inputs and documentation**

  Add documented inputs with defaults, keep the default centralized, and explain in both contribution guides that monorepos may override local configuration while sign-off remains a separate DCO check.

- [ ] **Step 4: Run focused verification**

  Run the default and override fixtures, Markdown formatting checks, YAML validation, parity checks, and `git diff --check`.

- [ ] **Step 5: Commit**

  `git add .github templates/.github CONTRIBUTING.md templates/CONTRIBUTING.md && git commit -s -m "docs: document commit policy defaults and overrides"`

### Task 4: Final repository verification

**Files:**
- Modify: `scripts/check-github-workflow-assets.sh` only if a missing parity assertion is discovered

- [ ] **Step 1: Run the complete local verification set**

  Run `bash scripts/check-github-workflow-assets.sh`, YAML validation, Markdown formatting checks, all policy fixtures, and `git diff --check`.

- [ ] **Step 2: Confirm source-of-truth parity**

  Compare every root/template workflow and action pair with `cmp -s`; confirm generated template paths contain all required policy assets.

- [ ] **Step 3: Review the final diff**

  Confirm no policy logic is duplicated in workflow callers, no sign-off action depends on commitlint, and no repository-specific configuration was added to the canonical action.

- [ ] **Step 4: Commit verification-only changes if required**

  `git add scripts && git commit -s -m "test: enforce commit policy asset parity"`
