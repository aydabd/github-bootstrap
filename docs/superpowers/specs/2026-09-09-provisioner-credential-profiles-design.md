# Provisioner Credential Profiles

## Goal

Separate real repository creation from generated-repository E2E execution so
their GitHub App user refresh tokens cannot invalidate one another. Keep the
shared token-resolution implementation generic while making every credential
profile explicit, auditable, and centrally defined.

## Profiles

The repository will define two provisioner profiles in one machine-readable
manifest:

- `production-provisioner`
- `e2e-provisioner`

Each profile owns a distinct GitHub App authorization and declares its client
ID variable, private-key secret, client-secret secret, refresh-token secret,
and Actions environment. Production uses `production-provisioning`; E2E uses
`e2e-testing`.

The existing `BOOTSTRAP_E2E_APP_*` credentials remain the separate lifecycle
App used to inspect and clean up generated repositories. They are not reused
as provisioner credentials.

## Workflow contract

Both `create-repository.yml` and `terraform-create-repository.yml` use the
production provisioner profile. The generated E2E workflow uses the E2E
provisioner profile for dispatching both creation workflows and for both
embedded and centralized delivery modes.

The reusable workflow interface changes are intentional breaking changes:
callers provide the profile-specific credentials from their selected
environment, and the workflow no longer accepts ambiguous shared provisioner
secret names. Direct production runs also require the production environment.

## Shared implementation

`resolve-gh-token` keeps generic inputs for credential values and receives an
explicit refresh-token rotation target. The rotation command selects either
repository scope or the named environment scope from that input; it never
copies or synchronizes refresh tokens between profiles.

The installer reads the manifest and accepts a profile, installing all four
profile-defined values into the selected repository environment. It does not
install provisioner credentials into repository scope.

## Source of truth

The manifest is authoritative for profile IDs, secret names, variable names,
and environment names. Installers and contract tests consume it directly.
Workflow YAML must still spell out GitHub Actions expressions, so contracts
validate that each workflow's explicit references match the manifest profile.

## Verification

Add deterministic contracts that prove:

1. profiles have distinct names, environments, and credential keys;
2. production creation workflows select the production profile;
3. generated E2E selects only the E2E provisioner profile and environment;
4. refresh rotation targets the selected environment;
5. the installer rejects unknown profiles and installs only profile-scoped
   credentials.

Run focused contracts, shellcheck, and `LINT_MODE=check make quality`. Live
E2E validation follows after the two GitHub Apps and both environments are
configured.
