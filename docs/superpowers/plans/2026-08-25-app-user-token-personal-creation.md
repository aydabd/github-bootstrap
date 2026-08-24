# App User-Token Personal Repository Creation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Support personal-account repository creation with a GitHub App user access token while retaining installation-token organization creation as the default.

**Architecture:** Extend the shared resolver with an explicit `app-user` mode selected only when a protected App user token is supplied. Validate `/user` identity against the target owner before creation, then use the existing installation-token path for organization owners. No PATs, dispatch credential inputs, or generated-repository secrets are introduced.

**Tech Stack:** GitHub Actions YAML, composite Bash action, GitHub CLI, deterministic shell contract tests, Markdown documentation.

**Spec:** Approved design in the current conversation; official GitHub REST repository-authentication documentation.

## Global Constraints

- Installation tokens remain the default documented organization path.
- App user tokens are the only personal-account path; PATs remain unsupported.
- Private keys, PATs, and tokens are never workflow-dispatch inputs.
- Personal mode must prove the App user-token identity matches `target_owner` before creation.
- Organization mode must retain App installation owner binding and repository scoping.
- No Vault/OIDC implementation is included.

---

### Task 1: Add failing resolver and workflow contract tests

**Files:**

- Modify: `scripts/github-setup/test-app-auth-contract.sh`
- Modify: `scripts/github-setup/test-profile.sh`

- [x] **Step 1: Add assertions for explicit App user-token mode.**

Assert the resolver exposes `app_user_token`, validates the authenticated user, emits `mode=app-user`, and does not use PAT terminology.

- [x] **Step 2: Add assertions for personal workflow wiring.**

Assert both creation workflows expose an optional `BOOTSTRAP_APP_USER_TOKEN` reusable secret and pass it only to the resolver. Assert the old organization-only audit error is removed or updated.

- [x] **Step 3: Run the contract tests and verify failure.**

Run:

```bash
scripts/github-setup/test-app-auth-contract.sh
```

Expected: fail because the resolver and creation workflows do not yet expose the App user-token path.

### Task 2: Implement the resolver’s App user-token path

**Files:**

- Modify: `.github/actions/resolve-gh-token/action.yml`
- Modify: `scripts/github-setup/validate-app-auth.sh`

- [x] **Step 1: Add optional `app_user_token` input.**

Keep existing App installation inputs required for organization mode, but allow the user-token mode to select an App user token explicitly.

- [x] **Step 2: Validate user-token identity fail-closed.**

Use `gh api /user --jq .login` with the masked token, compare case-insensitively to `TARGET_OWNER`, and reject mismatches before emitting any auth mode output.

- [x] **Step 3: Preserve installation-token validation and scope.**

When no App user token is supplied, retain current profile validation, owner matching, repository scoping, permission profiles, and pinned `actions/create-github-app-token` invocation unchanged.

- [x] **Step 4: Run the contract tests and verify they pass.**

Run the auth and profile contract tests; expected result is PASS.

### Task 3: Wire personal creation through both creation workflows

**Files:**

- Modify: `.github/workflows/create-repository.yml`
- Modify: `.github/workflows/terraform-create-repository.yml`
- Modify: `.github/actions/audit-bootstrap-request/action.yml`

- [x] **Step 1: Add optional reusable workflow secret.**

Add `BOOTSTRAP_APP_USER_TOKEN` as an optional `workflow_call` secret and pass it to the resolver. Do not add it to `workflow_dispatch` inputs.

- [x] **Step 2: Make owner-type auditing match the selected mode.**

Permit personal owners when `auth_mode=app-user`; continue rejecting personal owners for installation-token mode. Keep organization owner allowlist validation mandatory.

- [x] **Step 3: Ensure cleanup uses the correct token path.**

For personal creation, retain the App user token for cleanup and validate its identity against the created repository owner. For organization creation, retain the scoped installation-token cleanup path.

- [x] **Step 4: Run YAML and contract checks.**

Run `actionlint`, the auth/profile tests, and `git diff --check`.

### Task 4: Update secure documentation and E2E plan

**Files:**

- Modify: `README.md`
- Modify: `terraform/README.md`
- Modify: `docs/github-app-e2e-plan.md`
- Modify: `docs/github-app-permission-matrix.md`

- [x] **Step 1: Document both App modes.**

Explain that organization creation uses installation tokens by default, while personal creation uses an App user token obtained through App authorization. State that neither PATs nor dispatch credential inputs are supported.

- [x] **Step 2: Clarify secret delivery.**

Require protected caller/environment or external secret delivery for the App private key and App user token; never store either in Git, generated repositories, or test repositories. Keep Vault/OIDC explicitly deferred to issue #92.

- [x] **Step 3: Update the E2E plan.**

Require credentialed tests for organization installation-token creation and personal App user-token creation, identity mismatch rejection, cleanup, and cross-owner isolation. State that organization deletion/App revocation require explicit authorized cleanup.

### Task 5: Verify, review, and amend the focused commit

**Files:**

- All files changed by Tasks 1–4.

- [x] **Step 1: Run targeted tests and complete lint.**

```bash
scripts/github-setup/test-app-auth-contract.sh
scripts/github-setup/test-profile.sh
actionlint -ignore 'SC[0-9]+' .github/workflows/*.yml
LINT_MODE=check make lint
git diff --check
```

- [x] **Step 2: Run a separate Superpowers security review.**

Review owner identity binding, App user-token exposure, installation-token scope, workflow secrets, cleanup behavior, and PAT exclusion. Fix every actionable finding.

- [ ] **Step 3: Amend and push the existing signed-off conventional commit.**

```bash
git add <changed-files>
git commit --amend --no-edit -s
git push --force-with-lease origin github-app-auth-issue-86
```

- [ ] **Step 4: Reply to and resolve review threads only after verification.**

Confirm the remote PR head matches the final commit and all actionable threads are resolved.
