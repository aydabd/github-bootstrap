---
name: github-app-credentials
description: Configure and safely rotate the Provisioner GitHub App credentials for user and organization targets.
---

# GitHub App credential setup

Use this skill when configuring the Repository Bootstrap Provisioner App or
debugging personal-account authentication.

## Choose the credential path

- `Organization`: use the App private key and mint a short-lived installation
  token at runtime. The App must be installed in the organization.
- `User`: the bootstrap repository’s protected provisioning workflow performs
  the refresh exchange. Generated repositories never receive the client secret,
  refresh token, or short-lived user token.

Do not use a PAT, a `ghu_` access token as a stored credential, or a token in a
workflow-dispatch input. Do not use an installation token for `/user/repos`.

## Required configuration

Set the client ID as the repository or Environment variable
`BOOTSTRAP_PROVISIONER_APP_CLIENT_ID`. The bootstrap repository keeps the
following values as protected secrets; do not configure them in a generated
repository:

- `BOOTSTRAP_PROVISIONER_APP_PRIVATE_KEY`

The Provisioner App must have `Secrets: write` if personal runs will persist
rotated refresh tokens. Limit the App installation to the caller repository
and intended target repositories. If the target user does not own the caller
repository, automatic refresh-secret persistence is refused; use an external
secret manager or rotate that secret manually.

## Safe setup

Keep the manifest output directory outside the checkout with mode `0700`.
Use the bootstrap repository’s documented setup tooling to produce and install
credentials. Never print a credential, copy one into a generated repository, or
commit the files.

Verify without exposing values:

```bash
gh secret list --repo OWNER/REPOSITORY
gh variable list --repo OWNER/REPOSITORY
gh api /user --jq .login
```

The first two commands show names and metadata only. Run the personal E2E with
the target user; successful personal creation proves the refresh exchange,
owner check, repository creation, and refresh-secret rotation path.
