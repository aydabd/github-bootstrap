# GitHub App Manifest Personal E2E Implementation Plan

> Steps use checkbox (`- [ ]`) syntax for tracking. The repository-level workflow skills are supplied by the active agent environment; this plan does not require copies under `.github/skills/`.

**Goal:** Add safe GitHub App Manifest/OAuth bootstrap helpers and a guarded personal-account E2E path using GitHub-generated credentials.

**Architecture:** Shell helpers handle App Manifest conversion and user OAuth without placing credentials in Git, workflows, generated repositories, or logs. Protected local files are the temporary handoff boundary for GitHub-generated credentials. Existing workflows remain the only repository-creation implementation; the E2E harness supplies protected secrets and verifies ownership and cleanup.

**Tech Stack:** Bash, GitHub CLI, GitHub REST API, GitHub Actions reusable workflows.

**Spec:** `docs/superpowers/specs/2026-08-25-app-manifest-personal-e2e-design.md`

## Global Constraints

- GitHub generates the App private key; local code never generates or fabricates one.
- Personal user tokens must have the `ghu_` prefix and match `/user` to the target owner.
- Credentials never enter Git, generated repositories, test repositories, workflow inputs, or logs.
- Organization installation-token E2E remains pending.

### Task 1: Manifest bootstrap helper

**Files:**

- Create: `scripts/github-setup/github-app-manifest.sh`
- Test: `scripts/github-setup/test-app-manifest-contract.sh`

- [ ] Add subcommands `url` and `convert`, strict validation, exact personal permission payload, and protected output behavior.
- [ ] Add contract assertions for permissions and credential-safe output.
- [ ] Run `bash scripts/github-setup/test-app-manifest-contract.sh`.

### Task 2: User-token authorization helper

**Files:**

- Create: `scripts/github-setup/github-app-user-token.sh`
- Test: `scripts/github-setup/test-app-user-token-contract.sh`

- [ ] Implement URL generation and code exchange using a protected client-secret file.
- [ ] Verify the resulting token starts with `ghu_` and `/user` matches the requested owner.
- [ ] Add contract assertions preventing PAT fallback and token logging.
- [ ] Run shell syntax and contract tests.

### Task 3: Protected secret delivery and E2E entry point

**Files:**

- Create: `scripts/github-setup/install-app-secrets.sh`
- Create: `scripts/github-setup/test-personal-app-e2e-contract.sh`
- Modify: `.github/workflows/test-repository-creation.yml`
- Modify: `README.md`

- [ ] Deliver only `BOOTSTRAP_APP_PRIVATE_KEY` and `BOOTSTRAP_APP_USER_TOKEN` from explicit protected files using `gh secret set`.
- [ ] Refuse missing files, non-`ghu_` user tokens, and PAT-like values before any workflow dispatch.
- [ ] Add a guarded personal E2E workflow that runs only the personal scenarios and records no credential values.
- [ ] Document manual App authorization and organization limitation.
- [ ] Run all local contracts and inspect the resulting diff.

### Task 4: Full verification

- [ ] Run deterministic resolver and profile tests.
- [ ] Run YAML/action validation.
- [ ] Run `LINT_MODE=check make lint`.
- [ ] Run the guarded live personal E2E only if real App authorization and protected secrets are present.
- [ ] Re-run final status, diff, and verification checks.
