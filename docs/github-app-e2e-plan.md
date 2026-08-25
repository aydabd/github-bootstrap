# Credentialed GitHub App E2E follow-up

This change verifies App authentication locally through deterministic action and workflow contract
tests. It does not fake an App key or claim live authentication.

The follow-up E2E change should cover both supported owner types:

1. Register a disposable GitHub App with the App Manifest flow and only the permissions in the
   permission matrix. Exchange the one-time manifest code for the App credentials programmatically.
2. For organization coverage, install it on a disposable test organization. For personal coverage,
   authorize it for a disposable test user and provide the resulting App user access token only as
   a protected caller/environment secret (`BOOTSTRAP_APP_USER_TOKEN`, a `ghu_` GitHub App user token).
3. Keep private keys and user access tokens in an ephemeral runner or external secret manager, never
   in Git, a generated repository, or a test repository secret. Store only the Client ID as non-secret
   configuration.
4. Run both creation workflows for organization and personal targets. Owner mismatch, user-token
   identity mismatch, and user-token-to-organization misuse must fail before creation.
5. Verify repository creation, generated files, token scope, cleanup, and isolation from the upstream
   repository and unrelated owners.
6. Revoke the installation and App authorization, then delete disposable resources after the run.

The local contract tests do not mint credentials or call live GitHub authentication. This plan must
not be implemented by faking a private key or user token locally.

Vault/OIDC credential delivery remains tracked by issue #92 and is not part of this plan.
