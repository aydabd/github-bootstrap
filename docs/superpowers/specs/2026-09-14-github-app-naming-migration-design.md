# GitHub App Naming and Environment Migration Design

## Goal

Make GitHub App names, credential profiles, environments, workflows, and
documentation consistent while preserving a hard production/E2E trust boundary.

## Canonical naming

Human-facing GitHub App names:

- `Bootstrap Provisioner`
- `Bootstrap Writer`
- `Bootstrap Reviewer`
- `Bootstrap E2E Provisioner`
- `Bootstrap E2E Writer`
- `Bootstrap E2E Reviewer`
- `Bootstrap E2E Fixture`
- `Bootstrap E2E Admin`

GitHub environments:

- `production-provisioning`: production repository creation and administration.
- `production`: production maintenance Writer and Reviewer credentials used by
  generated repositories.
- `e2e`: every disposable E2E credential, including provisioning, maintenance,
  fixture, and cleanup identities.

Machine-readable namespaces:

- Production credentials use `BOOTSTRAP_PRODUCTION_*`.
- E2E credentials use `BOOTSTRAP_E2E_*`.

Profiles use role names `production-provisioner`, `production-writer`,
`production-reviewer`, `e2e-provisioner`, `e2e-writer`, `e2e-reviewer`, and
`e2e-fixture`. Production has no fixture or dispatch App.

## Trust boundaries

- Generated repositories use only `production` maintenance credentials.
- Disposable generated repositories and the E2E dispatcher use only `e2e`.
- The E2E dispatcher is named `dispatch-e2e.yml` and must contain no production
  environment, secret, variable, App slug, or profile reference.
- `production-provisioning` remains separate because its App can administer
  repositories, environments, secrets, and workflows.
- Production and E2E Apps remain separate installations even when manifests
  grant the same permission set.

## Migration safety

The migration is additive. Existing Apps, environments, variables, and secrets
remain untouched until the replacement Apps are installed and the new bindings
pass verification. The repository must document the old-to-new mapping and the
operator must provision new private keys, client secrets, and refresh tokens;
secret values must never be copied through source control or workflow inputs.

Verification must cover:

1. Profile and manifest contracts.
2. Production template binding and production credential isolation.
3. E2E generated repository provisioning and cleanup.
4. Label-triggered E2E dispatch against the exact PR head.
5. E2E maintenance lifecycle using only the `e2e` environment.

Only after all five pass may the operator remove the old Apps and bindings.
