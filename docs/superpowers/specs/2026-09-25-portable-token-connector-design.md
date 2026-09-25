# Portable Token Connector Design

## Status

Design approved in chat for review before implementation. This slice is
limited to the bootstrap connector/token boundary. It does not create,
install, transfer, rotate, or revoke any live GitHub App.

## Goal

Provide one fail-closed, portable connector interface for resolving the
credential needed by a bootstrap workflow while preserving the distinction
between centralized runtime installation tokens and personal-account
bootstrap/E2E refresh-token flows.

## Context

The repository already has `.github/actions/resolve-gh-token`, which can mint
an installation token with `actions/create-github-app-token` or exchange a
personal-account App refresh token. The portable App/Project preflight now
collects `app_installation_identity`, `app_permission_profile`, `token_mode`,
and target owner/repository information, but the token action still exposes
the older `app_owner`-centric contract. The connector must bridge these
contracts without distributing private keys or silently broadening scope.

## Scope

- Define a portable connector input contract for App identity, authenticated
  owner, target owner, repository scope, permission profile, and token mode.
- Normalize and validate the contract before any token or GitHub mutation is
  attempted.
- Use installation tokens for organization-owned or centralized runtime work.
- Keep App user refresh-token exchange limited to explicitly allowed
  bootstrap/E2E provisioning profiles.
- Preserve existing action input compatibility while migrating callers to the
  portable interface.
- Add deterministic offline tests for valid and invalid owner/scope/profile
  combinations and secret-safe output behavior.

## Non-goals

- Creating or installing real `leniva-ab` Apps.
- App transfer, credential rotation, key revocation, or secret migration.
- A hosted token broker or external service.
- Changing existing App permission profiles beyond the connector validation
  needed to select them.
- Removing the embedded token action or compatibility inputs.
- Live personal and organization canary execution.

## Proposed interface

The existing action remains the implementation boundary, with a portable
connector contract added around it:

| Input | Required | Meaning |
| --- | --- | --- |
| `app_installation_identity` | yes | Non-secret configured App identity; used to assert and audit the intended credential profile, never treated as a private key or token. |
| `app_owner` | yes | Owner that owns the App installation and supplied credentials. |
| `target_owner` | yes | Owner whose repository is being operated on. |
| `repositories` | profile-dependent | Explicit repository names for scoped installation tokens. |
| `permission_profile` | yes | Existing allowlisted least-privilege profile. |
| `token_mode` | yes | `installation` or `bootstrap-refresh`; `auto` is normalized before resolution. |
| existing credential inputs | profile-dependent | Client ID, private key, and refresh-token inputs remain secret-bearing and are never written to evidence. |

The action continues to return `token`, `auth_mode`, and `app_slug`. The
connector additionally emits a non-secret normalized metadata record suitable
for workflow output: identity, authenticated owner, target owner, normalized
mode, profile, and repository scope. It must not emit credentials, private-key
material, refresh tokens, or raw GitHub responses.

## Validation and data flow

1. Parse the portable configuration and normalize `auto` to
   `installation` for organization targets and to `bootstrap-refresh` only
   for explicitly supported personal bootstrap/E2E profiles.
2. Validate GitHub owner syntax, classify the target owner, and require the
   authenticated App owner to match the configured installation owner.
3. Require a non-empty repository scope for every profile that is not
   repository creation or explicitly lifecycle-scoped. Reject wildcard or
   cross-owner repository references.
4. Validate that `app_installation_identity` is a non-secret GitHub-safe
   identifier and is present whenever installation mode is selected. The
   caller remains responsible for mapping that identity to the supplied
   credentials; the connector never discovers or fetches secrets by identity.
5. Select the existing installation-token path for installation mode. The
   token request uses the validated owner and exact repository list.
6. Select the refresh-token path only when the normalized mode is
   `bootstrap-refresh`, the target is a personal account, the profile is in
   the existing bootstrap allowlist, and both client secret and refresh token
   inputs are present.
7. Mask all resolved credentials and return only the token output required by
   the caller plus the non-secret metadata record.

Any validation failure occurs before token creation or refresh-secret writes.
The connector must not fall back from an invalid installation request to a
user token, and it must not fall back from a missing scope to an owner-wide
installation token.

## Compatibility and migration

- Existing callers may continue to provide `app_owner` and current secret
  inputs during this slice.
- New callers pass the normalized portable fields and receive the same token
  outputs.
- Compatibility tests prove equivalent behavior for existing embedded
  workflows and new centralized callers.
- No old input, App, workflow, or credential is removed until live parity and
  rollback evidence are recorded under issue #280.

## Security properties

- Private keys, client secrets, refresh tokens, access tokens, and raw API
  responses never appear in logs, JSON evidence, or action outputs other than
  the masked token output consumed in-process.
- Installation tokens are repository-scoped and short-lived.
- Runtime profiles cannot use personal-account refresh-token exchange.
- App identity is metadata, not authorization; authorization comes from the
  supplied credentials and validated owner/scope.
- Cross-tenant owner mismatch, empty scope, wildcard scope, invalid mode, and
  unsupported profile are explicit failures.

## Verification

The implementation must add deterministic contract coverage for:

- organization plus installation mode with exact repository scope;
- personal bootstrap plus refresh mode;
- `auto` normalization for organization and personal targets;
- authenticated-owner/target-owner mismatch;
- missing, wildcard, and cross-owner repository scope;
- runtime profile requested with refresh mode;
- missing App identity or invalid identity syntax;
- secret masking and absence from structured metadata;
- compatibility calls using the existing action inputs.

Run the focused connector contract test, the repository deterministic contract
suite, and `LINT_MODE=check make quality`. Live App/canary tests remain
operator-gated and must be reported as `NOT_RUN` until credentials and
installations are explicitly provided.

## Rollout and rollback

The connector is introduced behind the existing workflow paths and can be
selected per caller. A failed connector validation leaves the embedded
compatibility path available; it does not mutate credentials or installations.
Rollback is the caller-level switch back to the existing action contract.
Retirement of compatibility inputs requires separate parity evidence and
explicit approval under issue #280.

## Acceptance criteria

- [ ] Portable connector inputs and normalization are documented and
      machine-checked.
- [ ] Installation-token and bootstrap-refresh paths are mutually constrained
      by target type and permission profile.
- [ ] Repository scope and owner boundaries are validated before token work.
- [ ] Existing callers remain compatible and new portable callers are covered.
- [ ] No secret material appears in logs, outputs, or deterministic evidence.
- [ ] Focused contracts and full quality pass.
- [ ] Live App creation, installation, canaries, migration, and compatibility
      retirement remain explicitly out of scope and unchanged.
