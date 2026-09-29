# Central Governance Runtime Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a machine-readable, least-privilege contract for the central Governance, Reviewer, and Writer App runtime without enabling live migration or changing existing delivery behavior.

**Architecture:** Extend the existing central package manifest with a `runtime` section that describes portable ownership, installation scope, event boundaries, token mode, secret custody, and permissions for the three production roles. Validate the exact contract with a deterministic shell/`jq` test and document how the central runtime connects to consumer-owned triggers, policy, rulesets, and secrets.

**Tech Stack:** JSON, POSIX Bash, `jq`, Markdown, existing deterministic contract-test runner.

**Spec:** GitHub Issue #352, linked to parent Issue #280.

## Global Constraints

- Runtime authentication uses repository-scoped short-lived installation tokens.
- Personal-account refresh-token exchange remains limited to explicit bootstrap/disposable E2E provisioning.
- Hosted/shared App private keys and client secrets remain operator-only and never enter tenant repositories or evidence.
- Runtime Apps have no ruleset-bypass authority.
- User-owned and organization-owned consumers are supported without hardcoding `leniva-ab`.
- Existing embedded and baseline centralized behavior remains unchanged.
- Immutable package refs remain semver release tags or full 40-character commit SHAs.

## Review Focus

- Unknown runtime role or duplicate role — the focused contract test rejects missing/extraneous roles.
- Cross-owner or wildcard repository scope — the focused contract test requires selected repository scope and forbids wildcard/owner-wide values.
- Refresh-token runtime mode — the focused contract test requires `installation` and rejects bootstrap refresh semantics.
- Ruleset bypass or broad administrator permission — the focused contract test requires an explicit false bypass flag and bounded permission keys.
- Credential leakage in the manifest — the focused contract test rejects secret-like fields and requires operator custody wording.

### Task 1: Add the runtime manifest contract and focused test

**Files:**
- Modify: `templates/centralized-actions-workflows/.github/centralized-workflows.json`
- Create: `scripts/github-setup/test-central-runtime-contract.sh`

**Interfaces:**
- Consumes: existing package manifest schema and `ref_policy`.
- Produces: `runtime` object with `service_layout`, `release_policy`, and exactly `governance`, `reviewer`, and `writer` roles.

- [ ] **Step 1: Write the failing test**

  Assert that the manifest has a runtime object with portable registration/installation owner values, a central service layout, immutable release policy, and exact role contracts. Assert installation token mode, selected repository scope, no ruleset bypass, no secret-like keys, and role-specific permission/event values.

- [ ] **Step 2: Run the focused test to verify it fails**

  Run: `bash scripts/github-setup/test-central-runtime-contract.sh`

  Expected: FAIL because the manifest has no `runtime` contract.

- [ ] **Step 3: Implement the minimum manifest contract**

  Add only the schema required by the test. Use portable placeholders for registration owner and central repository, `installation` as the token mode, `selected-repositories` as the installation scope, explicit `ruleset_bypass: false`, and role-specific permissions/events matching the issue’s Governance/Reviewer/Writer responsibilities.

- [ ] **Step 4: Run the focused test to verify it passes**

  Run: `bash scripts/github-setup/test-central-runtime-contract.sh`

  Expected: PASS.

- [ ] **Step 5: Commit**

  Commit message: `feat: define central governance runtime contract`

### Task 2: Document the central adapter and register the contract test

**Files:**
- Modify: `templates/centralized-actions-workflows/README.md`
- Modify: `docs/github-app-trust-boundaries.md`
- Modify: `scripts/run-contract-tests.sh`

**Interfaces:**
- Consumes: Task 1’s `runtime` manifest fields and focused contract test.
- Produces: operator/consumer documentation and deterministic suite coverage.

- [ ] **Step 1: Add documentation assertions to the focused test**

  Assert that the seed README explains consumer-owned triggers/secrets/policy and installation-token runtime, and that the trust-boundary document states operator-only shared credentials, no ruleset bypass, and selected-repository installation.

- [ ] **Step 2: Run the focused test to verify the new assertions fail**

  Run: `bash scripts/github-setup/test-central-runtime-contract.sh`

  Expected: FAIL on the missing or incomplete documentation assertions.

- [ ] **Step 3: Update documentation and deterministic suite wiring**

  Document the three roles, central service layout, adapter boundary, portable owners, credential custody, and operator-gated live installation. Add the focused test to `scripts/run-contract-tests.sh`.

- [ ] **Step 4: Run focused and aggregate contracts**

  Run: `bash scripts/github-setup/test-central-runtime-contract.sh && bash scripts/run-contract-tests.sh`

  Expected: PASS for the focused test and all deterministic contract tests.

- [ ] **Step 5: Commit**

  Commit message: `test: cover central runtime contract boundaries`

### Task 3: Run repository quality and handoff verification

**Files:**
- Test: all files changed by Tasks 1–2.

**Interfaces:**
- Consumes: completed runtime manifest, documentation, and contract-suite registration.
- Produces: fresh machine-readable validation evidence for issue #352.

- [ ] **Step 1: Run formatting and quality validation**

  Run: `LINT_MODE=check make quality`

  Expected: PASS with no changed-file formatting or lint failures.

- [ ] **Step 2: Inspect the final diff and security boundaries**

  Confirm no live Apps, credentials, installations, workflows, or rulesets were changed; confirm the manifest contains no secret values and optional capabilities remain disabled.

- [ ] **Step 3: Commit any required formatting-only correction**

  If quality identifies a formatting issue, fix it with a focused change and rerun the failed command before committing.

- [ ] **Step 4: Record validation evidence in the issue and prepare review handoff**

  Report the focused contract, deterministic suite, and quality command results, with live App/canary validation marked `NOT_RUN_OPERATOR_GATE`.
